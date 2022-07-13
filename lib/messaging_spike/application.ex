defmodule MessagingSpike.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      MessagingSpikeWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: MessagingSpike.PubSub},
      MessagingSpike.Brokers.Rabbit,
      MessagingSpike.Settings,
      MessagingSpike.Brokers.Nats,
      MessagingSpike.Brokers.Redis,
      MessagingSpike.Scheduler,
      # Start the Endpoint (http/https)
      MessagingSpikeWeb.Endpoint
      # Start a worker by calling: MessagingSpike.Worker.start_link(arg)
      # {MessagingSpike.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MessagingSpike.Supervisor]
    result = Supervisor.start_link(children, opts)
    MessagingSpike.Listeners.init()
    MessagingSpike.Scheduler.go()
    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MessagingSpikeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
