defmodule Elevator.Watchdog.Node do
  @moduledoc """
  Module polling information from a single floor and button combination.
  """

  use GenServer

  alias Elevator.Watchdog.State
  alias Elevator.OrderController.Order

  def start_link(%{"floor" => floor, "button" => button} = opts) do
    GenServer.start_link(__MODULE__, opts, name: create_name(floor, button))
  end

  def init(%{"floor" => floor, "button" => button, "timeout" => timeout}) do
    spawn(fn ->
      Process.sleep(timeout)
      poll(floor, button)
    end)
    {:ok, %State{floor: floor, button: button, timeout: timeout}}
  end

  def poll(floor, button) do
    GenServer.cast(create_name(floor, button), :poll)
  end

  @doc """
  Read the state of the order button for the given {`floor`, `button`}
  combination and issue a new order if button is pressed.
  """
  def handle_cast(:poll, %State{} = state) do
    button_state = Elevator.Driver.get_order_button_state(state.floor, state.button)
    if button_state == 1 do
      order = Order.new() |> Order.update([:floor, :direction], [state.floor, state.button])
      Elevator.OrderController.new_order(order)
    end

    spawn(fn ->
      Process.sleep(state.timeout)
      poll(state.floor, state.button)
    end)

    {:noreply, state}
  end

  defp create_name(floor, button) do
    String.to_atom(Atom.to_string(__MODULE__) <> "." <> Integer.to_string(floor) <> "." <> Atom.to_string(button))
  end
end
