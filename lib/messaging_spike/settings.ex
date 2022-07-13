defmodule MessagingSpike.Settings do
  use GenServer

  @default_message_rates [
    0,
    0,
    0,
    0,
    0,
    0,
    10,
    50,
    100,
    200,
    500,
    1000,
    1000,
    500,
    200,
    100,
    50,
    10,
    0,
    0,
    0,
    0,
    0,
    0
  ]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    {:ok, %{message_rates: @default_message_rates}}
  end

  def update(settings) do
    GenServer.call(__MODULE__, {:update, settings})
  end

  def get() do
    {:ok, GenServer.call(__MODULE__, {:get})}
  end

  def handle_call(command, _from, state) do
    case command do
      {:update, settings} ->
        {:reply, nil, Map.merge(state, settings)}

      {:get} ->
        {:reply, state, state}
    end
  end
end
