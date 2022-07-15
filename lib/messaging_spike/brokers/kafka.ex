defmodule MessagingSpike.Brokers.Kafka do
  use GenServer
  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def publish(topic, message) do
    GenServer.call(__MODULE__, {:publish, topic, message})
  end

  def subscribe(topic, fun) do
    child =
      spawn(fn ->
        subscribe(topic)
        |> Stream.each(fun)
        |> Stream.run()
      end)

    {:ok, child}
  end

  def subscribe(topic) do
    GenServer.call(__MODULE__, {:subscribe, topic})
  end

  def init(_init_arg) do
    Process.flag(:trap_exit, true)
    {:ok, connect()}
  end

  def handle_call(_, _, {nil}) do
    {:reply, {:error, "Kafka service is unavailable"}, {nil}}
  end

  def handle_call({:publish, topic, message}, _from, {conn}) do
    result = KafkaEx.produce(topic, 0, message, worker_name: conn)
    {:reply, result, {conn}}
  end

  def handle_call({:subscribe, topic}, _from, {conn}) do
    result = KafkaEx.stream(topic, 0, worker_name: conn)
    {:reply, result, {conn}}
  end

  def handle_cast({:retry_connection}, _) do
    {:noreply, connect()}
  end

  def handle_info({:EXIT, _, {%RuntimeError{message: "Brokers sockets are not opened"}, _}}, _) do
    :timer.apply_after(5000, GenServer, :cast, [__MODULE__, {:retry_connection}])
    {:noreply, {nil}}
  end

  def handle_info({:EXIT, _, {%RuntimeError{message: "Brokers sockets are closed"}, _}}, _) do
    :timer.apply_after(5000, GenServer, :cast, [__MODULE__, {:retry_connection}])
    {:noreply, {nil}}
  end

  def kafka_port do
    case Integer.parse(System.get_env("KAFKA_PORT")) do
      {portnum, _} -> portnum
      :error -> 9092
    end
  end

  defp connect() do
    host = System.get_env("KAFKA_HOST") || "localhost"
    port = kafka_port()

    IO.puts("The host is #{host}")

    {:ok,
     [
       consumer_group: consumer_group
     ]} = Application.fetch_env(:messaging_spike, __MODULE__)

    result =
      KafkaEx.start_link_worker(:no_name, uris: [{host, port}], consumer_group: consumer_group)

    with {:ok, conn} <- result do
      KafkaEx.create_topics(
        [
          %{
            config_entries: [],
            num_partitions: 1,
            replica_assignment: [],
            replication_factor: 1,
            topic: "heartbeat"
          }
        ],
        worker_name: conn
      )

      {conn}
    else
      e ->
        Logger.error("Error connecting to kafka #{inspect(e)}")
        {nil}
    end
  end
end
