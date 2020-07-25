defmodule Elevator.Watchdog.FloorNode do
  @moduledoc """
  Module polling information from a single floor and button combination.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(timeout) do
    spawn(fn ->
      Process.sleep(timeout)
      poll()
    end)

    {:ok, timeout}
  end

  def poll() do
    GenServer.cast(__MODULE__, :poll)
  end

  @doc """
  Read the state of the order button for the given {`floor`, `button`}
  combination and issue a new order if button is pressed.
  """
  def handle_cast(:poll, timeout) do
    floor_state = Elevator.Driver.get_floor_sensor_state()

    case floor_state do
      :between_floors ->
        Elevator.StateMachine.arrive_at_floor(-1)

      floor ->
        Elevator.StateMachine.arrive_at_floor(floor)
    end

    spawn(fn ->
      Process.sleep(timeout)
      poll()
    end)

    {:noreply, timeout}
  end
end
