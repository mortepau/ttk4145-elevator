defmodule Elevator.OrderController do
  @moduledoc """
  Module controlling the order assignment and calculation.
  """
  use GenServer

  require Logger

  alias Elevator.OrderController.Order
  alias Elevator.Driver

  def start_link(opts \\ {}) do
    Logger.info("Starting GenServer")
    GenServer.start_link(__MODULE__, opts, name: OrderController)
  end

  def init(_opts) do
    Logger.info("Initializing GenServer")
    state = {}
    {:ok, state}
  end

  def new_order(%Order{} = order) do
    GenServer.cast(OrderController, {:new_order, order})
  end

  def update_order(%Order{} = order) do
    GenServer.cast(OrderController, {:update_order, order})
  end

  def complete_order(%Order{} = order) do
    GenServer.cast(OrderController, {:complete_order, order})
  end

  def handle_cast({:new_order, %Order{} = order}, state) do
    Logger.debug("New Order")
    Elevator.StateMachine.new_order(order)
    Driver.set_order_button_light(order.button, order.floor, :on)
    {:noreply, state}
  end

  def handle_cast({:update_order, %Order{} = order}, state) do
    Logger.debug("Update Order")
    {:noreply, state}
  end

  def handle_cast({:complete_order, %Order{} = order}, state) do
    Logger.debug("Complete Order")
    Driver.set_order_button_light(order.button, order.floor, :off)
    {:noreply, state}
  end
end
