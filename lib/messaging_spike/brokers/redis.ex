defmodule MessagingSpike.Brokers.Redis do
  use GenServer
  require Logger

  # Api

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def rpc(topic, payload) do
    correlation_id = :erlang.unique_integer() |> :erlang.integer_to_binary() |> Base.encode64()

    GenServer.call(__MODULE__, {:rpc_publish, topic, payload, correlation_id, self()})
  end

  def publish(topic, payload, correlation_id \\ nil) do
    GenServer.call(__MODULE__, {:publish, topic, payload, correlation_id})
  end

  def subscribe(topic) do
    GenServer.call(__MODULE__, {:subscribe, topic})
  end

  def unsubscribe(topic) do
    GenServer.call(__MODULE__, {:unsubscribe, topic})
  end

  # Callbacks

  def init(_init_arg) do
    {:ok,
     [
       host: host,
       port: port
     ]} = Application.fetch_env(:messaging_spike, __MODULE__)

    {:ok, conn} = Redix.start_link("redis://#{host}:#{port}")
    {:ok, pubsub} = Redix.PubSub.start_link("redis://#{host}:#{port}")

    {:ok, {conn, pubsub, %{}}}
  end

  def handle_call(command, _from, state = {conn, pubsub, pid_map}) do
    case command do
      {:unsubscribe, topic} ->
        Redix.PubSub.unsubscribe(pubsub, topic, self())
        {:reply, :ok, state}

      {:publish, topic, payload, correlation_id} ->
        Redix.command!(conn, ["PUBLISH", topic, "#{payload}, correlation_id: #{correlation_id}"])
        {:reply, :ok, state}

      {:rpc_publish, topic, payload, correlation_id, pid} ->
        Logger.info(
          "publishing to #{topic}, expecting reply on reply_to queue, pid map #{inspect(pid_map)}"
        )

        Redix.command!(conn, [
          "PUBLISH",
          topic,
          "#{payload}, correlation_id: #{correlation_id}, reply_to: reply_queue"
        ])

        {:reply, :ok, {conn, pubsub, Map.put(pid_map, correlation_id, pid)}}

      {:rpc_reply, correlation_id, payload} ->
        pid = Map.get(pid_map, correlation_id)
        send(pid, payload)
        {:noreply, state}

      {:subscribe, topic} ->
        {:ok, _} = Redix.PubSub.subscribe(pubsub, topic, self())
        {:reply, :ok, state}
    end
  end

  def handle_info({:redix_pubsub, _, _, :subscribed, %{channel: channel}}, state) do
    Logger.info("subscribed to #{channel}")
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _, _, :message, %{channel: channel, payload: payload}}, state) do
    Logger.info("received message on channel #{channel}: #{payload}")
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, _ref, :unsubscribed, %{channel: channel}}, state) do
    Logger.info("unsubscribed from #{channel}")
    {:noreply, state}
  end
end
