defmodule Arcane.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ArcaneWeb.Telemetry,
      Arcane.Repo,
      {DNSCluster, query: Application.get_env(:arcane, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Arcane.PubSub},
      # Start a worker by calling: Arcane.Worker.start_link(arg)
      # {Arcane.Worker, arg},
      # Start to serve requests, typically the last entry
      ArcaneWeb.Endpoint,
      Arcane.Supabase.Client
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Arcane.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ArcaneWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
