# ValidationTest

Goal: Input validation & protocol documentation. You could hand the schemas off to another team and they would understand the protocol. You don't have to worry about coercing into a struct that can be passed around the system at this point (Ecto style); it's not hard to transform that data into a different format once it's validated / trusted. Validation will mostly happen in event handlers (router, websocket, MQTT), so anonymous maps & lists may work better than formal structs for validation output. You don't need a formal struct for everything if it's going to get thrown away a few lines later when your business logic is called.

**TODO: Add description**

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

