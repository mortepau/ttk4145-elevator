defmodule Elevator.OrderController.Order do
  defstruct [:floor, :button, :owner]

  @buttons [:hall_up, :hall_down, :cab]
  @floors 0..4

  alias Elevator.OrderController.Order

  def new() do
    %Order{}
  end

  def update(%Order{} = order, keys, values) when is_list(keys) and is_list(values) do
    Enum.zip(keys, values) |> Map.new() |> (fn x -> Map.merge(order, x) end).()
  end

  def valid?(order = %Order{}) do
    Enum.all?(Map.values(order), fn v -> v != nil end) and valid_button?(order) and
      valid_floor?(order)
  end

  defp valid_button?(%Order{button: button}) do
    button in @buttons
  end

  defp valid_floor?(%Order{floor: floor}) do
    floor in @floors
  end
end
