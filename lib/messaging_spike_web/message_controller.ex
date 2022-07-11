defmodule MessagingSpikeWeb.MessageController do
  use MessagingSpikeWeb, :controller

  alias MessagingSpike.Brokers.Rabbit
  alias MessagingSpike.Settings
  alias MessagingSpike.Brokers.Nats

  def blocking_request(conn, params = %{"topic" => topic}) do
    Rabbit.publish(topic, :erlang.term_to_binary(params), true)
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

  def size(conn, params) do
    result = Rabbit.rpc("size", Map.get(params, "input"))
    Plug.Conn.send_resp(conn, 200, result)
  end

  def check_token(conn, params) do
    result = Nats.request("check_token", Map.get(params, "token"))
    Plug.Conn.send_resp(conn, 200, result)
  end

  def update_settings(conn, params) do
    Rabbit.update_settings(params)
    Plug.Conn.send_resp(conn, 200, "success")
  end

  def update_settings_nats(conn, params) do
    Nats.publish("settings", :erlang.term_to_binary(params))
    Plug.Conn.send_resp(conn, 200, "success")
  end

  def update_settings_kafka(conn, params) do
    KafkaEx.produce("settings", 0, :erlang.term_to_binary(params))
    Plug.Conn.send_resp(conn, 200, "success")
  end

  def get_settings(conn, _params) do
    {:ok, settings} = Settings.get()
    {:ok, response_body} = Jason.encode(settings)
    Plug.Conn.send_resp(conn, 200, response_body)
  end
end
