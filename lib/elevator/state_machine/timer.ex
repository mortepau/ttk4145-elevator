defmodule Elevator.StateMachine.Timer do
  @moduledoc """
  Timer to control door functionality.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, :none}
  end

  def start(sender, duration) do
    GenServer.cast(__MODULE__, {:start, {sender, duration}})
  end

  def stop() do
    GenServer.cast(__MODULE__, :stop)
  end

  def handle_cast({:start, {sender, duration}}, reference) do
    Logger.debug("Starting timer")
    if reference != :none do
      Logger.debug("Cancelling previous timer")
      Process.cancel_timer(reference)
    end
    new_reference = Process.send_after(self(), {:timeout, sender}, duration)

    {:noreply, new_reference}
  end

  def handle_cast(:stop, reference) when reference == :none do
    Logger.debug("No timer to stop")
    {:noreply, reference}
  end

  def handle_cast(:stop, reference) do
    Logger.debug("Stopping timer")
    Process.cancel_timer(reference)
    {:noreply, :none}
  end

  def handle_info({:timeout, from}, reference) do
    Logger.debug("Timeout")
    Logger.debug("Passing timeout to #{inspect from}")
    Process.send(from, :timeout, [:noconnect])
    {:noreply, reference}
  end
end
