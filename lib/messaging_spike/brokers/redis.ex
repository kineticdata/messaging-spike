defmodule MessagingSpike.Brokers.Redis do
  use GenServer
  require Logger

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

  def unsubscribe(topic) do
    GenServer.call(__MODULE__, {:unsubscribe, topic})
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

    {:ok, conn} = Redix.start_link("redis://#{host}:#{port}")
    {:ok, pubsub} = Redix.PubSub.start_link("redis://#{host}:#{port}")

    {:ok, {conn, pubsub, %{}, %{}}}
  end

  def handle_call({:unsubscribe, topic}, _from, state = {_, pubsub, _, _}) do
    result = Redix.PubSub.unsubscribe(pubsub, topic, self())
    {:reply, result, state}
  end

  def handle_call({:publish, topic, payload}, _from, state = {conn, _, _, _}) do
    result = Redix.command(conn, ["PUBLISH", topic, payload])
    {:reply, result, state}
  end

  def handle_call(
        {:subscribe, topic, fun},
        _from,
        {conn, pubsub, pid_map, fun_map}
      ) do
    {:ok, ref} = Redix.PubSub.subscribe(pubsub, topic, self())
    {:reply, :ok, {conn, pubsub, pid_map, Map.put(fun_map, ref, fun)}}
  end

  def handle_info({:redix_pubsub, _, _, :subscribed, %{channel: channel}}, state) do
    Logger.info("Redis subscribed to #{channel}")
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _, ref, :message, %{channel: channel, payload: payload}}, state) do
    Logger.info("Redis received message on channel #{channel}: #{payload}")
    {_conn, _pubsub, _pid_map, fun_map} = state
    Map.get(fun_map, ref).(payload)
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, _ref, :unsubscribed, %{channel: channel}}, state) do
    Logger.info("Redis unsubscribed from #{channel}")
    {:noreply, state}
  end
end
