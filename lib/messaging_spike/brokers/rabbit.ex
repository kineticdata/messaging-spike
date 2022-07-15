defmodule MessagingSpike.Brokers.Rabbit do
  use GenServer
  require Logger

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

  def declare(topic, is_delete) do
    GenServer.call(__MODULE__, {:declare, topic, is_delete})
  end

  def declare_exchange(name) do
    GenServer.call(__MODULE__, {:declare_exchange, name})
  end

  def bind(queue_name, exchange_name) do
    GenServer.call(__MODULE__, {:bind, queue_name, exchange_name})
  end

  # Callbacks

  def init(_init_arg) do
    {:ok, connect()}
  end

  def handle_call(_, _, state = {nil, _, _}) do
    {:reply, {:error, "Rabbit service is unavailable"}, state}
  end

  def handle_call({:publish, topic, payload}, _from, state = {chan, _, _}) do
    {:reply, AMQP.Basic.publish(chan, "", topic, payload), state}
  end

  def handle_call(
        {:rpc_publish, topic, payload, correlation_id, pid},
        _from,
        {chan, reply_queue, pid_map}
      ) do
    {:reply,
     AMQP.Basic.publish(chan, "", topic, payload,
       correlation_id: correlation_id,
       reply_to: reply_queue
     ), {chan, reply_queue, Map.put(pid_map, correlation_id, pid)}}
  end

  def handle_call({:dequeue, topic}, _from, state = {chan, _, _}),
    do: {:reply, AMQP.Basic.get(chan, topic), state}

  def handle_call({:add, queue}, _from, state = {chan, _, _}) do
    {:reply, AMQP.Queue.declare(chan, queue), state}
  end

  def handle_call({:subscribe, topic, fun}, _from, state = {chan, _, _}) do
    {:reply, AMQP.Queue.subscribe(chan, topic, fun), state}
  end

  def handle_call({:declare, topic, is_delete}, _from, state = {chan, _, _}) do
    {:reply, AMQP.Queue.declare(chan, topic, durable: true, auto_delete: is_delete), state}
  end

  def handle_call({:declare_exchange, name}, _from, state = {chan, _, _}) do
    {:reply, AMQP.Exchange.declare(chan, name, :fanout), state}
  end

  def handle_call({:bind, queue_name, exchange_name}, _from, state = {chan, _, _}) do
    {:reply, AMQP.Queue.bind(chan, queue_name, exchange_name), state}
  end

  def handle_cast({:retry_connection}, _state) do
    {:noreply, connect()}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, message, meta}, state = {_chan, _reply_queue, pid_map}) do
    send(Map.get(pid_map, Map.get(meta, :correlation_id)), message)
    {:noreply, state}
  end

  def handle_info(
        {:EXIT, _pid,
         {:shutdown, {:connection_closing, {:server_initiated_close, 320, _message}}}},
        _state
      ) do
    :timer.apply_after(5000, GenServer, :cast, [__MODULE__, {:retry_connection}])
    {:noreply, {nil, nil, %{}}}
  end

  defp connect do
    host = System.get_env("RABBIT_HOST") || "localhost"
    port = System.get_env("RABBIT_PORT") || 5672

    with {:ok, conn} <- AMQP.Connection.open("amqp://#{host}:#{port}"),
         {:ok, chan} <- AMQP.Channel.open(conn),
         {:ok, %{queue: reply_queue}} <- AMQP.Queue.declare(chan, "", auto_delete: true),
         {:ok, _reply_sub_tag} <- AMQP.Basic.consume(chan, reply_queue) do
      AMQP.Queue.declare(chan, "heartbeat")
      Process.flag(:trap_exit, true)
      Process.link(Map.get(chan, :pid))
      {chan, reply_queue, %{}}
    else
      e ->
        Logger.error("Error connecting to rabbit #{inspect(e)}")
        :timer.apply_after(5000, GenServer, :cast, [__MODULE__, {:retry_connection}])
        {nil, nil, %{}}
    end
  end
end
