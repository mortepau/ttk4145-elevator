defmodule Elevator.Network.NodeDiscover do
  @moduledoc """
  Context for creating and handling a UDP broadcast connection.
  Uses GenServer and can be put in a Supervision tree.
  """
  use GenServer

  @broadcast_ip {255, 255, 255, 255}
  @broadcast_interval 1_000

  @doc """
  Start the GenServer controlling the NodeDiscover submodule.
  Input is the port for the UDP server.
  """
  def start_link(port \\ 8080) do
    IO.puts("NodeDiscover: Starting GenServer.")
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  @impl true
  @doc """
  Initialize the GenServer by starting the UDP server using `port` and
  create a distributed node with a unique name.
  """
  def init(port) do
    IO.puts("NodeDiscover: Initializing GenServer.")
    opts = [:binary, active: true, broadcast: true, reuseaddr: true]
    IO.puts("NodeDiscover: Starting UDP broadcasting.")
    {:ok, socket} = :gen_udp.open(port, opts)
    IO.puts("NodeDiscover: UDP broadcasting started on port: #{port}.")

    IO.puts("NodeDiscover: Starting node.")
    start_node()
    IO.puts("NodeDiscover: Node started.")
    Process.send_after(__MODULE__, {:broadcast, @broadcast_interval}, @broadcast_interval)
    IO.puts("NodeDiscover: Initializion finished.")

    {:ok, %{socket: socket, port: port, connection_pool: [Node.self()]}}
  end

  @impl true
  @doc """
  Handle a UDP packet. If it contains a new node name establish a connection with it.
  """
  def handle_info({:udp, _, _, _, packet}, %{connection_pool: connection_pool} = state) do
    node = :erlang.binary_to_term(packet)

    connection_pool = connection_pool_push(connection_pool, node)

    {:noreply, %{state | connection_pool: connection_pool}}
  end

  @doc """
  Broadcast the node name on the UDP port, and create a delayed call for
  a new broadcast.
  """
  def handle_info({:broadcast, next_broadcast}, %{socket: socket, port: port} = state) do
    :gen_udp.send(socket, @broadcast_ip, port, :erlang.term_to_binary(Node.self()))

    Process.send_after(__MODULE__, {:broadcast, next_broadcast}, next_broadcast)

    {:noreply, state}
  end

  @impl true
  @doc """
  Handle a node disconnect by removing it from `connection_pool`.
  """
  def handle_info({:nodedown, node}, %{connection_pool: connection_pool} = state) do
    connection_pool = connection_pool_pop(connection_pool, node)
    {:noreply, %{state | connection_pool: connection_pool}}
  end

  # Add a node to `connection_pool` if isn't already present.
  defp connection_pool_push(connection_pool, node) do
    case node?(node) and Enum.all?(connection_pool, fn x -> x != node end) do
      true ->
        IO.puts("Network: Connecting to node #{node}.")
        Node.connect(node)
        Node.monitor(node, true)
        Enum.concat(connection_pool, [node])

      false ->
        connection_pool
    end
  end

  # Remove a node from `connection_pool` if it is present.
  defp connection_pool_pop(connection_pool, node) do
    case node?(node) and Enum.any?(connection_pool, fn conn -> conn == node end) do
      true ->
        IO.puts("Network: Disconnecting from node #{node}.")
        Node.monitor(node, false)
        Node.disconnect(node)
        Enum.reject(connection_pool, fn conn -> conn == node end)

      false ->
        connection_pool
    end
  end

  # Check if `atom` matches the node name format.
  defp node?(atom) do
    # Matches a node name consisting of 32 alphanumeric characters, a @ and 4 digits separated by .
    pattern = ~r/^\b\w{32}\b@\d+\.\d+\.\d+\.\d+$/
    Regex.match?(pattern, to_string(atom))
  end

  # Based on the works of Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  # Create a distributed node with a unique name. Set the cookie so nodes are visible to each other.
  defp start_node() do
    case get_ip() do
      {:ok, ip} ->
        short_name = UUID.uuid4(:hex)
        ip = :inet.ntoa(ip) |> to_string()
        name = (short_name <> "@" <> ip) |> String.to_atom()
        Node.start(name, :longnames, 15_000)
        Node.set_cookie(:elevator_cookie)
        {:ok, name}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Based on the works of Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  # Get the IP address.
  defp get_ip() do
    ports = Enum.to_list(8091..8100)
    opts = [active: false, broadcast: true]
    packet = []
    {port, socket} = open_udp(ports, opts)
    :ok = :gen_udp.send(socket, {255, 255, 255, 255}, port, packet)

    {status, ip} =
      case :gen_udp.recv(socket, 100, 1_000) do
        {:ok, {ip, ^port, ^packet}} -> {:ok, ip}
        {:error, _reason} -> {:error, :no_ip_found}
      end

    :gen_udp.close(socket)
    {status, ip}
  end

  # Raise an error if trying to open a UDP port with no port specified.
  defp open_udp([], _opts) do
    raise "NodeDiscover: Not able to open port"
  end

  # Tries to open a UDP port, if it fails try again using the
  # next port in the list.
  defp open_udp([port | rest], opts) do
    case :gen_udp.open(port, opts) do
      {:ok, socket} ->
        {port, socket}

      {:error, _reason} ->
        open_udp(rest, opts)
    end
  end
end
