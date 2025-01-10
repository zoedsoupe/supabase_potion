defmodule Supabase.Fetcher.Request.Behaviour do
  @moduledoc false

  alias Supabase.Fetcher.Request

  @callback new(Supabase.Client.t()) :: Request.t()
  @callback with_method(Request.t(), method) :: Request.t()
            when method: Supabase.Fetcher.method()
  @callback with_database_url(Request.t(), path :: String.t()) :: Request.t()
  @callback with_storage_url(Request.t(), path :: String.t()) :: Request.t()
  @callback with_realtime_url(Request.t(), path :: String.t()) :: Request.t()
  @callback with_functions_url(Request.t(), path :: String.t()) :: Request.t()
  @callback with_auth_url(Request.t(), path :: String.t()) :: Request.t()
  @callback with_http_client(Request.t(), adapter :: module) :: Request.t()
  @callback with_query(Request.t(), query :: Enumerable.t()) :: Request.t()
  @callback with_body(Request.t(), body) :: Request.t()
            when body: Jason.Encoder.t() | {:stream, Enumerable.t()} | nil
  @callback with_headers(Request.t(), headers) :: Request.t()
    when headers: Supabase.Fetcher.headers()
  @callback with_body_decoder(Request.t(), decoder, decoder_opts) :: Request.t()
            when decoder: module | decoder_fun,
                 decoder_opts: keyword,
                 decoder_fun: (Supabase.Fetcher.response(), decoder_opts ->
                                 {:ok, body :: term} | {:error, term})
  @callback with_error_parser(Request.t(), parser :: module) :: Request.t()
end
