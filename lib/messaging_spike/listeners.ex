defmodule MessagingSpike.Listeners do
  alias MessagingSpike.Brokers.Rabbit
  alias MessagingSpike.Settings

  def init do
    Rabbit.declare("size", false)

    Rabbit.subscribe("size", fn message, meta ->
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
    IO.puts("Server #{queue_name} is bound to the broadcast exchange")

    Rabbit.subscribe(queue_name, fn message, _meta ->
      Settings.update(:erlang.binary_to_term(message))
    end)
  end
end
