defmodule Elevator.StateMachine.State do
  defstruct [:floor, :direction, :behaviour, :orders, :timeout_door]
end
