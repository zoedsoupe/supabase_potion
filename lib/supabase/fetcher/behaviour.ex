defmodule Supabase.Fetcher.Behaviour do
  @moduledoc "Defines Supabase HTTP Clients callbacks"

  alias Supabase.Client
  alias Supabase.Error
  alias Supabase.Fetcher

  @type result(a) :: {:ok, a} | {:error, Error.t()}

  # builder functions
  @callback new(Client.t()) :: Fetcher.t()
  @callback with_method(Fetcher.t(), method) :: Fetcher.t()
            when method: Finch.Request.method()
  @callback with_database_url(Fetcher.t(), path :: String.t()) :: Fetcher.t()
  @callback with_storage_url(Fetcher.t(), path :: String.t()) :: Fetcher.t()
  @callback with_realtime_url(Fetcher.t(), path :: String.t()) :: Fetcher.t()
  @callback with_functions_url(Fetcher.t(), path :: String.t()) :: Fetcher.t()
  @callback with_auth_url(Fetcher.t(), path :: String.t()) :: Fetcher.t()
  @callback with_query(Fetcher.t(), query :: Enumerable.t()) :: Fetcher.t()
  @callback with_body(Fetcher.t(), body) :: Fetcher.t()
            when body: Jason.Encoder.t() | {:stream, Enumerable.t()} | nil
  @callback with_headers(Fetcher.t(), headers) :: Fetcher.t()
            when headers: Finch.Request.headers()
  @callback with_options(Fetcher.t(), options) :: Fetcher.t()
            when options: Finch.request_opts()
  @callback with_body_decoder(Fetcher.t(), decoder, decoder_opts) :: Fetcher.t()
            when decoder: module | decoder_fun,
                decoder_opts: keyword,
                decoder_fun: (Finch.Response.t, decoder_opts -> {:ok, body :: term} | {:error, term})
  @callback with_error_parser(Fetcher.t(), parser :: module) :: Fetcher.t()

  # general helpers
  @callback request(Fetcher.t()) :: result(Finch.Response.t())
  @callback request_async(Fetcher.t()) :: result(Finch.Response.t())
  @callback upload(Fetcher.t(), filepath :: Path.t()) :: result(Finch.Response.t())
  @callback stream(Fetcher.t()) :: result(Enumerable.t())
  @callback stream(Fetcher.t(), on_response) :: result(Enumerable.t())
            when on_response: ({status :: integer, headers :: Finch.Request.headers(),
                                body :: Enumerable.t()} ->
                                 term)
end
