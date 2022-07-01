defmodule MessagingSpikeWeb.MessageController do
  use MessagingSpikeWeb, :controller

  alias MessagingSpike.Brokers.Rabbit

  def blocking_request(conn, params = %{"topic" => topic}) do
    Rabbit.publish(topic, :erlang.term_to_binary(params))
    Plug.Conn.send_resp(conn, 200, Jason.encode!(params))
  end

  def dequeue(conn, _params = %{"topic" => topic}) do
    {:ok, payload, _meta} = Rabbit.dequeue(topic)
    Plug.Conn.send_resp(conn, 200, Jason.encode!(payload))
  end

  def add(conn, %{"queue" => queue}) do
    Rabbit.add(queue)
    Plug.Conn.send_resp(conn, 200, "success")
  end
end
