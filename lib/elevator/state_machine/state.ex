defmodule Elevator.StateMachine.State do
  defstruct [:floor, :direction, :behaviour, :orders, :lights]
end
