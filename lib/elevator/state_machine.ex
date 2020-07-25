defmodule Elevator.StateMachine do
  @moduledoc """
  Controlling the behaviour of the elevator. The behaviour depends on its
  state, current orders, and which direction it is travelling.
  """

  use GenServer

  require Logger

  alias Elevator.StateMachine.{State, Timer}
  alias Elevator.OrderController
  alias Elevator.OrderController.Order
  alias Elevator.Driver

  # Initialization
  
  def start_link(opts \\ {}) do
    Logger.info("Starting GenServer")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Initializing GenServer")
    state = %State{
      floor: -1,
      direction: :stop,
      behaviour: :idle,
      orders: [],
      timeout_door: 3_000
    }

    {:ok, state}
  end

  # API

  def new_order(%Order{} = order) do
    GenServer.cast(__MODULE__, {:new_order, order})
  end

  def arrive_at_floor(floor) when is_integer(floor) do
    GenServer.cast(__MODULE__, {:arrive_at_floor, floor})
  end

  # Handle functions

  def handle_cast({:new_order, %Order{} = order}, %State{orders: orders} = state) do
    already_active = order_active?(orders, order)

    if already_active do
      Logger.debug("Order already active")
      {:noreply, state}
    else
      Logger.debug("New order")
      state =
        case state.behaviour do
          :idle ->
            if state.floor == order.floor do
              open_door(state.timeout_door)
              Map.put(state, :behaviour, :door_open)
            else
              state
              |> add_order(order)
              |> set_direction()
              |> Map.put(:behaviour, :moving)
            end

          :moving ->
            state
            |> add_order(order)

          :door_open ->
            if state.floor == order.floor do
              open_door(state.timeout_door)
              state
            else
              state
              |> add_order(order)
            end

          _ ->
            state
        end

      {:noreply, state}
    end
  end

  def handle_cast({:arrive_at_floor, new_floor}, %State{} = state) do
    state =
      cond do
        new_floor == -1 ->
          if state.floor == -1 and state.direction == :stop do
            Logger.debug("Starting between floors")
            start_between_floors(state)
          else
            state
          end

        new_floor != state.floor ->
          Logger.debug("New floor")
          state = Map.put(state, :floor, new_floor)
          Driver.set_floor_indicator(new_floor)

          case state.behaviour do
            :moving ->
              if stop?(state) do
                open_door(state.timeout_door)

                state
                |> remove_orders()
                |> Map.put(:behaviour, :door_open)
              else
                state
              end

            _ ->
              state
          end

        true ->
          state
      end

    {:noreply, state}
  end

  def handle_info(:timeout, %State{} = state) do
    Logger.debug("Closing door")
    close_door()

    state =
      state
      |> set_direction()
      |> (fn s ->
        if s.direction == :stop do
          Map.put(s, :behaviour, :idle)
        else
          Map.put(s, :behaviour, :moving)
        end
      end).()

    {:noreply, state}
  end

  # Helper functions

  defp start_between_floors(%State{} = state) do
    Driver.set_motor_direction(:down)
    state
    |> Map.put(:direction, :down)
    |> Map.put(:behaviour, :moving)
  end

  defp set_direction(%State{} = state) do
    any_above = orders_above?(state.orders, state.floor)
    any_below = orders_below?(state.orders, state.floor)

    direction =
      case state.direction do
        :up ->
          cond do
            any_above -> :up
            any_below -> :down
            true -> :stop
          end

        :down ->
          cond do
            any_below -> :down
            any_above -> :up
            true -> :stop
          end

        :stop ->
          cond do
            any_below -> :down
            any_above -> :up
            true -> :stop
          end

        _ ->
          :stop
      end

    Logger.debug("Setting direction to #{direction}")
    Driver.set_motor_direction(direction)
    %State{state | direction: direction}
  end

  defp stop?(%State{} = state) do
    case state.direction do
      :up ->
        order_active?(state.orders, state.floor, :hall_up) or
          order_active?(state.orders, state.floor, :cab) or
          not orders_above?(state.orders, state.floor)

      :down ->
        order_active?(state.orders, state.floor, :hall_down) or
          order_active?(state.orders, state.floor, :cab) or
          not orders_below?(state.orders, state.floor)

      :stop ->
        true
    end
  end

  defp orders_above?(orders, floor) do
    Enum.any?(orders, fn order -> order.floor > floor end)
  end

  defp orders_below?(orders, floor) do
    Enum.any?(orders, fn order -> order.floor < floor end)
  end

  defp order_active?(orders, %Order{floor: floor, button: button}) do
    order_active?(orders, floor, button)
  end

  defp order_active?(orders, floor, button) do
    Enum.any?(orders, fn order -> order.floor == floor and order.button == button end)
  end

  defp add_order(%State{orders: orders} = state, %Order{} = order) do
    new_orders = Enum.uniq(orders ++ [order])
    %State{state | orders: new_orders}
  end

  defp remove_order(%State{orders: orders} = state, %Order{} = order) do
    new_orders = Enum.reject(orders, fn ord -> ord == order end)
    %State{state | orders: new_orders}
  end

  defp remove_orders(%State{orders: orders, floor: floor} = state) do
    new_orders =
      Enum.reject(orders, fn order ->
        if order.floor == floor do
          OrderController.complete_order(order)
          true
        else
          false
        end
      end)

    %State{state | orders: new_orders}
  end

  defp open_door(timeout) do
    Logger.debug("Opening door")
    Driver.set_motor_direction(:stop)
    Driver.set_door_open_light(:on)
    Timer.start(self(), timeout)
  end

  defp close_door() do
    Logger.debug("Closing door")
    Driver.set_door_open_light(:off)
    Timer.stop()
  end
end
