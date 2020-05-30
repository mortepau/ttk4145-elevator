defmodule Elevator.OrderController.Order do
  defstruct [:id, :floor, :direction, :owner]

  @directions [:hall_up, :hall_down, :cab]
  @floors 0..4

  alias Elevator.OrderController.Order

  def new() do
    %Order{id: make_ref()}
  end

  def assign_id(order = %Order{}) do
    %Order{order | id: make_ref()}
  end

  def valid?(order = %Order{}) do
    Enum.all?(Map.values(order), fn v -> v != nil end) and check_direction(order) and check_floor(order)
  end

  defp check_direction(order = %Order{}) do
    Enum.any?(@directions, fn dir -> dir == order.direction end)
  end

  defp check_floor(order = %Order{}) do
    Enum.any?(@floors, fn floor -> floor == order.floor end)
  end
end
