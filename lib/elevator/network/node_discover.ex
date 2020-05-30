defmodule Elevator.Network.NodeDiscover do
  @moduledoc """
  Context for creating and handling a UDP broadcast connection.
  Uses GenServer and can be put in a Supervision tree.
  """
  use GenServer

  @name NodeDiscover
  @broadcast_ip {255, 255, 255, 255}
  @broadcast_interval 1_000

  @doc """
  Start the GenServer controlling the NodeDiscover submodule.
  Input is the port for the UDP server.
  """
  def start_link(port \\ 8080) do
    IO.puts("NodeDiscover: Starting GenServer.")
    GenServer.start_link(__MODULE__, port, name: @name)
  end

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
    Process.send_after(@name, {:broadcast, @broadcast_interval}, @broadcast_interval)
    IO.puts("NodeDiscover: Initializion finished.")

    {:ok, {socket, port}}
  end

  @doc """
  Handle a UDP packet. Checks if the packet is a valid node name and
  sends it to `Elevator.Network`.
  """
  def handle_info({:udp, _socket, _address, _port, packet}, state) do
    IO.puts(
      "NodeDiscover(#{Node.self() |> to_string() |> String.slice(0, 10)}...): Packet received."
    )

    packet = :erlang.binary_to_term(packet)

    cond do
      node?(to_string(packet)) and Node.self() != packet ->
        Elevator.Network.new_node(packet)
        :ok

      true ->
        :ok
    end

    {:noreply, state}
  end

  @doc """
  Broadcast the node name on the UDP port, and create a delayed call for
  a new broadcast.
  """
  def handle_info({:broadcast, next_broadcast}, {socket, port}) do
    IO.puts(
      "NodeDiscover(#{Node.self() |> to_string() |> String.slice(0, 10)}...): Broadcasting node."
    )

    :gen_udp.send(socket, @broadcast_ip, port, :erlang.term_to_binary(Node.self()))

    Process.send_after(@name, {:broadcast, next_broadcast}, next_broadcast)

    {:noreply, {socket, port}}
  end

  # Check if `string` matches the node name format.
  defp node?(string) do
    # Matches a node name consisting of 32 alphanumeric characters, a @ and 4 digits separated by .
    pattern = ~r/^\b\w{32}\b@\d+\.\d+\.\d+\.\d+$/
    Regex.match?(pattern, string)
  end

  # Convert the node name to an ip address on the format {#1, #2, #3, #4}.
  # Assumes the node has a valid format.
  def node_to_ip() do
    Node.self()
    |> to_string()
    |> String.split("@")
    |> Enum.at(1)
    |> String.split(".")
    |> Enum.map(fn x -> String.to_integer(x) end)
    |> Enum.reduce({}, fn x, acc -> Tuple.append(acc, x) end)
  end

  # Based on the works of Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  # Create a distributed node with a unique name. Set the cookie so nodes are visible to each other.
  def start_node() do
    case get_ip() do
      {:ok, ip} ->
        short_name = UUID.uuid4(:hex)
        ip = ip_to_string(ip)
        name = (short_name <> "@" <> ip) |> String.to_atom()
        Node.start(name, :longnames, 15_000)
        Node.set_cookie(:elevator_cookie)
        {:ok, name}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  # Retrieve all nodes currently connected.
  defp all_nodes() do
    case [Node.self() | Node.list()] do
      [:nonode@nohost] -> {:error, :node_not_running}
      nodes -> {:ok, nodes}
    end
  end

  # Based on the works of Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  # Get the IP address.
  defp get_ip() do
    ports = Enum.to_list(8091..8100)
    opts = [active: false, broadcast: true]
    packet = 'find ip'
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

  # Credited: Jostein Løwer. https://github.com/jostlowe/kokeplata/tree/master/lib (27.05.20)
  # Convert the IP address to a string.
  defp ip_to_string(ip) do
    :inet.ntoa(ip) |> to_string()
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
