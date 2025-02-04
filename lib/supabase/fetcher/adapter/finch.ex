defmodule Supabase.Fetcher.Adapter.Finch do
  @moduledoc "HTTP Client backend implementation for `Supabase.Fetcher` using Finch"

  use Supabase.Fetcher.Adapter

  import Supabase.Fetcher.Request, only: [with_body: 2, with_headers: 2]

  alias Supabase.Fetcher

  @impl true
  def request(%Request{method: method, headers: headers} = b, opts \\ []) do
    query = URI.encode_query(b.query)
    url = URI.append_query(b.url, query)

    method
    |> Finch.build(url, headers, b.body)
    |> Finch.request(Supabase.Finch, opts)
  end

  @impl true
  def request_async(%Request{method: method, headers: headers} = b, opts \\ []) do
    query = URI.encode_query(b.query)
    url = URI.append_query(b.url, query)

    ref =
      method
      |> Finch.build(url, headers, b.body)
      |> Finch.async_request(Supabase.Finch, opts)

    error =
      receive do
        {^ref, {:error, err}} -> err
      after
        300 -> nil
      end

    if is_nil(error) do
      status = receive(do: ({^ref, {:status, status}} -> status))
      headers = receive(do: ({^ref, {:headers, headers}} -> headers))

      stream =
        Stream.resource(
          fn -> ref end,
          fn ref ->
            receive do
              {^ref, {:data, chunk}} -> {[chunk], ref}
              {^ref, :done} -> {:halt, ref}
            end
          end,
          &Function.identity/1
        )

      body = Enum.to_list(stream) |> Enum.join()

      headers =
        receive do
          {^ref, {:headers, final_headers}} -> Fetcher.merge_headers(headers, final_headers)
        after
          300 -> headers
        end

      {:ok, %Finch.Response{body: body, headers: headers, status: status}}
    else
      {:error, error}
    end
  end

  @impl true
  def stream(%Request{method: method, headers: headers} = b, on_response \\ nil, opts \\ []) do
    query = URI.encode_query(b.query)
    url = URI.append_query(b.url, query)
    req = Finch.build(method, url, headers, b.body)
    ref = make_ref()
    task = spawn_stream_task(req, ref, opts)
    status = receive(do: ({:chunk, {:status, status}, ^ref} -> status))
    headers = receive(do: ({:chunk, {:headers, headers}, ^ref} -> headers))

    stream =
      Stream.resource(fn -> {ref, task} end, &receive_stream(&1), fn {_ref, task} ->
        Task.shutdown(task)
      end)

    headers =
      receive do
        {:chunk, {:headers, final_headers}, ^ref} ->
          Fetcher.merge_headers(headers, final_headers)
      after
        300 -> headers
      end

    if is_function(on_response, 1) do
      case on_response.({status, headers, stream}) do
        :ok -> :ok
        {:ok, body} -> {:ok, body}
        {:error, %Supabase.Error{} = err} -> {:error, err}
        unexpected -> Supabase.Error.new(service: b.service, metadata: %{raw_error: unexpected})
      end
    else
      %Finch.Response{
        status: status,
        body: Enum.to_list(stream) |> Enum.join(),
        headers: headers
      }
      |> then(&{:ok, &1})
    end
  end

  defp spawn_stream_task(%Finch.Request{} = req, ref, opts) do
    me = self()

    Task.async(fn ->
      on_chunk = fn chunk, _acc -> send(me, {:chunk, chunk, ref}) end
      Finch.stream(req, Supabase.Finch, nil, on_chunk, opts)
      send(me, {:done, ref})
    end)
  end

  defp receive_stream({ref, _task} = payload) do
    receive do
      {:chunk, {:data, data}, ^ref} -> {[data], payload}
      {:done, ^ref} -> {:halt, payload}
    end
  end

  @impl true
  def upload(%Request{} = b, file, opts \\ []) do
    mime_type = MIME.from_path(file)
    body_stream = File.stream!(file, 2048)
    %File.Stat{size: content_length} = File.stat!(file)
    content_headers = [{"content-length", to_string(content_length)}, {"content-type", mime_type}]

    b
    |> with_body({:stream, body_stream})
    |> with_headers(content_headers)
    |> request(opts)
  end

  defimpl Supabase.Fetcher.ResponseAdapter, for: Finch.Response do
    def from(%Finch.Response{} = resp) do
      %Supabase.Fetcher.Response{status: resp.status, headers: resp.headers, body: resp.body}
    end
  end
end
