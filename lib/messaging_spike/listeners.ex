defmodule MessagingSpike.Listeners do
  alias MessagingSpike.Brokers.Rabbit
  alias MessagingSpike.Settings
  alias MessagingSpike.Brokers.Nats
  alias MessagingSpike.Brokers.Redis

  def init do
    # ---------------------------------------------------------------
    # Rabbit
    # ---------------------------------------------------------------

    Rabbit.declare("size", false)

    Rabbit.declare("heartbeat", true)
    Rabbit.subscribe("heartbeat", fn _, _ -> nil end)

    Rabbit.subscribe("size", fn message, meta ->
      IO.puts("executing RPC via rabbit")
      correlation_id = Map.get(meta, :correlation_id)
      reply_to = Map.get(meta, :reply_to)
      result = to_string(String.length(message))
      Rabbit.publish(reply_to, result, correlation_id)
    end)

    # create exchange
    Rabbit.declare_exchange("broadcast")
    # create multiple queues and bind them
    {:ok, %{queue: queue_name}} = Rabbit.declare("", true)
    Rabbit.bind(queue_name, "broadcast")

    Rabbit.subscribe(queue_name, fn message, _meta ->
      Settings.update(:erlang.binary_to_term(message))
    end)

    # ---------------------------------------------------------------
    # Nats
    # ---------------------------------------------------------------

    Nats.subscribe(
      "check_token",
      fn message, reply_to ->
        IO.puts("executing RPC via nats")
        Nats.publish(reply_to, to_string(String.length(message) > 10))
      end,
      queue_group: "rpc"
    )

    Nats.subscribe("settings", fn message ->
      Settings.update(:erlang.binary_to_term(message))
    end)

    # ---------------------------------------------------------------
    # Kafka
    # ---------------------------------------------------------------

    spawn(fn ->
      KafkaEx.create_topics([
        %KafkaEx.Protocol.CreateTopics.TopicRequest{
          topic: "settings",
          num_partitions: 1,
          replication_factor: 1,
          replica_assignment: [],
          config_entries: []
        }
      ])

      [
        %KafkaEx.Protocol.Offset.Response{
          partition_offsets: [%{error_code: :no_error, offset: [latest_offset], partition: 0}]
        }
      ] = KafkaEx.latest_offset("settings", 0)

      KafkaEx.stream("settings", 0, offset: max(latest_offset - 1, 0))
      |> Stream.map(&Map.get(&1, :value))
      |> Stream.map(&:erlang.binary_to_term/1)
      |> Stream.each(&Settings.update(&1))
      |> Stream.run()
    end)

    # ---------------------------------------------------------------
    # Redis
    # ---------------------------------------------------------------

    Redis.subscribe("settings", fn message ->
      Settings.update(:erlang.binary_to_term(message))
    end)
  end
end
