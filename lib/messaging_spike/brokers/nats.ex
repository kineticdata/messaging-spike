defmodule MessagingSpike.Brokers.Nats do
  use GenServer
  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # API

  def get_conn do
    GenServer.call(__MODULE__, {:get_conn})
  end

  def subscribe(topic, fun, options \\ []) do
    GenServer.cast(__MODULE__, {:subscribe, topic, fun, options})
  end

  def publish(topic, message) do
    GenServer.cast(__MODULE__, {:publish, topic, message})
  end

  def request(topic, message) do
    {:ok, result} = Gnat.request(get_conn(), topic, message)
    Map.get(result, :body)
  end

  # Callbacks

  def init(_init_arg) do
    Process.flag(:trap_exit, true)
    {:ok, connect()}
  end

  def handle_call(_, _, state = {nil, _}) do
    {:reply, {:error, "Nats service is unavailable"}, state}
  end

  def handle_call({:get_conn}, _from, state = {conn, _funs}) do
    {:reply, conn, state}
  end

  def handle_cast({:retry_connection}, _state) do
    {:noreply, connect()}
  end

  def handle_cast(_, state = {nil, _}) do
    {:noreply, state}
  end

  def handle_cast({:publish, topic, message}, state = {conn, _funs}) do
    Gnat.pub(conn, topic, message)
    {:noreply, state}
  end

  def handle_cast({:subscribe, topic, fun, options}, {conn, funs}) do
    {:ok, sid} = Gnat.sub(conn, self(), topic, options)
    {:noreply, {conn, Map.put(funs, sid, fun)}}
  end

  def handle_info({:msg, %{body: body, sid: sid, reply_to: reply_to}}, state = {_conn, funs}) do
    fun = Map.get(funs, sid)

    if reply_to do
      fun.(body, reply_to)
    else
      fun.(body)
    end

    {:noreply, state}
  end

  def handle_info({:EXIT, conn, "connection closed"}, {conn, _}) do
    :timer.apply_after(5000, GenServer, :cast, [__MODULE__, {:retry_connection}])
    {:noreply, {nil, %{}}}
  end

  def handle_info({:EXIT, _, :econnrefused}, _) do
    :timer.apply_after(5000, GenServer, :cast, [__MODULE__, {:retry_connection}])
    {:noreply, {nil, %{}}}
  end

  def handle_info({:EXIT, _, :timeout}, _) do
    :timer.apply_after(5000, GenServer, :cast, [__MODULE__, {:retry_connection}])
    {:noreply, {nil, %{}}}
  end


  def nats_port do
    env_port = System.get_env("NATS_PORT")

    if is_nil(env_port) do
      4222
    else
      String.to_integer(env_port)
    end
  end

  defp connect do
    host = System.get_env("NATS_HOST") || "localhost"
    port = nats_port()

    with {:ok, conn} <- Gnat.start_link(%{host: host, port: port}) do
      {conn, %{}}
    else
      e ->
        Logger.error("Error connecting to nats #{inspect(e)}")
        {nil, %{}}
    end
  end
end
