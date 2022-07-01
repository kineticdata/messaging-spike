defmodule MessagingSpikeWeb.MessageController do
  use MessagingSpikeWeb, :controller

  alias MessagingSpike.Brokers.Rabbit

  def blocking_request(conn, params = %{"topic" => topic}) do
    Rabbit.publish(topic, :erlang.term_to_binary(params))
    Plug.Conn.send_resp(conn, 200, Jason.encode!(params))
  end
end
