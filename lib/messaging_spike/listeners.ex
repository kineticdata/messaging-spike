defmodule MessagingSpike.Listeners do
  alias MessagingSpike.Brokers.Rabbit

  def init do
    Rabbit.declare("size")

    Rabbit.subscribe("size", fn message, meta ->
      correlation_id = Map.get(meta, :correlation_id)
      reply_to = Map.get(meta, :reply_to)
      result = to_string(String.length(message))
      Rabbit.publish(reply_to, result, correlation_id)
    end)
  end
end
