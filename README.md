# Speck

Goal: Input validation & protocol documentation. You could hand the schemas off to another team and they would understand the protocol. You don't have to worry about coercing into a struct that can be passed around the system at this point (Ecto style); it's not hard to transform that data into a different format once it's validated / trusted. Validation will mostly happen in event handlers (router, websocket, MQTT), ~~so anonymous maps & lists may work better than formal structs for validation output. You don't need a formal struct for everything if it's going to get thrown away a few lines later when your business logic is called.~~

```elixir
# Validation layer

%MQTT.AddDevice{}
%MQTT.RemoveDevice{}

# Model layer

%Device{}
```

The messages above can be versioned.

```elixir
# mqtt/v1/add_device.ex
%MQTT.V1.AddDevice{}

# mqtt/add_device.v1.ex
%MQTT.AddDevice.V1{}
```

It's ok to transform. In the input handler, perform the message validation. If the payload is invalid, it can fail fast and return the error(s) upstream. If it succeeds, transform the message into internal data (struct) and pass it to the model/context layer.

```elixir
message = Speck.validate(MQTT.AddDevice.V1, params)

settings = %Device{
  id: message.id,
  rs485_address: message.rs485_address
}

Device.configure(settings)
```

## Installation

The package can be installed by adding `speck` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:speck, "~> 0.1.0"}
  ]
end
```

Add the Speck compiler to your `mix.exs` project config:

```elixir
compilers: Mix.compilers ++ [:speck]
```
