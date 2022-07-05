defmodule MessagingSpike.Brokers.Rabbit do
  use GenServer

  # Api

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def rpc(topic, payload) do
    task =
      Task.async(fn ->
        pid = self()

        correlation_id =
          :erlang.unique_integer() |> :erlang.integer_to_binary() |> Base.encode64()

        GenServer.call(__MODULE__, {:rpc_publish, topic, payload, correlation_id, pid})

        message =
          receive do
            any -> any
          end

        message
      end)

    Task.await(task)
  end

  def rpc_reply(correlation_id, payload) do
    GenServer.call(__MODULE__, {:rpc_reply, correlation_id, payload})
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

  def ack(delivery_tag) do
    GenServer.call(__MODULE__, {:ack, delivery_tag})
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

    {:ok, %{queue: reply_queue}} =
      AMQP.Queue.declare(chan, "", exclusive: true, auto_delete: true)

    {:ok} =
      AMQP.Queue.subscribe(chan, reply_queue, fn message, meta ->
        rpc_reply(Map.get(meta, :correlation_id), message)
      end)

    {:ok, {chan, reply_queue, %{}}}
  end

  def handle_call(command, _from, {chan, reply_queue, pid_map}) do
    new_pid_map = pid_map

    result =
      case command do
        {:publish, topic, payload} ->
          AMQP.Basic.publish(chan, "", topic, payload)

        {:rpc_publish, topic, payload, correlation_id, pid} ->
          new_pid_map = Map.put(pid_map, correlation_id, pid)

          AMQP.Basic.publish(chan, "", topic, payload,
            correlation_id: correlation_id,
            reply_to: reply_queue
          )

        {:rpc_reply, correlation_id, payload} ->
          pid = Map.get(pid_map, correlation_id)
          send(pid, payload)

        {:dequeue, topic} ->
          AMQP.Basic.get(chan, topic)

        {:add, queue} ->
          AMQP.Queue.declare(chan, queue)

        {:subscribe, topic, fun} ->
          AMQP.Queue.subscribe(chan, topic, fun)

        {:declare, topic} ->
          AMQP.Queue.declare(chan, topic, durable: true)

        {:ack, delivery_tag} ->
          AMQP.Basic.ack(chan, delivery_tag)
      end

    {:reply, result, {chan, reply_queue, new_pid_map}}
  end
end
