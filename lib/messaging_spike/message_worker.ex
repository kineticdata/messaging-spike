defmodule MessagingSpike.MessageWorker do
  use GenServer

  alias MessagingSpike.Brokers.Kafka
  alias MessagingSpike.Brokers.Nats
  alias MessagingSpike.Brokers.Rabbit
  alias MessagingSpike.Brokers.Redis

  def kill(pid) do
    GenServer.cast(pid, :kill)
  end

  def start(init_arg) do
    GenServer.start(__MODULE__, init_arg)
  end

  def init({broker_type, topic, rate}) do
    module =
      case broker_type do
        :kafka -> Kafka
        :nats -> Nats
        :rabbit -> Rabbit
        :redis -> Redis
      end

    interval = ceil(1 / (rate / (60 * 1000)))

    message = "Heartbeat from pid:#{inspect(self())}"

    {:ok, ref} = :timer.apply_interval(interval, module, :publish, [topic, message])

    {:ok, %{ref: ref}}
  end

  def handle_cast(:kill, %{ref: ref}) do
    :timer.cancel(ref)

    {:stop, "Worker was killed", nil}
  end
end
