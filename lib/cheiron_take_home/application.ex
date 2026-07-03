defmodule CheironTakeHome.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CheironTakeHomeWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:cheiron_take_home, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CheironTakeHome.PubSub},
      # Start a worker by calling: CheironTakeHome.Worker.start_link(arg)
      # {CheironTakeHome.Worker, arg},
      # Start to serve requests, typically the last entry
      CheironTakeHomeWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CheironTakeHome.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CheironTakeHomeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
