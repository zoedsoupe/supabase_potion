defmodule Supabase.Fetcher do
  @moduledoc """
  `Supabase.Fetcher` is a comprehensive HTTP client designed to interface seamlessly with Supabase services. This module acts as the backbone for making HTTP requests, streaming data, uploading files, and managing request/response lifecycles within the Supabase ecosystem.

  ## Key Features

  - **Request Composition**: Build requests with method, headers, body, and query parameters using a composable builder pattern.
  - **Service-Specific Integrations**: Automatically derive URLs for Supabase services like `auth`, `functions`, `storage`, `realtime`, and `database`.
  - **Streaming Support**: Stream large responses efficiently using `Finch.stream/5`, reducing memory usage for large payloads.
  - **Customizable Response Handling**: Attach decoders and error parsers tailored to specific service requirements.
  - **Error Management**: Centralized error handling through `Supabase.ErrorParser`, supporting structured and semantic error reporting.

  ## Key Components

  ### Request Builder API

  The `Supabase.Fetcher` provides a composable API for constructing HTTP requests. Each step updates the request builder state:

  - `with_<service>_url/2`: Appends the path to a service-specific base URL.
  - `with_method/2`: Sets the HTTP method (`:get`, `:post`, etc.).
  - `with_headers/2`: Appends or overrides headers.
  - `with_body/2`: Sets the request body, supporting JSON, iodata, or streams.
  - `with_query/2`: Adds query parameters.

  ### Decoders and Parsers

  - **Body Decoder**: Custom modules implementing the `Supabase.Fetcher.BodyDecoder` behaviour can decode response bodies into application-specific formats.
  - **Error Parser**: Handle service-specific errors using `Supabase.Error` implementations, ensuring consistent error reporting across services.

  ### Streaming

  - `stream/1` and `stream/2` support fine-grained control over streamed responses, allowing consumers to process data incrementally while retaining access to status and headers.

  ### Upload Support

  Effortlessly upload binary files using the `upload/2` function, which manages content type, headers, and streaming.

  ## Example Usage

  ### Basic Request

  ```elixir
  {:ok, response} =
    Supabase.Fetcher.new(client)
    |> Supabase.Fetcher.with_auth_url("/token")
    |> Supabase.Fetcher.with_method(:post)
    |> Supabase.Fetcher.with_body(%{username: "test", password: "test"})
    |> Supabase.Fetcher.request()
  ```

  ## Streaming

  ### Consume the whole stream

  ```elixir
  {:ok, %Finch.Response{body: <<...>>}} =
    Supabase.Fetcher.new(client)
    |> Supabase.Fetcher.with_storage_url("/large-file")
    |> Supabase.Fetcher.stream()
  ```

  ### Fine-grained control over body stream

  ```elixir
  on_response = fn {_status, _headers, body} ->
    try do
      file = File.stream!("output.txt", [:write, :utf8])

      body
      |> Stream.into(file)
      |> Stream.run()
    rescue
      e in File.Error -> {:error, e.reason}
    end
  end

  {:ok, %Finch.Response{body: stream}} =
    Supabase.Fetcher.new(client)
    |> Supabase.Fetcher.with_storage_url("/large-file")
    |> Supabase.Fetcher.stream(on_response)
  ```

  ## Custom Decoders and Error Parsers

  ```elixir
  {:ok, response} =
    Supabase.Fetcher.new(client)
    |> Supabase.Fetcher.with_functions_url("/execute")
    |> Supabase.Fetcher.with_body_decoder(MyCustomDecoder)
    |> Supabase.Fetcher.with_error_parser(MyErrorParser)
    |> Supabase.Fetcher.request()
  ```

  ## Notes

  This module is designed to be extensible and reusable for all Supabase-related services. It abstracts away the low-level HTTP intricacies while providing the flexibility developers need to interact with Supabase services in Elixir applications.
  """

  alias Supabase.Client

  @behaviour Supabase.FetcherBehaviour

  @type t :: %__MODULE__{
          client: Client.t(),
          method: Finch.Request.method(),
          body: Finch.Request.body(),
          headers: Finch.Request.headers(),
          url: Finch.Request.url(),
          options: Finch.request_opts(),
          service: Supabase.service(),
          body_decoder: module,
          error_parser: module
        }

  defstruct [
    :url,
    :service,
    :client,
    :body,
    method: :get,
    query: "",
    options: [],
    headers: %{},
    body_decoder: Supabase.Fetcher.JSONDecoder,
    error_parser: Supabase.ErrorParser
  ]

  @doc """
  Initialise the `Supabase.Fetcher` struct, accumulating the
  client global headers and the client itself, so the request can be
  easily composed using the `with_` functions of this module.
  """
  @impl true
  def new(%Client{global: global} = client) do
    headers =
      global.headers
      |> Map.put("authorization", "Bearer " <> client.access_token)
      |> Map.to_list()

    %__MODULE__{client: client, headers: headers}
  end

  @services [:auth, :functions, :storage, :realtime, :database]

  for service <- @services do
    @doc """
    Applies the #{service} base url from the client and appends the
    informed path to the url. Note that this function will overwrite
    the `url` field each time of call.
    """
    @impl true
    def unquote(:"with_#{service}_url")(%__MODULE__{} = builder, path)
        when is_binary(path) do
      base = Map.get(builder.client, :"#{unquote(service)}_url")
      %{builder | url: Path.join(base, path) |> URI.parse(), service: unquote(service)}
    end
  end

  @doc """
  Attaches a custom body decoder to be called after a successfull response.
  The body decoder should implement the `Supabase.Fetcher.BodyDecoder` behaviour, and it default
  to the `Supabase.Fetcher.JSONDecoder`.

  You can pass `nil` as the decoder to avoid body decoding, if you need the raw body.
  """
  @impl true
  def with_body_decoder(%__MODULE__{} = builder, decoder) when is_atom(decoder) do
    %{builder | body_decoder: decoder}
  end

  @doc """
  Attaches a custom error parser to be called after a successfull response.
  The error parser should implement the `Supabase.Error` behaviour, and it default
  to the `Supabase.ErrorParser`.

  THis attribute can't be overwritten.
  """
  @impl true
  def with_error_parser(%__MODULE__{} = builder, parser)
      when is_atom(parser) and not is_nil(parser) do
    %{builder | error_parser: parser}
  end

  @doc """
  Define the method of the request, default to `:get`, the available options
  are the same of `Finch.Request.method()` and note that this function
  will overwrite the `method` attribute each time is called.
  """
  @impl true
  def with_method(%__MODULE__{} = builder, method \\ :get) when is_atom(method) do
    %{builder | method: method}
  end

  @doc """
  Append query params to the current request builder, it receives an `Enumerable.t()`
  and encodes it to string with `URI.encode_query/1`. Note that this function
  overwrite the `query` attribute each time is called.
  """
  @impl true
  def with_query(%__MODULE__{} = builder, query) do
    %{builder | query: URI.encode_query(query)}
  end

  @doc """
  Defines the request body to be sent, it can be a map, that will be encoded
  with `Jason.encode_to_iodata!/1`, any `iodata` or a stream body in the pattern of `{:stream, Enumerable.t}`, although you will problably prefer to use the `upload/2`
  function of this module to hadle body stream since it will handle file management, content headers and so on.
  """
  @impl true
  def with_body(builder, body \\ nil)

  def with_body(%__MODULE__{} = builder, %{} = body) do
    %{builder | body: Jason.encode_to_iodata!(body)}
  end

  def with_body(%__MODULE__{} = builder, body) do
    %{builder | body: body}
  end

  @doc """
  Append headers to the current request builder, the headers needs to be an
  `Enumerable.t()` and will be merged via `merge_headers/2`, which means that
  this function can be called multiple times **without** overwriting the existing
  headers definitions.
  """
  @impl true
  def with_headers(%__MODULE__{} = builder, headers) do
    %{builder | headers: merge_headers(builder.headers, headers)}
  end

  @doc """
  Defines the request options, available options are `Finch.request_opts()`
  """
  @impl true
  def with_options(%__MODULE__{} = builder, options) when is_list(options) do
    %{builder | options: options}
  end

  @doc """
  Executes the current request builder, synchronously and returns the response.
  """
  @impl true
  def request(%__MODULE__{method: method, headers: headers} = b) do
    url = URI.append_query(b.url, b.query)

    method
    |> Finch.build(url, headers, b.body)
    |> Finch.request(Supabase.Finch, b.options)
    |> handle_response(b)
  end

  @doc """
  Executes the current request builder, asynchronously and returns the response.
  Note that this function consumes the whole response stream and returns a `Finch.Response` in case of success.
  """
  @impl true
  def request_async(%__MODULE__{method: method, headers: headers} = b) do
    url = URI.append_query(b.url, b.query)

    ref =
      method
      |> Finch.build(url, headers, b.body)
      |> Finch.async_request(Supabase.Finch, b.options)

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
          {^ref, {:headers, final_headers}} -> merge_headers(headers, final_headers)
        after
          300 -> headers
        end

      {:ok, %Finch.Response{body: body, headers: headers, status: status}}
    else
      {:error, error}
    end
    |> handle_response(b)
  end

  @doc """
  Makes a HTTP request from the request builder and
  stream back the response. Good to stream large files downloads.

  The `Supabase.Fetcher.stream/1` consumes the whole response stream and returns, in case of success, `{:ok, %Finch.Response{}}`, however you can have a more fine-grained control of the stream using `Supabase.Fetcher.stream/2`.

  For that, you can pass a 1 arity function, with that the response stream will be
  **partially** consumed to get the response status and headers, but the body will
  remain as a stream, then it will invoke the `on_response` function that you passed
  with `{status, headers, stream}` as argument, then you can return whaetever you need.
  """
  @impl true
  def stream(%__MODULE__{method: method, headers: headers} = b, on_response \\ nil) do
    url = URI.append_query(b.url, b.query)
    req = Finch.build(method, url, headers, b.body)
    ref = make_ref()
    task = spawn_stream_task(req, ref, b.options)
    status = receive(do: ({:chunk, {:status, status}, ^ref} -> status))
    headers = receive(do: ({:chunk, {:headers, headers}, ^ref} -> headers))

    stream =
      Stream.resource(fn -> {ref, task} end, &receive_stream(&1), fn {_ref, task} ->
        Task.shutdown(task)
      end)

    headers =
      receive do
        {:chunk, {:headers, final_headers}, ^ref} ->
          merge_headers(headers, final_headers)
      after
        300 -> headers
      end

    if is_function(on_response, 1) do
      on_response.({status, headers, stream})
    else
      %Finch.Response{
        status: status,
        body: Enum.to_list(stream) |> Enum.join(),
        headers: headers
      }
      |> then(&{:ok, &1})
      |> handle_response(b)
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
  Upload a binary file based into the current request builder.
  """
  @impl true
  def upload(%__MODULE__{} = b, file, opts \\ []) do
    mime_type = MIME.from_path(file)
    body_stream = File.stream!(file, 2048, [:raw])
    %File.Stat{size: content_length} = File.stat!(file)
    content_headers = [{"content-length", to_string(content_length)}, {"content-type", mime_type}]

    b
    |> with_body({:stream, body_stream})
    |> with_headers(content_headers)
    |> with_options(opts)
    |> request()
  rescue
    e in File.Error ->
      message = File.Error.message(e)
      {:error, Supabase.Error.new(code: e.reason, message: message, service: b.service)}
  end

  @spec handle_response({:ok, Finch.Response.t()} | {:error, term}, t) ::
          {:ok, Finch.Response.t() | (stream :: Enumerable.t())} | {:error, Supabase.Error.t()}
  defp handle_response({:ok, %Finch.Response{body: stream} = resp}, %__MODULE__{} = builder)
       when is_struct(stream, Stream) do
    error_parser = builder.error_parser

    if resp.status >= 400 do
      {:error, error_parser.from_http_response(%{resp | body: nil}, builder)}
    else
      {:ok, stream}
    end
  end

  defp handle_response({:ok, %Finch.Response{} = resp}, %__MODULE__{} = builder) do
    error_parser = builder.error_parser

    with {:ok, resp} <- decode_body(resp, builder.body_decoder) do
      if resp.status >= 400 do
        {:error, error_parser.from_http_response(resp, builder)}
      else
        {:ok, resp}
      end
    end
  end

  defp handle_response({:error, %Mint.TransportError{} = err}, %__MODULE__{} = builder) do
    message = Mint.TransportError.message(err)
    metadata = Supabase.Error.make_default_http_metadata(builder)

    {:error,
     Supabase.Error.new(
       code: :transport_error,
       message: message,
       service: builder.service,
       metadata: metadata
     )}
  end

  defp handle_response({:error, %Mint.HTTPError{} = err}, %__MODULE__{} = builder) do
    message = Mint.HTTPError.message(err)
    metadata = Supabase.Error.make_default_http_metadata(builder)

    {:error,
     Supabase.Error.new(
       code: :http_error,
       message: message,
       service: builder.service,
       metadata: metadata
     )}
  end

  defp handle_response({:error, _err}, %__MODULE__{} = builder) do
    metadata = Supabase.Error.make_default_http_metadata(builder)

    {:error,
     Supabase.Error.new(
       code: :unexpected,
       service: builder.service,
       metadata: metadata
     )}
  end

  @doc """
  Helper function to directly decode the body using a `Supabase.Fetcher.BodyDecoder`
  """
  @spec decode_body(Finch.Response.t(), module | nil) ::
          {:ok, Finch.Response.t()} | {:error, term}
  def decode_body(%Finch.Response{} = resp, decoder \\ Supabase.Fetcher.JSONDecoder) do
    if decoder do
      with {:ok, body} <- decoder.decode(resp), do: {:ok, %{resp | body: body}}
    else
      {:ok, resp}
    end
  end

  @doc """
  Merge two collections of headers as an `Enumberable.t()`, avoiding duplicates and removing nullable headers
  - aka `nil` values.

  Note that this function is **left-associative** in terms of header priority.
  """
  @spec merge_headers(Enumerable.t(String.t()), Enumerable.t(String.t())) ::
          Finch.Request.headers()
  def merge_headers(some, other) do
    some = if is_list(some), do: some, else: Map.to_list(some)
    other = if is_list(other), do: other, else: Map.to_list(other)

    some
    |> Kernel.++(other)
    |> Enum.uniq_by(fn {name, _} -> name end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  @doc """
  Helper function to get a specific header value from a response.
  """
  @spec get_header(term, String.t()) :: String.t() | nil
  @spec get_header(term, String.t(), String.t()) :: String.t() | nil
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

  defimpl Inspect, for: Supabase.Fetcher do
    import Inspect.Algebra

    def inspect(%Supabase.Fetcher{} = fetcher, opts) do
      base_url = Map.get(fetcher.client, :"#{fetcher.service}_url", "")
      headers = Enum.reject(fetcher.headers, &(String.downcase(elem(&1, 0)) == "authorization"))

      fields = [
        method: String.upcase(to_string(fetcher.method)),
        path: String.replace(to_string(fetcher.url), base_url, ""),
        service: fetcher.service,
        headers: format_headers(headers),
        body_decoder: fetcher.body_decoder,
        error_parser: fetcher.error_parser
      ]

      concat([
        "#Supabase.Fetcher<",
        to_doc(fields, opts),
        ">"
      ])
    end

    defp format_headers(headers) when is_list(headers) do
      Enum.map_join(headers, ", ", fn {k, v} -> "#{k}=#{v}" end)
    end
  end
end
