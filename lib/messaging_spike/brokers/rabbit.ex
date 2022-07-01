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

    # {:ok, _consumer_tag} =
    #   AMQP.Queue.subscribe(chan, "faq", fn payload, _meta ->
    #     IO.inspect(:erlang.binary_to_term(payload))
    #   end)

    {:ok, {chan}}
  end

  def handle_call(command, _from, {chan}) do
    result =
      case command do
        {:publish, topic, payload} -> AMQP.Basic.publish(chan, topic, "", payload)
        {:dequeue, topic} -> AMQP.Basic.get(chan, topic)
        {:add, queue} -> AMQP.Queue.declare(chan, queue)
      end

    {:reply, result, {chan}}
  end
end
