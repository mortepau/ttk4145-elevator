defmodule Elevator.Network do
  @moduledoc """
  Network context. The connection to the outer world.
  """
  use GenServer

  alias Elevator.{Network.State, OrderController, OrderController.Order}

  @name Network

  def start_link(_) do
    IO.puts("Network: Starting GenServer.")
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  @impl true
  def init(_) do
    IO.puts("Network: Initializing GenServer.")

    state = %State{
      connection_pool: [],
      pending: [],
      timeouts: %{order: 15_000, packet: 250, connection: 1_000}
    }

    IO.puts("Network: Initialization finished.")

    {:ok, state}
  end

  def new_node(node) do
    GenServer.cast(@name, {:new_node, node})
  end

  @impl true
  def handle_cast({:new_node, node}, %State{connection_pool: connection_pool} = state) do
    connection_pool = connection_pool_push(connection_pool, node)
    {:noreply, %State{state | connection_pool: connection_pool}}
  end

  @doc """
  Handle a timeout message. Remove the timed out connection.
  """
  def handle_info({:timeout, node}, %State{connection_pool: connection_pool} = state) do
    connection_pool = connection_pool_pop(connection_pool, node)
    {:noreply, %State{state | connection_pool: connection_pool}}
  end

  @doc """
  Handle a new order from another elevator. Distribute it to `OrderController`.
  """
  def handle_info({:new_order, order}, %State{pending: pending} = state) do
    OrderController.new_order(order)
    pending = acknowledge_order(:new, pending, order)
    {:noreply, %State{state | pending: pending}}
  end

  @doc """
  Handle an order update from another elevator. Distribute it to `OrderController`.
  """
  def handle_info({:update_order, order}, %State{} = state) do
    OrderController.update_order(order)
    {:noreply, state}
  end

  @doc """
  Handle an order completion from another elevator. Distribute it to `OrderController`.
  """
  def handle_info({:complete_order, order}, %State{} = state) do
    OrderController.complete_order(order)
    {:noreply, state}
  end

  @impl true
  @doc """
  Return the GenServer state, used for debugging purposes
  """
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:pending, _from, state) do
    {:reply, state.pending, state}
  end

  defp connection_pool_push(connection_pool, node) do
    IO.puts("Network: Connecting to new node #{node}.")
    Node.connect(node)
    Enum.concat(connection_pool, [node]) |> Enum.uniq()
  end

  defp connection_pool_pop(connection_pool, node) do
    IO.puts("Network: Disconnecting from node #{node}.")
    Node.disconnect(node)
    Enum.reject(connection_pool, fn conn -> conn == node end)
  end

  defp acknowledge_order(:new, %State{pending: pending} = state, %Order{} = new_order) do
    pending =
      case Enum.any?(pending, fn order -> order.id == new_order.id end) do
        true ->
          pending

        false ->
          pending ++ [new_order]
      end

    %State{state | pending: pending}
  end

  # Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  defp all_nodes() do
    case [Node.self() | Node.list()] do
      [:nonode@nohost] -> {:error, :node_not_running}
      nodes -> {:ok, nodes}
    end
  end
end
