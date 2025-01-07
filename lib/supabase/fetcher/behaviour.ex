defmodule Supabase.Fetcher.Behaviour do
  @moduledoc "Defines Supabase HTTP Clients callbacks"

  alias Supabase.Fetcher.Request
  alias Supabase.Fetcher.Response

  @callback request(Request.t()) :: Supabase.result(Response.t())
  @callback request_async(Request.t()) :: Supabase.result(Response.t())
  @callback upload(Request.t(), filepath :: Path.t()) :: Supabase.result(Response.t())
  @callback stream(Request.t()) :: Supabase.result(Response.t())
  @callback stream(Request.t(), on_response) :: Supabase.result(Response.t())
            when on_response: ({Supabase.Fetcher.status(), Supabase.Fetcher.headers(),
                                body :: Enumerable.t()} ->
                                 Supabase.result(Response.t()))
end
