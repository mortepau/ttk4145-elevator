defmodule Elevator.StateMachine do
  @moduledoc """
  Controlling the behaviour of the elevator. The behaviour depends on its
  state, current orders, and which direction it is travelling.
  """

  use GenServer

  alias Elevator.StateMachine.State
  alias Elevator.OrderController.Order
  alias Elevator.Driver

  def start_link(opts \\ {}) do
    GenServer.start_link(__MODULE__, opts, name: StateMachine)
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

  def moving() do
  end

  def idle() do
  end

  def door_open() do
  end

  def new_order() do
    
  end

  def complete_order() do
    
  end

  def set_light(%Order{} = order) do
      GenServer.cast(__MODULE__, {:set_light, order})
  end

  def clear_light(%Order{} = order) do
      GenServer.cast(__MODULE__, {:clear_light, order})
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
end
