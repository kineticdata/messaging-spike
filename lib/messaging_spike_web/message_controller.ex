defmodule MessagingSpikeWeb.MessageController do
  use MessagingSpikeWeb, :controller

  alias MessagingSpike.Brokers.Rabbit

  def blocking_request(conn, params = %{"topic" => topic}) do
    Rabbit.publish(topic, "Hello World")
    Plug.Conn.send_resp(conn, 200, Jason.encode!(params))
  end
end
