defmodule Supabase.Fetcher.BodyDecoder do
  @moduledoc """
  Behaviour to define custom body decoders to a HTTP response

  TO define a custom body decoder you need to implement this behaviour and
  register it into the request builder that will use it, for example, for a custom
  JSONDecoder:

      defmodule MyJSONDecoder do
        @behaviour Supabase.Fetcher.BodyDecoder

        @impl true
        def decode(%Finch.Response{} = resp, opts) do
        end
      end

  When registering custom body decoder, you can pass it custom options as keyword list
  so they'll be available as the second parameter of the `decode/2` behaviour function.
  """

  @callback decode(Finch.Response.t(), options) :: {:ok, body :: term} | {:error, term}
    when options: keyword
end

defmodule Supabase.Fetcher.JSONDecoder do
  @moduledoc "The default body decoder to HTTP responses"

  @behaviour Supabase.Fetcher.BodyDecoder

  @doc "Tries to decode the response body as JSON"
  @impl true
  def decode(%Finch.Response{body: body}, opts \\ []) do
    keys = Keyword.get(opts, :keys, "strings")
    Jason.decode(body, keys: keys)
  end
end
