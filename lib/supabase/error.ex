defmodule Supabase.Error do
  @moduledoc """
  Represents and centralizes error responses within the Supabase ecosystem.

  The `Supabase.Error` struct is a unified way to handle error responses, 
  providing fields to represent key attributes of an error while remaining flexible 
  enough to accommodate custom implementations.

  ## Fields

  - `code` (atom): A semantic representation of the error code, e.g., `:not_found` or `:unauthorized`.
  - `message` (String.t): A human-readable message describing the error.
  - `service` (Supabase.service()): The service from which the error originated (e.g., `:auth`, `:storage`).
  - `metadata` (map): Additional information to provide context about the error, 
    such as the request path, headers, or response body.

  ## Example

      %Supabase.Error{
        code: :not_found,
        message: "Resource Not Found",
        service: :storage,
        metadata: %{
          path: "/api/resource",
          req_body: %{},
          resp_body: "Not found",
          headers: [{"content-type", "application/json"}]
        }
      }

  ## Custom Error Handling

  Libraries or users may define custom error parsers by implementing the 
  `Supabase.Error` behaviour's `from/2` callback from the `Supabase.ErrorParser`
  protocol.
  This enables the transformation of ANY structure into meaningful errors 
  specific to their application domain.
  """

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response

  @type t :: %__MODULE__{
          code: atom,
          message: String.t(),
          service: Supabase.service() | nil,
          metadata: map
        }

  defstruct [:message, :service, code: :unexpected, metadata: %{}]

  @doc "Callback used on invoking the HTTP error parsed on a response (status >= 400)"
  @callback from(source :: term, context :: term) :: t

  @doc "Creates a new `Supabase.Error` struct based on informed options"
  @spec new(keyword) :: t
  def new(attrs) when is_list(attrs) do
    code = Keyword.get(attrs, :code, :unexpected)
    message = Keyword.get(attrs, :message, humanize_error_code(code))
    service = Keyword.get(attrs, :service)
    metadata = Keyword.get(attrs, :metadata, %{})

    %__MODULE__{code: code, message: message, service: service, metadata: metadata}
  end

  @doc "Helper to just transform an atom code into a more human-friendly string"
  @spec humanize_error_code(atom) :: String.t()
  def humanize_error_code(code) when is_atom(code) do
    code
    |> Atom.to_string()
    |> String.split("_", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Helper function to construct the metadata fields for when building
  an error from a HTTP response, based into the "context", aka `Supabase.Request`.
  """
  @spec make_default_http_metadata(Supabase.Fetcher.Request.t()) :: map
  def make_default_http_metadata(%Supabase.Fetcher.Request{} = ctx) do
    service_key = if service = ctx.service, do: :"#{service}_url"
    base_url = Map.get(ctx.client, service_key)
    path = String.replace(to_string(ctx.url), base_url, "")
    headers = Enum.reject(ctx.headers, &(String.downcase(elem(&1, 0)) == "authorization"))

    %{
      path: path,
      req_body: ctx.body,
      headers: headers
    }
  end

  defimpl Inspect, for: Supabase.Error do
    import Inspect.Algebra

    def inspect(
          %Supabase.Error{code: code, message: message, service: service, metadata: metadata},
          opts
        ) do
      concat([
        "#Supabase.Error<",
        to_doc([code: code, message: message, service: service], opts),
        if(metadata != %{}, do: concat([", metadata: ", to_doc(metadata, opts)]), else: ""),
        ">"
      ])
    end
  end
end

defmodule Supabase.HTTPErrorParser do
  @moduledoc """
  The default error parser in case no one is provided via `Supabase.Fetcher.with_error_parser/2`.

  Error parsers should be implement firstly by adjacent services libraries, to
  handle service-specific error like for authentication or storage, although
  a final user could easily attach their own custom error parser.

  The default error parser define the `code` and `message` fields based into
  the HTTP Status.

  The default `metadata` format is:

      %{
        path: "The URL path appended to the base_url in request",
        req_body: "The request body, encoded as iodata or binary",
        resp_body: "The response body as it is",
        # headers is a list of tuples (String.t, String.t)
        # the `authorization` header is removed from it
        headers: []
      }

  All other fields are filled with the `Supabase.Request` struct as context,
  if available.
  """

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response

  @behaviour Supabase.Error

  def from(%Response{} = resp, %Request{service: service} = ctx)
      when resp.status >= 400 do
    code = parse_status(resp.status)
    metadata = Supabase.Error.make_default_http_metadata(ctx)
    metadata = Map.merge(metadata, %{resp_status: resp.status, resp_body: resp.body})

    Supabase.Error.new(code: code, service: service, metadata: metadata)
  end

  defp parse_status(400), do: :bad_request
  defp parse_status(401), do: :unauthorized
  defp parse_status(403), do: :forbidden
  defp parse_status(404), do: :not_found
  defp parse_status(405), do: :method_not_allowed
  defp parse_status(409), do: :resource_already_exists
  defp parse_status(411), do: :missing_content_length
  defp parse_status(413), do: :content_too_large
  defp parse_status(416), do: :invalid_range
  defp parse_status(422), do: :unprocessable_entity
  defp parse_status(423), do: :resource_locked
  defp parse_status(429), do: :too_many_requests
  defp parse_status(500), do: :server_error
  defp parse_status(501), do: :not_implemented
  defp parse_status(503), do: :service_unavailable
  defp parse_status(504), do: :gateway_timeout
  defp parse_status(_), do: :unexpected
end
