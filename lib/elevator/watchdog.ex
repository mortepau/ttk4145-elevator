defmodule Elevator.Watchdog do
  @moduledoc """
  Module reading the current elevator status.
  """

  use Supervisor

  def start_link(opts \\ {}) do
    IO.puts("#{__MODULE__}: Starting link")
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize the Supervision tree by creating a child for each combination of {`floor`, `button`}.
  """
  def init([%{"floors" => floors, "buttons" => buttons}]) do
    IO.puts("#{__MODULE__}: Initializing Supervisor")
    children = 
      for f <- floors do
        for b <- buttons do
          name = String.to_atom(Integer.to_string(f) <> "_" <> Atom.to_string(b))
          map = %{"floor" => f, "button" => b, "timeout" => 100}
          Supervisor.child_spec({Elevator.Watchdog.ButtonNode, map}, id: name)
        end
      end
      |> List.flatten()
      |> (fn list -> [{Elevator.Watchdog.FloorNode, 100} | list] end).()

    Supervisor.init(children, strategy: :one_for_one)
  end

  def init(_args) do
    raise ArgumentError
  end
end