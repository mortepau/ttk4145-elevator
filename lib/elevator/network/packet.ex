defmodule Elevator.Network.Packet do
  @moduledoc """
  A struct for a network packet.

  `id`: Unique ID defining the packet

  `status`: An atom defining type of packet, one of `[:heartbeat, :timeout, :new_order, :update_order, :complete_order]`

  `source`: Sender of the packet

  `target`: Receiver of the packet

  `payload`: Packet content
  """

  defstruct [:id, :status, :source, :target, :payload]

  alias Elevator.Network.Packet

  @doc """
  Creates a new `%Elevator.Network.Packet{}`, setting its `id`.
  """
  def new() do
    %Packet{id: UUID.uuid4(:hex)}
  end

  @doc """
  Assign a unique ID to `packet`.
  """
  def assign_id(%Packet{} = packet) do
    case packet.id do
      nil -> %Packet{packet | id: UUID.uuid4(:hex)}
      _ -> packet
    end
  end

  @doc """
  Checks if the packet is valid.
  """
  def valid?(%Packet{} = packet) do
    Enum.all?(Map.values(packet), fn v -> v != nil end)
  end
end
