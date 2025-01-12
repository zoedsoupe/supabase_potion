defmodule Supabase.Fetcher.Response do
  @moduledoc """
  Defines a common structure to operate on HTTP responses from different
  HTTP clients backends and also defines helper functions to operate this
  same structure
  """

  @type t :: %__MODULE__{
          status: Supabase.Fetcher.status(),
          headers: Supabase.Fetcher.headers(),
          body: Supabase.Fetcher.body()
        }

  defstruct [:status, :headers, :body]

  @doc """
  Helper function to directly decode the body using a `Supabase.Fetcher.BodyDecoder`
  """
  @spec decode_body(t, module | nil | fun, decoder_opts :: keyword) :: Supabase.result(t)
  def decode_body(resp, decoder \\ Supabase.Fetcher.JSONDecoder, opts \\ [])

  def decode_body(%__MODULE__{} = resp, decoder, opts)
      when is_function(decoder, 2) do
    with {:ok, body} <- decoder.(resp, opts), do: {:ok, %{resp | body: body}}
  end

  def decode_body(%__MODULE__{} = resp, nil, _opts) do
    {:ok, resp}
  end

  def decode_body(%__MODULE__{} = resp, decoder, opts) do
    with {:ok, body} <- decoder.decode(resp, opts), do: {:ok, %{resp | body: body}}
  end

  @doc """
  Helper function to get a specific header value from a response.
  """
  @spec get_header(t, String.t()) :: String.t() | nil
  @spec get_header(t, String.t(), String.t()) :: String.t() | nil
  def get_header(%__MODULE__{headers: headers}, header) do
    if h = Enum.find(headers, &(elem(&1, 0) == header)) do
      elem(h, 1)
    else
      nil
    end
  end

  def get_header(%__MODULE__{} = resp, header, default) do
    get_header(resp, header) || default
  end
end

defprotocol Supabase.Fetcher.ResponseAdapter do
  @doc "Normalizes a client-specific response into a Supabase.Fetcher.Response struct."
  @spec from(Supabase.Fetcher.Adapter.response()) :: Supabase.Fetcher.Response.t()
  def from(response)
end
