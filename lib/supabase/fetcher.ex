defmodule Supabase.Fetcher do
  @moduledoc """
  `Supabase.Fetcher` is a comprehensive HTTP client designed to interface seamlessly with Supabase services. This module acts as the backbone for making HTTP requests, streaming data, uploading files, and managing request/response lifecycles within the Supabase ecosystem.

  ## Key Features

  - **Request Composition**: Build requests with method, headers, body, and query parameters using a composable builder pattern via `Supabase.Fetcher.Request`.
  - **Streaming Support**: Stream large responses efficiently using `Finch.stream/5`, reducing memory usage for large payloads.
  - **Error Management**: Centralized error handling through `Supabase.ErrorParser`, supporting structured and semantic error reporting.

  ## Key Components

  ### HTTP Clients

  `Supabase.Fetcher` provides a `Supabase.Fetcher.Adapter` behaviour that defines
  the interface to implement custom HTTP clients backends (e.g `Finch`, `Req`, `:httpc`).

  That way is possible to use the same API defined on `Supabase.Fetcher` and customize
  how make the actual HTTP request. The default implementation uses `Supabase.Fetcher.Adapter.Finch`.

  You can customize the HTTP client used in `Supabase.Fetcher` with the `Supabase.Fetcher.Request.with_http_client/2` function while building your request:

  ```elixir
  fetcher =
    Supabase.Fetcher.Request.new(client)
    |> Supabase.Fetcher.Request.with_http_client(Supabase.Fetcher.Adapter.Httpc)
  ```

  `supabase_potion` would ideally provide multiple client implementations but you can
  safely extend to your own preference using the aforementioned behaviour, something like:

  ```elixir
  defmodule MyHTTPClient do
    @moduledoc "My custom HTTP client to be used as backend for `Supabase.Fetcher`"

    @behaviour Supabase.Fetcher.Adapter

    @impl true
    def request(%Supabase.Fetcher.Request{}), do: # ...

    @impl true
    # optional, if the client support async requests
    def request_async(%Supabase.Fetcher.Request{}), do: # ...

    @impl true
    # optional, if the client support response streaming
    def stream(%Supabase.Fetcher.Request{}), do: # ...
    def stream(%Supabase.Fetcher.Request{}, on_response), do: # ...

    @impl true
    # required to Storage upload to work
    def upload(%Supabase.Fetcher.Request{}, file_path, options), do: # ...
  end
  ```

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
  {:ok, %Supabase.Fetcher.Response{} = response} =
    Supabase.Fetcher.Request.new(client)
    |> Supabase.Fetcher.Request.with_auth_url("/token")
    |> Supabase.Fetcher.Request.with_method(:post)
    |> Supabase.Fetcher.Request.with_body(%{username: "test", password: "test"})
    |> Supabase.Fetcher.request()
  ```

  ## Streaming

  ### Consume the whole stream

  ```elixir
  {:ok, %Supabase.Fetcher.Response{body: <<...>>}} =
    Supabase.Fetcher.Request.new(client)
    |> Supabase.Fetcher.Request.with_storage_url("/large-file")
    |> Supabase.Fetcher.stream()
  ```

  ### Fine-grained control over body stream

  ```elixir
  on_response = fn {status, headers, body} ->
    try do
      file = File.stream!("output.txt", [:write, :utf8])

      body
      |> Stream.into(file)
      |> Stream.run()

      {:ok, %Supabase.Fetcher.Response{status: status, headers: headers}}
    rescue
      e in File.Error -> {:error, e.reason}
    end
  end

  {:ok, %Supabase.Fetcher.Response{body: stream}} =
    Supabase.Fetcher.Request.new(client)
    |> Supabase.Fetcher.Request.with_storage_url("/large-file")
    |> Supabase.Fetcher.stream(on_response)
  ```

  ## Custom Decoders and Error Parsers

  ```elixir
  {:ok, %Supabase.Decoder{} = response} =
    Supabase.Fetcher.Request.new(client)
    |> Supabase.Fetcher.Request.with_functions_url("/execute")
    |> Supabase.Fetcher.Request.with_body_decoder(MyCustomDecoder)
    |> Supabase.Fetcher.Request.with_error_parser(MyErrorParser)
    |> Supabase.Fetcher.request()
  ```

  ## Notes

  This module is designed to be extensible and reusable for all Supabase-related services. It abstracts away the low-level HTTP intricacies while providing the flexibility developers need to interact with Supabase services in Elixir applications.

  In general, if you don't have specific needs, custom application formats or you aren't
  building something new around `Supabase.Fetcher` you generally are safe using the default options if you only need to consume Supabase services as a client.
  """

  alias Supabase.Error
  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response
  alias Supabase.Fetcher.ResponseAdapter

  @behaviour Supabase.Fetcher.Behaviour

  @typedoc "Generic typespec to define possible response values, adapt to each client"
  @type response :: Finch.Response.t()
  @type status :: integer
  @type headers :: list({header :: String.t(), value :: String.t()})
  @type query :: list({param :: String.t(), value :: String.t()})
  @type method :: :get | :post | :head | :patch | :put | :delete
  @type body :: iodata | {:stream, Enumerable.t()} | nil
  @type url :: String.t() | URI.t()

  @doc """
  Executes the current request builder, synchronously and returns the response.
  """
  @impl true
  def request(%Request{http_client: http_client} = builder, opts \\ [])
      when not is_nil(builder.url) do
    with {:ok, resp} <- http_client.request(builder, opts) do
      {:ok, ResponseAdapter.from(resp)}
    end
    |> handle_response(builder)
  end

  @doc """
  Executes the current request builder, asynchronously and returns the response.
  Note that this function does not **stream** the request, although it can use
  a stream to consume chunks, as you can see an example in `Supabase.Fetcher.Adapter.Finch.request_async/2`.

  What happens here is that the request is done on a separate process, and the response
  is sent via message passing, in chunks, so no all HTTP client support async requests.

  Also, this function provides a higher-level API to just trigger the request dispatch
  and return a result, so the use experience looks like the sync version `request/2`.

  If you wanna **stream** a HTTP request, then you should go with `stream/2` or `stream/3`.

  And if you wanna **upload** a binary/file, streaming it, then you should go with `upload/3`.
  """
  @impl true
  def request_async(%Request{http_client: http_client} = builder, opts \\ [])
      when not is_nil(builder.url) do
    with {:ok, resp} <- http_client.request_async(builder, opts) do
      {:ok, ResponseAdapter.from(resp)}
    end
    |> handle_response(builder)
  end

  @doc """
  Makes a HTTP request from the request builder and
  stream back the response. Good to stream large files downloads, as it what
  `Supabase.Storage` does.

  The `Supabase.Fetcher.stream/2` consumes the whole response stream and returns, in case of success, `{:ok, %Supabase.Fetcher.Response{}}`, however you can have a more fine-grained control of the stream using `Supabase.Fetcher.stream/3`.

  The `stream/2` behaviour look likes `request/2` and `request_async/2` since it feels
  like a sync request where you dispatch and receive a parsed result.

  For have more control of the response chunks, you can pass a 1 arity function, with that the response stream will be
  **partially** consumed to get the response status and headers, but the body will
  remain as a stream, then it will invoke the `on_response` function that you passed
  with `{status, headers, stream}` as argument, then you should return `Supabase.Fetcher.Response` in case of success or `Supabase.Error` in case of error.
  """
  @impl true
  def stream(builder, on_response \\ nil, opts \\ [])

  def stream(%Request{http_client: http_client} = builder, nil, opts)
      when not is_nil(builder.url) do
    with {:ok, resp} <- http_client.stream(builder, opts) do
      {:ok, ResponseAdapter.from(resp)}
    end
    |> handle_response(builder)
  end

  def stream(%Request{http_client: http_client} = builder, on_response, opts)
      when not is_nil(builder.url) do
    with {:ok, resp} <- http_client.stream(builder, on_response, opts) do
      {:ok, ResponseAdapter.from(resp)}
    end
    |> handle_response(builder)
  end

  @doc """
  Upload a binary file based into the current request builder.
  """
  @impl true
  def upload(%Request{http_client: http_client} = builder, file, opts \\ [])
      when not is_nil(builder.url) do
    with {:ok, resp} <- http_client.upload(builder, file, opts) do
      {:ok, ResponseAdapter.from(resp)}
    end
    |> handle_response(builder)
  rescue
    e in File.Error -> {:error, Supabase.ErrorParser.from(e)}
  end

  @spec handle_response({:ok, response} | {:error, term}, context) :: Supabase.result(response)
        when response: Response.t(),
             context: Request.t()
  defp handle_response({:ok, %Response{} = resp}, %Request{} = builder) do
    error_parser = builder.error_parser
    decoder = builder.body_decoder
    decoder_opts = builder.body_decoder_opts

    with {:ok, resp} <- Response.decode_body(resp, decoder, decoder_opts) do
      if resp.status >= 400 do
        {:error, error_parser.from(resp, builder)}
      else
        {:ok, resp}
      end
    end
  rescue
    e in Protocol.UndefinedError ->
      reraise e, __STACKTRACE__

    exception ->
      message = Exception.format(:error, exception)
      stacktrace = Exception.format_stacktrace(__STACKTRACE__)

      Supabase.Error.new(
        code: :decode_body_failed,
        message: message,
        service: builder.service,
        metadata: %{stacktrace: stacktrace}
      )
  end

  defp handle_response({:error, %Error{} = err}, %Request{} = builder) do
    metadata = Error.make_default_http_metadata(builder)
    metadata = Map.merge(metadata, err.metadata)
    {:error, %{err | metadata: metadata}}
  end

  defp handle_response({:error, err}, %Request{} = builder) do
    {:error, Supabase.ErrorParser.from(err, builder)}
  end

  @doc """
  Merge two collections of headers as an `Enumberable.t()`, avoiding duplicates and removing nullable headers
  - aka `nil` values.

  Note that this function is **right-associative** in terms of header priority,
  this means that any duplicate new header that is passed to this function
  will **overwrite** the last definition, take caution with it.
  """
  @spec merge_headers(Enumerable.t(String.t()), Enumerable.t(String.t())) ::
          Finch.Request.headers()
  def merge_headers(some, other) do
    some = if is_list(some), do: some, else: Map.to_list(some)
    other = if is_list(other), do: other, else: Map.to_list(other)

    other
    |> Kernel.++(some)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.uniq_by(fn {name, _} -> String.downcase(name) end)
  end
end
