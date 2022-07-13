defmodule MessagingSpike.Brokers.Nats do
  use GenServer

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
    {:ok,
     [
       host: host,
       port: port,
       username: _username,
       password: _password
     ]} = Application.fetch_env(:messaging_spike, __MODULE__)

    {:ok, conn} = Gnat.start_link(%{host: host, port: port})

    {:ok, {conn, %{}}}
  end

  def handle_call(request, _from, state = {conn, _funs}) do
    case request do
      {:get_conn} ->
        {:reply, conn, state}
    end
  end

  def handle_cast(request, state = {conn, funs}) do
    case request do
      {:publish, topic, message} ->
        Gnat.pub(conn, topic, message)
        {:noreply, state}

      {:subscribe, topic, fun, options} ->
        {:ok, sid} = Gnat.sub(conn, self(), topic, options)
        {:noreply, {conn, Map.put(funs, sid, fun)}}
    end
  end

  def handle_info(info, state = {_conn, funs}) do
    case info do
      {:msg, %{body: body, sid: sid, reply_to: reply_to}} ->
        fun = Map.get(funs, sid)

        if reply_to do
          fun.(body, reply_to)
        else
          fun.(body)
        end

        {:noreply, state}
    end
  end
end
