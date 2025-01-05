defmodule Supabase.Fetcher.BodyDecoder do
  @moduledoc "Behaviour to define custom body decoders to a HTTP response"

  @callback decode(Finch.Response.t()) :: {:ok, term} | {:error, term}
end

defmodule Supabase.Fetcher.JSONDecoder do
  @moduledoc "The default body decoder to HTTP responses"

  @behaviour Supabase.Fetcher.BodyDecoder

  @doc "Tries to decode the response body as JSON"
  @impl true
  def decode(%Finch.Response{body: body}) do
    Jason.decode(body)
  end
end
