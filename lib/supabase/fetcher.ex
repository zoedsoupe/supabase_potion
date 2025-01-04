defmodule Supabase.Fetcher do
  @moduledoc """
   A fundamental HTTP client for interfacing directly with Supabase services.

  `Supabase.Fetcher` provides the groundwork for sending HTTP requests to the Supabase infrastructure. This includes utilities for various HTTP methods such as GET, POST, PUT, DELETE, and functions to simplify the process of streaming data or uploading files.

  ## Key Features

  - **Low-level HTTP Interactions**: This module allows for raw HTTP requests to any URL, simplifying interactions with web resources.
  - **Data Streaming**: Efficiently stream large data payloads, such as downloading files.
  - **Request Customization**: Extensive header customization and utility functions for constructing requests tailored to your requirements.
  - **Response Parsing**: Automatically converts JSON responses into Elixir maps and handles various response scenarios.

  ## Recommended Usage

  While `Supabase.Fetcher` is versatile and comprehensive, it operates at a very granular level. For most applications and needs, leveraging higher-level APIs that correspond to specific Supabase services is advisable:

  - `Supabase.Storage` - API to interact directly with buckets and objects in Supabase Storage.

  ## Disclaimer

  If your aim is to directly harness this module as a low-level HTTP client, due to missing features in other packages or a desire to craft a unique Supabase integration, you can certainly do so. However, always keep in mind that `Supabase.Storage` and other Supabase-oriented packages might offer better abstractions and ease-of-use.

  Use `Supabase.Fetcher` with a clear understanding of its features and operations.
  """

  @behaviour Supabase.FetcherBehaviour

  @spec version :: String.t()
  def version do
    {:ok, vsn} = :application.get_key(:supabase_potion, :vsn)
    List.to_string(vsn)
  end

  @spec new_connection(atom, url, body, headers) :: Finch.Request.t()
        when url: String.t() | URI.t(),
             body: binary | nil | {:stream, Enumerable.t()},
             headers: list(tuple)
  def new_connection(method, url, body, headers) do
    headers = merge_headers(headers, default_headers())
    Finch.build(method, url, headers, body)
  end

  @spec default_headers :: list(tuple)
  defp default_headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"x-client-info", "supabase-fetch-elixir/#{version()}"},
      {"user-agent", "SupabasePotion/#{version()}"}
    ]
  end

  @doc """
  Makes a HTTP request to the desired URL, with default headers and
  stream back the response. Good to stream large files downlaods.

  You can also pass custom `Finch` options directly to the underlying `Finch.stream/4` function.
  Those options can be seen on the [Finch documentation](https://hexdocs.pm/finch/Finch.html#stream/5-options).

  ## Examples

       iex> {status, stream} = Supabase.Fetcher.stream("https://example.com")
       iex> file = File.stream!("path/to/file", [], 4096)
       Stream.run Stream.into(stream, file)
  """
  @impl true
  def stream(url, headers \\ [], opts \\ []) do
    ref = make_ref()
    task = spawn_stream_task(new_connection(:get, url, nil, headers), ref, opts)
    status = receive(do: ({:chunk, {:status, status}, ^ref} -> status))

    stream =
      Stream.resource(fn -> {ref, task} end, &receive_stream(&1), fn {_ref, task} ->
        Task.shutdown(task)
      end)

    case {status, stream} do
      {200, stream} -> {:ok, stream}
      {s, _} when s >= 400 -> {:error, :not_found}
      {s, _} when s >= 500 -> {:error, :server_error}
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

  @doc """
  Simple GET request that format the response to a map or retrieve
  the error reason as `String.t()`.

  ## Examples

       iex> Supabase.Fetcher.get("https://example.com")
       {:ok, %{"key" => "value"}}
  """
  def get(url) do
    get(url, nil, [], [])
  end

  def get(url, body) do
    get(url, body, [], [])
  end

  def get(url, body, headers) do
    get(url, body, headers, [])
  end

  @impl true
  def get(url, body, headers, opts) do
    resp =
      :get
      |> new_connection(url, Jason.encode_to_iodata!(body), headers)
      |> Finch.request(Supabase.Finch)

    if opts[:resolve_json] do
      format_response(resp)
    else
      resp
    end
  end

  @doc """
  Simple POST request that format the response to a map or retrieve
  the error reason as `String.t()`.

  ## Examples

       iex> Supabase.Fetcher.post("https://example.com", %{key: "value"})
       {:ok, %{"key" => "value"}}
  """
  @impl true
  def post(url, body \\ nil, headers \\ [], opts \\ []) do
    headers = merge_headers(headers, [{"content-type", "application/json"}])

    :post
    |> new_connection(url, Jason.encode_to_iodata!(body), headers)
    |> Finch.request(Supabase.Finch)
    |> then(&if opts[:resolve_json], do: format_response(&1), else: &1)
  end

  @doc """
  Simple PUT request that format the response to a map or retrieve
  the error reason as `String.t()`.

  ## Examples

       iex> Supabase.Fetcher.put("https://example.com", %{key: "value"})
       {:ok, %{"key" => "value"}}
  """
  @impl true
  def put(url, body, headers \\ [], opts \\ []) do
    headers = merge_headers(headers, [{"content-type", "application/json"}])

    :put
    |> new_connection(url, Jason.encode_to_iodata!(body), headers)
    |> Finch.request(Supabase.Finch)
    |> then(&if opts[:resolve_json], do: format_response(&1), else: &1)
  end

  @doc """
  Simple HEAD request that format the response to a map or
  retrieve the error as `String.t()`
  """
  @impl true
  def head(url, body, headers \\ [], opts \\ []) do
    headers = merge_headers(headers, [{"content-type", "application/json"}])

    :head
    |> new_connection(url, Jason.encode_to_iodata!(body), headers)
    |> Finch.request(Supabase.Finch)
    |> then(&if opts[:resolve_json], do: format_response(&1), else: &1)
  end

  @doc """
  Simple PATCH request that format the response to a map or
  retrieve the error as `String.t()`
  """
  @impl true
  def patch(url, body, headers \\ [], opts \\ []) do
    headers = merge_headers(headers, [{"content-type", "application/json"}])

    :put
    |> new_connection(url, Jason.encode_to_iodata!(body), headers)
    |> Finch.request(Supabase.Finch)
    |> then(&if opts[:resolve_json], do: format_response(&1), else: &1)
  end

  @doc """
  Simple DELETE request that format the response to a map or retrieve
  the error reason as `String.t()`.

  ## Examples

       iex> Supabase.Fetcher.delete("https://example.com", %{key: "value"})
       {:ok, %{"key" => "value"}}

       iex> Supabase.Fetcher.delete("https://example.com", %{key: "value"})
       {:error, :not_found}
  """
  @impl true
  def delete(url, body \\ nil, headers \\ [], opts \\ []) do
    headers = merge_headers(headers, [{"content-type", "application/json"}])

    :delete
    |> new_connection(url, Jason.encode_to_iodata!(body), headers)
    |> Finch.request(Supabase.Finch)
    |> then(&if opts[:resolve_json], do: format_response(&1), else: &1)
  end

  @doc """
  Upload a binary to the desired URL.

  params:
  - `method`: `:put` or `:post`
  - `url`: the URL to upload the file
  - `file`: the path to the file to upload
  - `headers`: list of additional headers to append to the request

  ## Examples

       iex> Supabase.Fetcher.upload(:post, "https://example.com", "path/to/file")
       {:ok, %{"key" => "value"}}
  """
  @impl true
  def upload(method, url, file, headers \\ []) do
    mime_type = MIME.from_path(file)
    body_stream = File.stream!(file, 2048, [:raw])
    %File.Stat{size: content_length} = File.stat!(file)
    content_headers = [{"content-length", to_string(content_length)}, {"content-type", mime_type}]
    headers = merge_headers(headers, content_headers)
    conn = new_connection(method, url, {:stream, body_stream}, headers)

    conn
    |> Finch.request(Supabase.Finch)
    |> format_response()
  rescue
    e in File.Error -> {:error, e.reason}
  end

  def get_full_url(base_url, path) do
    URI.merge(base_url, path)
  end

  @doc """
  Convenience function that given a `apikey` and a optional ` token`, it will return the headers
  to be used in a request to your Supabase API.

  ## Examples

       iex> Supabase.Fetcher.apply_conn_headers("apikey-value")
       [{"apikey", "apikey-value"}, {"authorization", "Bearer apikey-value"}]

       iex> Supabase.Fetcher.apply_conn_headers("apikey-value", "token-value")
       [{"apikey", "apikey-value"}, {"authorization", "Bearer token-value"}]
  """

  def apply_headers(api_key, token \\ nil, headers \\ []) do
    conn_headers = [
      {"apikey", api_key},
      {"authorization", "Bearer #{token || api_key}"}
    ]

    merge_headers(conn_headers, headers)
  end

  defp merge_headers(some, other) do
    some = if is_list(some), do: some, else: Map.to_list(some)
    other = if is_list(other), do: other, else: Map.to_list(other)

    some
    |> Kernel.++(other)
    |> Enum.uniq_by(fn {name, _} -> name end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  def apply_client_headers(%Supabase.Client{} = client, token \\ nil, headers \\ []) do
    client.api_key
    |> apply_headers(token || client.access_token, client.global.headers)
    |> merge_headers(headers)
  end

  def get_header(%Finch.Response{headers: headers}, header) do
    if h = Enum.find(headers, &(elem(&1, 0) == header)) do
      elem(h, 1)
    else
      nil
    end
  end

  def get_header(%Finch.Response{} = resp, header, default) do
    get_header(resp, header) || default
  end

  def format_response({:error, %{reason: reason}}) do
    {:error, reason}
  end

  def format_response({:ok, %{status: 404}}) do
    {:error, :not_found}
  end

  def format_response({:ok, %{status: 401}}) do
    {:error, :unauthorized}
  end

  def format_response({:ok, %{status: 204}}) do
    {:ok, :no_body}
  end

  def format_response({:ok, %{status: s, body: body}}) when s in 200..300 do
    Jason.decode(body)
  end

  def format_response({:ok, %{status: s, body: body}}) when s in 400..499 do
    with {:ok, result} <- Jason.decode(body) do
      {:error, format_bad_request_error(result)}
    end
  end

  def format_response({:ok, %{status: s}}) when s >= 500 do
    {:error, :server_error}
  end

  defp format_bad_request_error(%{"message" => msg}) do
    case msg do
      "The resource was not found" -> :not_found
      _ -> msg
    end
  end

  defp format_bad_request_error(%{"code" => 429, "msg" => msg}) do
    if String.starts_with?(msg, "For security purposes,") do
      [seconds] = Regex.run(~r/\d+/, msg, return: :binary) || ["undefined"]
      {:error, {:rate_limit_until_seconds, seconds}}
    else
      case msg do
        "Email rate limit exceeded" -> :email_rate_limit
        _ -> msg
      end
    end
  end

  defp format_bad_request_error(%{"error" => err, "error_description" => desc}) do
    case {err, desc} do
      {"invalid_grant", nil} -> :invalid_grant
      {"invalid_grant", "Invalid login credentials"} -> {:invalid_grant, :invalid_credentials}
      {"invalid_grant", "Email not confirmed"} -> {:invalid_grant, :email_not_confirmed}
      {"invalid_grant", err} -> {:invalid_grant, err}
    end
  end

  defp format_bad_request_error(err) do
    err
  end
end
