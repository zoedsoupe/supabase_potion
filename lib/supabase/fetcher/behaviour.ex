defmodule Supabase.Fetcher.Behaviour do
  @moduledoc "Defines Supabase HTTP Clients callbacks"

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response

  @type on_response_input ::
          {Supabase.Fetcher.status(), Supabase.Fetcher.headers(), body :: Enumerable.t()}
  @typedoc """
  The response handler for streaming responses. It receives the response status, headers, and body as input.

  Note that here only the status and headers are consumed from the stream and so the body reamins unconsumed for custom operations, receiving each chunk of the body as it arrives.

  It needs to return either `:ok` or `{:ok, body}` or `{:error, Supabase.Error}`.
  """
  @type on_response :: (on_response_input -> :ok | {:ok, term} | {:error, Supabase.Error.t()})

  @callback request(Request.t()) :: Supabase.result(Response.t())
  @callback request_async(Request.t()) :: Supabase.result(Response.t())
  @callback upload(Request.t(), filepath :: Path.t()) :: Supabase.result(Response.t())
  @callback stream(Request.t()) :: Supabase.result(Response.t())
  @callback stream(Request.t(), on_response) :: Supabase.result(Response.t())
end
