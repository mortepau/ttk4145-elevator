defmodule Elevator.OrderController.Order do
  defstruct [:floor, :direction, :owner]

  @directions [:hall_up, :hall_down, :cab]
  @floors 0..4

  alias Elevator.OrderController.Order

  def new() do
    %Order{}
  end

  def update(%Order{} = order, keys, values) when is_list(keys) and is_list(values) do
    Enum.zip(keys, values) |> Map.new() |> (fn x -> Map.merge(order, x) end).()
  end

  def valid?(order = %Order{}) do
    Enum.all?(Map.values(order), fn v -> v != nil end) and valid_direction?(order) and
      valid_floor?(order)
  end

  defp valid_direction?(order = %Order{}) do
    Enum.any?(@directions, fn dir -> dir == order.direction end)
  end

  defp valid_floor?(order = %Order{}) do
    Enum.any?(@floors, fn floor -> floor == order.floor end)
  end
end
