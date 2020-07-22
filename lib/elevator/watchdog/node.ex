defmodule Elevator.Watchdog.Node do
  @moduledoc """
  Module polling information from a single floor and button combination.
  """

  use GenServer

  alias Elevator.OrderController.Order

  def start_link(%{"floor" => floor, "button" => button} = opts) do
    GenServer.start_link(__MODULE__, opts, name: create_name(floor, button))
  end

  def init(%{"floor" => floor, "button" => button, "timeout" => timeout}) do
    spawn(fn ->
      Process.sleep(timeout)
      poll(floor, button)
    end)
    {:ok, %{floor: floor, button: button, timeout: timeout}}
  end

  def poll(floor, button) do
    GenServer.cast(create_name(floor, button), :poll)
  end

  def handle_cast(:poll, %{floor: floor, button: button, timeout: timeout} = state) do
    button_state = Elevator.Driver.get_order_button_state(floor, button)
    if button_state do
      order = Order.new() |> Order.update([:floor, :button], [floor, button])
      Elevator.OrderController.new_order(order)
    end

    spawn(fn ->
      Process.sleep(timeout)
      poll(floor, button)
    end)

    {:noreply, state}
  end

  defp create_name(floor, button) do
    String.to_atom(Atom.to_string(__MODULE__) <> "." <> Integer.to_string(floor) <> "." <> Atom.to_string(button))
  end
end
