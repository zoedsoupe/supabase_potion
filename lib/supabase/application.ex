defmodule Supabase.Application do
  @moduledoc false

  use Application

  @finch_opts [name: Supabase.Finch, pools: %{:default => [size: 10]}]

  @impl true
  def start(_start_type, _args) do
    children =
      [{Finch, @finch_opts}]
      |> maybe_append_child(fn e -> e == :dev end, SupabasePotion.Client)

    opts = [strategy: :one_for_one, name: Supabase.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @spec maybe_append_child(list(Supervisor.child_spec()), (env -> bool), Supervisor.child_spec()) ::
          list(Supervisor.child_spec())
        when env: :dev | :prod | :test
  defp maybe_append_child(children, pred, child) do
    env = get_env()

    if pred.(env), do: children ++ [child], else: children
  end

  defp get_env, do: Application.get_env(:supabase_potion, :env, :dev)
end
