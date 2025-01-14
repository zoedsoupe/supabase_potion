defmodule Supabase.Fetcher.Adapter do
  @moduledoc """
  Behaviour that defines the interface to implement different HTTP clients
  as backends for the `Supabase.Fetcher` request builder.
  """

  alias Supabase.Fetcher
  alias Supabase.Fetcher.Request

  @type response :: Fetcher.response()
  @type request_opts :: keyword

  @callback request(Request.t(), request_opts) :: {:ok, response} | {:error, term}
  @callback request_async(Request.t(), request_opts) :: {:ok, response} | {:error, term}
  @callback upload(Request.t(), filepath :: Path.t(), request_opts) ::
              {:ok, response} | {:error, term}
  @callback stream(Request.t(), request_opts) :: {:ok, response} | {:error, term}
  @callback stream(Request.t(), on_response, request_opts) :: {:ok, response} | {:error, term}
            when on_response: ({Fetcher.status(), Fetcher.headers(), body :: Enumerable.t()} ->
                                 {:ok, response} | {:error, term})

  @optional_callbacks request_async: 2, stream: 2, stream: 3

  @spec not_implemented_error(module, atom, integer) :: Supabase.Error.t()
  def not_implemented_error(module, fun, arity) do
    msg = "#{inspect(module)} doesn't implement Supabase.Fetcher.#{fun}/#{arity}"

    Supabase.Error.new(
      code: :non_implemented_function,
      message: msg,
      metadata: %{function: [{fun, arity}], http_client: module}
    )
  end

  defmacro __using__(_opts) do
    quote do
      alias Supabase.Fetcher.Adapter
      alias Supabase.Fetcher.Request

      @behaviour Supabase.Fetcher.Adapter

      @impl true
      def request_async(%Request{}, _opts) do
        {:error, Adapter.not_implemented_error(__MODULE__, :request_async, 2)}
      end

      @impl true
      def stream(%Request{}, _opts) do
        {:error, Adapter.not_implemented_error(__MODULE__, :stream, 2)}
      end

      @impl true
      def stream(%Request{}, _on_response, _opts) do
        {:error, Adapter.not_implemented_error(__MODULE__, :stream, 3)}
      end

      defoverridable Supabase.Fetcher.Adapter
    end
  end
end
