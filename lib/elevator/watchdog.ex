defmodule Elevator.Watchdog do
  @moduledoc """
  Module reading the current elevator status.
  """

  use Supervisor

  def start_link(opts \\ {}) do
    IO.puts("#{__MODULE__}: Starting link")
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init([%{"floors" => floors, "buttons" => buttons}]) do
    IO.puts("#{__MODULE__}: Initializing Supervisor")
    children = 
      for f <- floors do
        for b <- buttons do
          name = String.to_atom(Integer.to_string(f) <> "_" <> Atom.to_string(b))
          map = %{"floor" => f, "button" => b, "timeout" => 100}
          Supervisor.child_spec({Elevator.Watchdog.Node, map}, id: name)
        end
      end
      |> List.flatten()

    opts = [strategy: :one_for_one, name: Elevator.Watchdog.Supervisor]
    Supervisor.init(children, opts)
  end

  def init(_args) do
    raise ArgumentError
  end
end
