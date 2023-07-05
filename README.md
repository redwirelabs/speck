# ValidationTest

Goal: Input validation & protocol documentation. You could hand the schemas off to another team and they would understand the protocol. You don't have to worry about coercing into a struct that can be passed around the system at this point (Ecto style); it's not hard to transform that data into a different format once it's validated / trusted. Validation will mostly happen in event handlers (router, websocket, MQTT), ~~so anonymous maps & lists may work better than formal structs for validation output. You don't need a formal struct for everything if it's going to get thrown away a few lines later when your business logic is called.~~

```elixir
# Validation layer

%WebsocketMessage.ConfigureThermostat{}
%WebsocketMessage.RemoveThermostat{}

# Model layer

%Thermostat{}
```

The messages above can be versioned.

```elixir
# websocket/v1/configure_thermostat.ex
%WebsocketMessage.V1.ConfigureThermostat{}

# websocket/configure_thermostat.v1.ex
%WebsocketMessage.ConfigureThermostat.V1{}
```

It's ok to transform. In the input handler, perform the message validation. If the payload is invalid, it can fail fast and return the error(s) upstream. If it succeeds, transform the message into internal data (struct) and pass it to the model/context layer.

```elixir
message = coerce(ConfigureThermostat, params)

settings = %Thermostat{
  id: message.id,
  modbus_address: message.modbus_address
}

Thermostat.configure(settings)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `validation_test` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:validation_test, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/validation_test>.
