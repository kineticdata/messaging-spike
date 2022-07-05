defmodule MessagingSpike.Listeners do
  alias MessagingSpike.Brokers.Rabbit

  def init do
    Rabbit.subscribe("faq", fn message, meta ->
      IO.inspect(:erlang.binary_to_term(message), label: "message")
      IO.inspect(meta, label: "meta")
    end)
  end
end
