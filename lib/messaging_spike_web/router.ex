defmodule MessagingSpikeWeb.Router do
  use MessagingSpikeWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", MessagingSpikeWeb do
    pipe_through :api

    post("/blocking-request/:topic", MessageController, :blocking_request)
    # TODO: "/fire-and-forget/:topic"
    # put a map that writes to
    put("/settings", MessageController, :update_settings)
    put("/settings-nats", MessageController, :update_settings_nats)
    # get the settings map
    get("/settings", MessageController, :get_settings)
    # TODO: "/publish/:topic"
    # TODO: "/subscribe/:topic"
    # TODO: "/unsubscribe/:topic"
    get("/size/:input", MessageController, :size)
    post("/add/:queue", MessageController, :add)
    get("/dequeue/:topic", MessageController, :dequeue)
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: MessagingSpikeWeb.Telemetry
    end
  end
end
