defmodule Supabase.Fetcher.Request do
  @moduledoc """
  `Supabase.Fetcher.Request` is a structure to handle HTTP request builder designed to interface seamlessly with Supabase services.

  ## Key Features

  - **Request Composition**: Build requests with method, headers, body, and query parameters using a composable builder pattern.
  - **Service-Specific Integrations**: Automatically derive URLs for Supabase services like `auth`, `functions`, `storage`, `realtime`, and `database`.
  - **Customizable Response Handling**: Attach decoders and error parsers tailored to specific service requirements.
  - **Error Management**: Centralized error handling through `Supabase.ErrorParser`, supporting structured and semantic error reporting.

  ## Key Components

  ### Request Builder API

  The `Supabase.Fetcher.Request` provides a composable API for constructing HTTP requests. Each step updates the request builder state:

  - `with_<service>_url/2`: Appends the path to a service-specific base URL, available services can be consulted on `Supabase.services()` typespec.
  - `with_method/2`: Sets the HTTP method (`:get`, `:post`, etc.).
  - `with_headers/2`: Appends or overrides headers.
  - `with_body/2`: Sets the request body, supporting JSON, iodata, or streams.
  - `with_query/2`: Adds query parameters.
  - `with_body_decoder/3`: Registers a custom body decoder to be hooked into the response, defaults to `Supabase.Fetcher.JSONDecoder`.
  - `with_error_parser/2`: Registers a custom error parser to be hooked into the response, defaults to `Supabase.ErrorParser`.

  ### Custom HTTP Clients

  `Supabase.Fetcher.Request` depends on a  `Supabase.Fetcher.Adapter` implementation to dispatch HTTP requests, check `Supabase.Fetcher` module documentation for more info.

  ### Decoders and Parsers

  - **Body Decoder**: Custom modules implementing the `Supabase.Fetcher.BodyDecoder` behaviour can decode response bodies into application-specific formats.
  - **Error Parser**: Handle service-specific errors using `Supabase.Error` implementations, ensuring consistent error reporting across services.

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
  alias Supabase.Fetcher

  @behaviour Supabase.Fetcher.Request.Behaviour

  @type t :: %__MODULE__{
          client: Client.t(),
          method: Supabase.Fetcher.method(),
          body: Supabase.Fetcher.body(),
          headers: Supabase.Fetcher.headers(),
          url: Supabase.Fetcher.url(),
          service: Supabase.service(),
          query: Supabase.Fetcher.query(),
          body_decoder: module,
          body_decoder_opts: keyword,
          error_parser: module,
          http_client: module
        }

  defstruct [
    :url,
    :service,
    :client,
    :body,
    method: :get,
    query: [],
    headers: [],
    body_decoder_opts: [],
    body_decoder: Supabase.Fetcher.JSONDecoder,
    error_parser: Supabase.ErrorParser,
    http_client: Supabase.Fetcher.Adapter.Finch
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
  to the `Supabase.Fetcher.JSONDecoder`, or it can be a 2-arity function that will follow the `Supabase.Fetcher.BodyDecoder.decode/1` callback interface.

  You can pass `nil` as the decoder to avoid body decoding, if you need the raw body.
  """
  @impl true
  def with_body_decoder(%__MODULE__{} = builder, decoder, decoder_opts \\ [])
      when (is_atom(decoder) or is_function(decoder, 2)) and is_list(decoder_opts) do
    %{builder | body_decoder: decoder, body_decoder_opts: decoder_opts}
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
  def with_method(%__MODULE__{} = builder, method \\ :get)
      when method in ~w(get put post patch delete head)a do
    %{builder | method: method}
  end

  @doc """
  Registers a custom HTTP client backend to be used by `Supabase.Fetcher` while
  dispatching the request. The default one is `Supabase.Fetcher.Adapter.Finch`
  """
  @impl true
  def with_http_client(%__MODULE__{} = builder, adapter) when is_atom(adapter) do
    %{builder | http_client: adapter}
  end

  @doc """
  Append query params to the current request builder, it receives an `Enumerable.t()`
  and accumulates it into the current request. This function behaves the same as
  `with_headers/2`, so it is **rigt-associative**, meaning that duplicate keys
  informed will overwrite the last value.

  Finally, before the request is sent, the query will be encoded with `URI.encode_query/1`
  """
  @impl true
  def with_query(%__MODULE__{} = builder, query)
      when is_map(query) or is_list(query) do
    %{builder | query: Fetcher.merge_headers(builder.query, query)}
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
    %{builder | headers: Fetcher.merge_headers(builder.headers, headers)}
  end

  @doc """
  Tries to find and return the value for a query param, given it name, if it doesn't
  existis, it returns the default value informed or `nil`.
  """
  @spec get_query_param(t, param :: String.t(), default :: String.t() | nil) :: String.t() | nil
  def get_query_param(%__MODULE__{} = builder, key, default \\ nil)
      when is_binary(key) and (is_binary(default) or is_nil(default)) do
    case List.keyfind(builder.query, key, 0) do
      nil -> default
      {^key, value} -> value
    end
  end

  @doc """
  Tries to find and return the value for a request headers, given it name, if it doesn't
  existis, it returns the default value informed or `nil`.

  Do not confuse with `Supabase.Response.get_header/2`.
  """
  @spec get_header(t, name :: String.t(), default :: String.t() | nil) :: String.t() | nil
  def get_header(%__MODULE__{} = builder, key, default \\ nil)
      when is_binary(key) and (is_binary(default) or is_nil(default)) do
    case List.keyfind(builder.headers, key, 0) do
      nil -> default
      {^key, value} -> value
    end
  end

  @doc """
  Merges an existing query param value with a new one, prepending the new value
  with the existing one. If no current value exists for the param, this function
  will behave the same as `with_query/2`.
  """
  @spec merge_query_param(t, param :: String.t(), value :: String.t(),
          with: joinner :: String.t()
        ) :: t
  def merge_query_param(%__MODULE__{} = builder, key, value, [with: w] \\ [with: ","])
      when is_binary(key) and is_binary(value) and is_binary(w) do
    if curr = get_query_param(builder, key) do
      with_query(builder, %{key => Enum.join([curr, value], w)})
    else
      with_query(builder, %{key => value})
    end
  end

  @doc """
  Merges an existing request header value with a new one, prepending the new value
  with the existing one. If no current value exists for the header, this function
  will behave the same as `with_headers/2`.
  """
  @spec merge_req_header(t, header :: String.t(), value :: String.t(),
          with: joinner :: String.t()
        ) :: t
  def merge_req_header(%__MODULE__{} = builder, key, value, [with: w] \\ [with: ","])
      when is_binary(key) and is_binary(value) and is_binary(w) do
    if curr = get_header(builder, key) do
      with_headers(builder, %{key => Enum.join([curr, value], w)})
    else
      with_headers(builder, %{key => value})
    end
  end

  defimpl Inspect, for: __MODULE__ do
    import Inspect.Algebra

    def inspect(%Supabase.Fetcher.Request{} = fetcher, opts) do
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
        "#Supabase.Fetcher.Request<",
        to_doc(fields, opts),
        ">"
      ])
    end

    defp format_headers(headers) when is_list(headers) do
      Enum.map_join(headers, ", ", fn {k, v} -> "#{k}=#{v}" end)
    end
  end
end
