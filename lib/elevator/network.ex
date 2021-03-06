defmodule Elevator.Network do
  @moduledoc """
  Network context. The connection to the outer world.
  """
  use GenServer

  require Logger

  alias Elevator.{Network.State, Network.Packet, OrderController, OrderController.Order}

  @doc """
  Function to be used by the Supervisor to start a linked connection.
  """
  def start_link(_) do
    Logger.info("Starting GenServer")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  @doc """
  Initialize the GenServer by setting its state to the `Elevator.Network.State` struct.
  """
  def init(_) do
    Logger.info("Initializing GenServer")

    state = %State{
      connection_pool: [],
      pending: [],
      timeouts: %{order: 15_000, packet: 250}
    }

    Logger.info("Initialization finished")

    {:ok, state}
  end

  @doc """
  A new order is received from OrderController. Send to GenServer as a cast.
  """
  def new_order(%Order{} = order) do
    GenServer.cast(__MODULE__, {:new_order, order})
  end

  @doc """
  An order is completed. Send to GenServer as a cast.
  """
  def complete_order(%Order{} = order) do
    GenServer.cast(__MODULE__, {:complete_order, order})
  end

  @impl true
  @doc """
  Distribute the new order to all connected nodes.
  Create a timer for each packet sent.
  """
  def handle_cast({:new_order, %Order{} = order}, %State{pending: pending} = state) do
    new_pending =
      for node <- all_nodes() do
        packet =
          Packet.new() |> Packet.update([:source, :target, :payload], [Node.self(), node, order])

        Logger.debug("Sending order (#{packet.id}) to #{node}")
        Process.send({__MODULE__, node}, {:new_order, packet}, [:noconnect])
        Process.send_after(__MODULE__, {:timeout, packet}, state.timeouts.packet)
        packet
      end

    pending = pending ++ new_pending
    {:noreply, %State{state | pending: pending}}
  end

  @impl true
  @doc """
  Handle the new order by sending it to the OrderController and sending an acknowledgement to the sender.
  """
  def handle_info({:new_order, %Packet{} = packet}, %State{pending: pending} = state) do
    Logger.debug("New order received")
    OrderController.new_order(packet.payload)
    acknowledge_packet(packet)
    {:noreply, %State{state | pending: pending}}
  end

  @doc """
  Handle an acknowledgement received from the network.
  """
  def handle_info({:acknowledge, id}, %State{pending: pending} = state) do
    Logger.debug("Packet #{id} acknowledged")
    pending = Enum.reject(pending, fn packet -> packet.id == id end)
    {:noreply, %State{state | pending: pending}}
  end

  @doc """
  Handle a packet timeut. Resend the packet to the target.
  """
  @impl true
  def handle_info({:timeout, %Packet{} = packet}, %State{pending: pending} = state) do
    if Enum.any?(pending, fn p -> p.id == packet.id end) do
      Process.send({__MODULE__, packet.target}, {:new_order, packet}, [:noconnect])
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

  # Acknowledge a packet with a given `id`.
  defp acknowledge_packet(%Packet{id: id, source: source}) do
    Logger.debug("Acknowledge order with id #{id}")
    Process.send({__MODULE__, source}, {:acknowledge, id}, [:noconnect])
  end

  # Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  # Retrieve all nodes currently connected.
  defp all_nodes() do
    case [Node.self() | Node.list()] do
      [:nonode@nohost] -> {:error, :node_not_running}
      nodes -> nodes
    end
  end
end
