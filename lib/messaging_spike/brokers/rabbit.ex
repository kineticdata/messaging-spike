defmodule MessagingSpike.Brokers.Rabbit do
  use GenServer

  # Api

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def rpc(topic, payload) do
    correlation_id = :erlang.unique_integer() |> :erlang.integer_to_binary() |> Base.encode64()

    GenServer.call(__MODULE__, {:rpc_publish, topic, payload, correlation_id, self()})

    receive do
      anything -> anything
    end
  end

  def publish(topic, payload, correlation_id \\ nil) do
    GenServer.call(__MODULE__, {:publish, topic, payload, correlation_id})
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

  def declare(topic, is_delete) do
    GenServer.call(__MODULE__, {:declare, topic, is_delete})
  end

  def declare_exchange(name) do
    GenServer.call(__MODULE__, {:declare_exchange, name})
  end

  def bind(queue_name, exchange_name) do
    GenServer.call(__MODULE__, {:bind, queue_name, exchange_name})
  end

  def update_settings(settings_map) do
    GenServer.call(__MODULE__, {:update_settings, :erlang.term_to_binary(settings_map)})
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

    {:ok, %{queue: reply_queue}} = AMQP.Queue.declare(chan, "", auto_delete: true)

    {:ok, _sub_tag} = AMQP.Basic.consume(chan, reply_queue)

    {:ok, {chan, reply_queue, %{}}}
  end

  def handle_call(command, _from, state = {chan, reply_queue, pid_map}) do
    case command do
      {:publish, topic, payload, correlation_id} ->
        {:reply, AMQP.Basic.publish(chan, "", topic, payload, correlation_id: correlation_id),
         state}

      {:rpc_publish, topic, payload, correlation_id, pid} ->
        {:reply,
         AMQP.Basic.publish(chan, "", topic, payload,
           correlation_id: correlation_id,
           reply_to: reply_queue
         ), {chan, reply_queue, Map.put(pid_map, correlation_id, pid)}}

      {:rpc_reply, correlation_id, payload} ->
        pid = Map.get(pid_map, correlation_id)
        send(pid, payload)
        {:reply, nil, state}

      {:dequeue, topic} ->
        {:reply, AMQP.Basic.get(chan, topic), state}

      {:add, queue} ->
        {:reply, AMQP.Queue.declare(chan, queue), state}

      {:subscribe, topic, fun} ->
        {:reply, AMQP.Queue.subscribe(chan, topic, fun), state}

      {:declare, topic, is_delete} ->
        {:reply, AMQP.Queue.declare(chan, topic, durable: true, auto_delete: is_delete), state}

      {:declare_exchange, name} ->
        {:reply, AMQP.Exchange.declare(chan, name, :fanout), state}

      {:bind, queue_name, exchange_name} ->
        {:reply, AMQP.Queue.bind(chan, queue_name, exchange_name), state}

      {:ack, delivery_tag} ->
        {:reply, AMQP.Basic.ack(chan, delivery_tag), state}

      {:update_settings, settings_map} ->
        {:reply, AMQP.Basic.publish(chan, "broadcast", "", settings_map), state}
    end
  end

  def handle_info(message, state = {_chan, _reply_queue, pid_map}) do
    case message do
      {:basic_consume_ok, %{consumer_tag: _tag}} ->
        {:noreply, state}

      {:basic_deliver, message, meta} ->
        send(Map.get(pid_map, Map.get(meta, :correlation_id)), message)
        {:noreply, state}
    end
  end
end
