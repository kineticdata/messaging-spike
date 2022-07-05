defmodule MessagingSpike.Brokers.Rabbit do
  use GenServer

  # Api

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def publish(topic, payload) do
    GenServer.call(__MODULE__, {:publish, topic, payload})
  end

  def dequeue(topic) do
    GenServer.call(__MODULE__, {:dequeue, topic})
  end

  def add(queue) do
    GenServer.call(__MODULE__, {:add, queue})
  end

  def subscribe(topic, fun) do
    GenServer.call(__MODULE__, {:subscribe, topic, fun})
  end

  def declare(topic) do
    GenServer.call(__MODULE__, {:declare, topic})
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

        {:dequeue, topic} ->
          AMQP.Basic.get(chan, topic)

        {:add, queue} ->
          AMQP.Queue.declare(chan, queue)

        {:subscribe, topic, fun} ->
          AMQP.Queue.subscribe(chan, topic, fun)

        {:declare, topic} ->
          AMQP.Exchange.declare(chan, topic, :direct, durable: true)
          AMQP.Queue.declare(chan, topic, durable: true)
          AMQP.Queue.bind(chan, topic, topic)
      end

    {:reply, result, {chan}}
  end
end
