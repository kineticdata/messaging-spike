defmodule MessagingSpike.Brokers.Rabbit do
  use GenServer

  # Api

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def publish(topic, payload) do
    GenServer.call(__MODULE__, {:publish, topic, payload})
  end

  def subscribe(topic, fun) do
    GenServer.call(__MODULE__, {:subscribe, topic, fun})
  end

  # Callbacks

  def init(_init_arg) do
    {:ok,
     [
       host: host,
       port: port,
       username: _username,
       password: _password
     ]} = Application.fetch_env(:messaging_spike, __MODULE__)

    {:ok, conn} = AMQP.Connection.open("amqp://#{host}:#{port}")
    {:ok, chan} = AMQP.Channel.open(conn)
    {:ok, {chan}}
  end

  def handle_call(command, _from, {chan}) do
    result =
      case command do
        {:publish, topic, payload} ->
          AMQP.Basic.publish(chan, topic, "", payload)

        {:subscribe, topic, fun} ->
          AMQP.Queue.subscribe(chan, topic, fun)

        {:get_conn} ->
          chan
      end

    {:reply, result, {chan}}
  end
end
