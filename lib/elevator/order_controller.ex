defmodule Elevator.OrderController do
  @moduledoc """
  Module controlling the order assignment and calculation.
  """
  use GenServer

  alias Elevator.OrderController.Order

  def start_link(opts \\ {}) do
    GenServer.start_link(__MODULE__, opts, name: OrderController)
  end

  def init(_opts) do
    state = {}
    {:ok, state}
  end

  def new_order(%Order{} = order) do
    IO.puts("From OrderController.new_order: new order received")
    GenServer.cast(OrderController, {:new_order, order})
  end

  def update_order(%Order{} = order) do
    IO.puts("From OrderController.update_order: update order received")
    GenServer.cast(OrderController, {:update_order, order})
  end

  def complete_order(%Order{} = order) do
    IO.puts("From OrderController.complete_order: complete order received")
    GenServer.cast(OrderController, {:complete_order, order})
  end

  def handle_cast({:new_order, %Order{} = order}, state) do
    IO.inspect(order)
    {:noreply, state}
  end

  def handle_cast({:update_order, %Order{} = order}, state) do
    IO.inspect(order)
    {:noreply, state}
  end

  def handle_cast({:complete_order, %Order{} = order}, state) do
    IO.inspect(order)
    {:noreply, state}
  end
end
