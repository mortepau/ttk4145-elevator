defmodule Elevator.StateMachine do
  @moduledoc """
  Controlling the behaviour of the elevator. The behaviour depends on its
  state, current orders, and which direction it is travelling.
  """

  use GenServer

  require Logger

  alias Elevator.StateMachine.{State, Timer}
  alias Elevator.OrderController.Order
  alias Elevator.Driver

  def start_link(opts \\ {}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %State{
      floor: -1,
      direction: :stop,
      behaviour: :idle,
      orders: [],
      lights: []
    }
    {:ok, state}
  end

  def new_order(%Order{} = order) do
    GenServer.cast(__MODULE__, {:new_order, order})
  end

  def complete_order(%Order{} = order) do
   GenServer.cast(__MODULE__, {:complete_order, order}) 
  end

  def arrive_at_floor(floor) do
    GenServer.cast(__MODULE__, {:arrive_at_floor, floor})
  end

  def set_light(%Order{} = order) do
    GenServer.cast(__MODULE__, {:set_light, order})
  end

  def clear_light(%Order{} = order) do
    GenServer.cast(__MODULE__, {:clear_light, order})
  end

  def handle_cast({:new_order, %Order{} = order}, %State{orders: orders} = state) do
    {:noreply, state}
  end

  def handle_cast({:arrive_at_floor, new_floor}, %State{} = state) do
    state = 
      cond do
        state.floor == -1 and state.direction == :stop ->
          direction = start_between_floors()
          %State{state | direction: direction}
        new_floor == -1 ->
          # Do nothing, between floors
          state
        new_floor != state.floor ->
          Logger.debug("Arrived at new floor #{new_floor}")
          floor = new_floor
          orders = update_orders(state.orders, floor)
          Driver.set_floor_indicator(floor)
          open_door(3000)
          %State{state | floor: floor, orders: orders}
        true ->
          state
      end

    {:noreply, state}
  end

  def handle_cast({:set_light, %Order{} = order}, %State{lights: lights} = state) do
    Driver.set_order_button_light(order.button, order.floor, 1)
    lights = put_in(lights, [order.floor, order.button], 1)

    {:noreply, %State{state | lights: lights}}
  end

  def handle_cast({:clear_light, %Order{} = order}, %State{lights: lights} = state) do
    Driver.set_order_button_light(order.button, order.floor, 0)
    lights = put_in(lights, [order.floor, order.button], 0)

    {:noreply, %State{state | lights: lights}}
  end

  def handle_info(:timeout, %State{} = state) do
    Logger.debug("Timer timeout")
    close_door() 
    {:noreply, state}
  end

  defp start_between_floors() do
    Logger.info("Starting between floors")
    :down
  end

  defp update_orders(orders, floor) do
    Logger.debug("Updating orders")
    Enum.filter(orders, fn order -> order.floor != floor end)
  end

  defp open_door(timeout) do
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Timer.start(self(), timeout)
  end

  defp close_door() do
    Driver.set_door_open_light(:off)
    Timer.stop()
  end
end
