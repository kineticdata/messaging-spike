defmodule MessagingSpike.Settings do
  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, init_arg}
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
        {:reply, nil, settings}

      {:get} ->
        {:reply, state, state}
    end
  end
end
