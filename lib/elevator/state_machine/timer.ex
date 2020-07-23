defmodule Elevator.StateMachine.Timer do
  @moduledoc """
  Timer to control door functionality.
  """

  use GenServer

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
    IO.puts("#{__MODULE__}: Starting Timer")
    if reference != :none do
    IO.puts("#{__MODULE__}: Cancelling previous Timer")
      Process.cancel_timer(reference)
    end
    new_reference = Process.send_after(self(), {:timeout, sender}, duration)

    {:noreply, new_reference}
  end

  def handle_cast(:stop, reference) when reference == :none do
    IO.puts("#{__MODULE__}: Stopping Timer ( No reference )")
    {:noreply, reference}
  end

  def handle_cast(:stop, reference) do
    IO.puts("#{__MODULE__}: Stopping Timer")
    Process.cancel_timer(reference)
    {:noreply, :none}
  end

  def handle_info({:timeout, from}, reference) do
    IO.puts("#{__MODULE__}: Timeout")
    IO.inspect(from)
    IO.inspect(reference)
    IO.puts("#{__MODULE__}: Sending message")
    Process.send(from, :timeout, [:noconnect])
    {:noreply, reference}
  end
end
