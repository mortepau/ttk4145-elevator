defmodule Elevator.StateMachine.Timer do
  @moduledoc """
  Timer to control door functionality.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    Logger.debug("Starting GenServer")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.debug("Initializing GenServer")
    {:ok, :none}
  end

  def start(sender, duration) do
    GenServer.cast(__MODULE__, {:start, {sender, duration}})
  end

  def stop() do
    GenServer.cast(__MODULE__, :stop)
  end

  def handle_cast({:start, {sender, duration}}, reference) do
    if reference != :none do
      Logger.debug("Cancelling previous Timer")
      Process.cancel_timer(reference)
    end

    Logger.debug("Starting Timer")
    new_reference = Process.send_after(self(), {:timeout, sender}, duration)

    {:noreply, new_reference}
  end

  def handle_cast(:stop, reference) when reference == :none do
    Logger.debug("Invalid Timer")
    {:noreply, reference}
  end

  def handle_cast(:stop, reference) do
    Logger.debug("Stopping Timer")
    Process.cancel_timer(reference)
    {:noreply, :none}
  end

  def handle_info({:timeout, from}, reference) do
    Logger.debug("Timer timed out")
    Process.send(from, :timeout, [:noconnect])
    {:noreply, reference}
  end
end
