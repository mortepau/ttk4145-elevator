defmodule Elevator.Application do
  @moduledoc false

  @ports 8080..8090
  @broadcast_port 16_600

  use Application

  def start(_type, _args) do
    children = [
      {Elevator.OrderController, []},
      {Elevator.Network.NodeDiscover, @broadcast_port},
      {Elevator.Network, Enum.to_list(@ports)}
    ]

    opts = [strategy: :one_for_one, name: Elevator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end