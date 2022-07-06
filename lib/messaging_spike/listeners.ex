defmodule MessagingSpike.Listeners do
  alias MessagingSpike.Brokers.Rabbit

  def init do
    Rabbit.declare("faq")

    Rabbit.subscribe("faq", fn _message, meta ->
      answer = :rand.uniform(100)
      reply_to = Map.get(meta, :reply_to)
      delivery_tag = Map.get(meta, :delivery_tag)

      Rabbit.publish(reply_to, answer)
      Rabbit.ack(delivery_tag)
    end)
  end
end
