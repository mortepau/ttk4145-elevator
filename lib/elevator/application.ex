defmodule Elevator.Application do
  @moduledoc false

  @ports 8080..8090
  @broadcast_port 16_600

  @floors 0..3
  @buttons [:hall_up, :hall_down, :cab]

  use Application

  def start(_type, _args) do
    children = [
      {Elevator.Driver, []},
      {Elevator.Watchdog, [%{"floors" => @floors, "buttons" => @buttons}]},
      {Elevator.StateMachine.Timer, []},
      {Elevator.StateMachine, []},
      {Elevator.OrderController, []},
      {Elevator.Network.NodeDiscover, @broadcast_port},
      {Elevator.Network, Enum.to_list(@ports)}
    ]

    opts = [strategy: :one_for_one, name: Elevator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
