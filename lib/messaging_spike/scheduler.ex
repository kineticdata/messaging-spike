defmodule MessagingSpike.Scheduler do
  use GenServer
  require Logger

  @seconds_in_day 24 * 60 * 60
  @seconds_in_hour 60 * 60

  def go do
    GenServer.cast(__MODULE__, :go)
  end

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    {:ok, %{}}
  end

  def handle_cast(:go, state) do
    {:ok, settings} = MessagingSpike.Settings.get()

    unix_time = DateTime.utc_now() |> DateTime.to_unix()
    current_second = rem(unix_time, @seconds_in_day)
    current_hour = div(current_second, @seconds_in_hour)
    initial_rate = Enum.at(Map.get(settings, :message_rates), current_hour)
    initial_duration = (@seconds_in_hour - rem(current_second, @seconds_in_hour)) * 1000

    Logger.debug(
      "Scheduler starting at hour #{current_hour} with remaing duration #{initial_duration}ms"
    )

    workers = create_workers(initial_rate)

    Process.send_after(self(), :step, initial_duration)

    {:noreply, Map.merge(state, %{current_hour: current_hour, workers: workers})}
  end

  def handle_info(:step, %{current_hour: current_hour, workers: workers}) do
    {:ok, settings} = MessagingSpike.Settings.get()

    next_hour = rem(current_hour + 1, 24)
    rate = Enum.at(Map.get(settings, :message_rates), next_hour)

    Logger.debug("Scheduler resuming at hour #{next_hour} ... Killing old workers")

    Enum.each(workers, &MessagingSpike.MessageWorker.kill/1)

    new_workers = create_workers(rate)

    Process.send_after(self(), :step, 60 * 60 * 1000)

    {:noreply, %{current_hour: next_hour, workers: new_workers}}
  end

  defp create_workers(0) do
    Logger.debug("Starting no workers at this time")
    []
  end

  defp create_workers(rate) do
    Logger.debug("Starting workers with rate of #{rate} messages/minute")

    Enum.map([:nats, :rabbit], fn broker_type ->
      {:ok, pid} = MessagingSpike.MessageWorker.start({broker_type, "heartbeat", rate})
      pid
    end)
  end
end
