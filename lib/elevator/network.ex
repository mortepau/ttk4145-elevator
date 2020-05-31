defmodule Elevator.Network do
  @moduledoc """
  Network context. The connection to the outer world.
  """
  use GenServer

  alias Elevator.{Network.State, Network.Packet, OrderController, OrderController.Order}

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
      timeouts: %{order: 15_000, packet: 250}
    }

    IO.puts("Network: Initialization finished.")

    {:ok, state}
  end

  @doc """
  A node connected, received from NodeDiscover. Send to GenServer as a call.
  Returns true if it was a new node, false otherwise. 
  """
  def node_connect(node) do
    GenServer.call(@name, {:node_connect, node})
  end

  @doc """
  A node disconnected, received from NodeDiscover. Send to GenServer as a cast.
  """
  def node_disconnect(node) do
    GenServer.cast(@name, {:node_disconnect, node})
  end

  @doc """
  A new order is received from OrderController. Send to GenServer as a cast.
  """
  def new_order(%Order{} = order) do
    GenServer.cast(@name, {:new_order, order})
  end

  @impl true
  def handle_call({:node_connect, node}, _from, %State{connection_pool: connection_pool} = state) do
    {is_new, connection_pool} = connection_pool_push(connection_pool, node)
    {:reply, is_new, %State{state | connection_pool: connection_pool}}
  end

  @impl true
  def handle_cast({:node_disconnect, node}, %State{connection_pool: connection_pool} = state) do
    connection_pool = connection_pool_pop(connection_pool, node)
    {:noreply, %State{state | connection_pool: connection_pool}}
  end

  @impl true
  @doc """
  Distribute the new order to all connected nodes.
  Create a timer 
  """
  def handle_cast({:new_order, %Order{} = order}, %State{pending: pending} = state) do
    new_pending =
      for node <- all_nodes() do
        packet =
          Packet.new() |> Packet.update([:source, :target, :payload], [Node.self(), node, order])

        IO.puts("Network: Sending order (#{packet.id}) to #{node}.")
        Process.send({@name, node}, {:new_order, packet}, [:noconnect])
        Process.send_after(@name, {:timeout, packet}, state.timeouts.packet)
        packet
      end

    pending = pending ++ new_pending
    {:noreply, %State{state | pending: pending}}
  end

  @impl true
  @doc """
  Handle the new order by sending it to the OrderController and sending
  an acknowledgement to the sender.
  """
  def handle_info({:new_order, %Packet{} = packet}, %State{pending: pending} = state) do
    IO.puts("New order received")
    OrderController.new_order(packet.payload)
    acknowledge_packet(packet)
    {:noreply, %State{state | pending: pending}}
  end

  @doc """
  Handle an acknowledgement received from the network.
  """
  def handle_info({:acknowledge, id}, %State{pending: pending} = state) do
    IO.puts("Network: Packet #{id} acknowledged.")
    pending = Enum.reject(pending, fn packet -> packet.id == id end)
    {:noreply, %State{state | pending: pending}}
  end

  @doc """
  Handle a packet timeut. Resend the packet to the target.
  """
  @impl true
  def handle_info({:timeout, %Packet{} = packet}, %State{pending: pending} = state) do
    if Enum.any?(pending, fn p -> p.id == packet.id end) do
      Process.send({@name, packet.target}, {:new_order, packet}, [:noconnect])
    end

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

  defp connection_pool_push(connection_pool, node) do
    case Enum.all?(connection_pool, fn x -> x != node end) do
      true ->
        IO.puts("Network: Connecting to new node #{node}.")
        connection_pool = Enum.concat(connection_pool, [node])
        {true, connection_pool}

      false ->
        {false, connection_pool}
    end
  end

  defp connection_pool_pop(connection_pool, node) do
    case Enum.any?(connection_pool, fn conn -> conn == node end) do
      true ->
        IO.puts("Network: Disconnecting from node #{node}.")
        Node.disconnect(node)
        Enum.reject(connection_pool, fn conn -> conn == node end)

      false ->
        connection_pool
    end
  end

  defp acknowledge_packet(%Packet{id: id, source: source}) do
    IO.puts("Network: Acknowledge order with id #{id}.")
    Process.send({@name, source}, {:acknowledge, id}, [:noconnect])
  end

  # Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  defp all_nodes() do
    case [Node.self() | Node.list()] do
      [:nonode@nohost] -> {:error, :node_not_running}
      nodes -> nodes
    end
  end
end
