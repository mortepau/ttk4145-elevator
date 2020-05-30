# Elevator

This repository contains the implementation of an elevator for the course `TTK4145 - Real-Time Programming` at NTNU.
The elevator uses a peer-to-peer based connection for communication between `Elevator` modules.

----
## Table of Contents

- [Elevator](#elevator)
    * [Table of Contents](#table-of-contents)
    * [Modules](#modules)
        * [Interconnect](#interconnect)
        - [StateMachine](#elevator.statemachine)
        - [Network](#elevator.network)
        - [OrderController](#elevator.ordercontroller)
            * [OrderMap](#elevator.ordercontroller.ordermap)
            * [Order](#elevator.ordercontroller.order)
        - [Watchdog](#elevator.watchdog)
        - [Driver](#elevator.driver)
    * [Installation](#installation)

----

## Modules

The `Elevator` module consists of five modules which are explained in this section.

### Interconnect

### `Elevator.StateMachine`

This is the state machine and controls which controls the behaviour of the elevator
given its current [`Elevator.OrderMap`](#elevator.ordermap).

### `Elevator.Network`

This module controls all the communication between different `Elevator` modules.

TODO: Add information about how it is done (TCP/UDP)

#### `Elevator.Network.Packet`

This is a struct containing a packet for transmission.

``` elixir
packet = {
    id: Packet.UUID,
    target: Network.UUID,
    source: Network.UUID,
    payload: Elevator.OrderController.Order
}
```

`target` - The recipient of the packet.

`source` - The sender of the packet.

`payload` - The `Elevator.OrderController.Order` to transmit.

### `Elevator.OrderController`

#### `Elevator.OrderController.OrderMap`

This is a struct containing all the 

#### `Elevator.OrderController.Order`

This is a struct containing a single order.

``` elixir
order = {
    id: UUID,
    assignee: UUID,
    floor: int,
    direction: enum,
    time: Date-object
}
```
`id` - a unique number identifying the order.

`assignee` - a unique number identifying the elevator executing the order.

`floor` - indicating target floor for order.

`direction` - indicating direction for order.

`direction` can be one of
``` elixir
{:cab, :hall_down, :hall_up}
```

`time` - time when order was created.

### `Elevator.Watchdog`

### `Elevator.Driver`

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elevator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elevator, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elevator](https://hexdocs.pm/elevator).

