# Speck

A library for input validation and protocol documentation with a focus on being lightweight and tightly focused, designed for embedded systems and web applications.

## Installation

The package can be installed by adding `speck` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:speck, "~> 1.1.0"}
  ]
end
```

Add the Speck compiler to your `mix.exs` project config:

```elixir
compilers: [:speck] ++ Mix.compilers
```

## Configuration

Create schemas in the `protocol` directory at the root of your Elixir project. Schemas are compiled, and therefore should use the `.ex` extension. Schemas can be grouped into subfolders if your project interfaces with more than one transport. _Avoid_ putting your schemas in `lib`, as they use a different compiler than standard Elixir files. The schema directory can be changed in your project's mix config:

```elixir
config :speck, schema_path: "my_schemas"
```

## Philosophy

Speck is designed to be the validation layer for an application. The key here is "layer": Your application should employ a [layered architecture](https://www.oreilly.com/library/view/software-architecture-patterns/9781491971437/ch01.html) to use Speck effectively. Speck should sit between the external input and business logic layers. In an MVC framework this would be between the controller and model. The layers should have hard boundaries, meaning function calls can only happen sideways or to the layer directly below. Input and return values should pass through a transformation when crossing layer boundaries, preventing a layer from leaking through its neighbors.

![](assets/architecture.png)

> _Phoenix / Ecto users:_ Although Speck schemas may feel familiar compared to Ecto schemas, it is important to understand that the Speck design pattern is completely different. Phoenix uses a leaky abstraction to pass input params into a changeset / schema, which is used all the way down to the database. With Speck, the schema should represent the shape of the input, NOT the shape of the database. Validation should happen in the controller or live view, with the attributes of a valid schema then being passed to the context layer (business logic). The context layer should be responsible for constructing the application's internal representation of the data, which could be a struct or Ecto schema.

The structs used for validation should be different from the ones passed around internally. In an embedded system the structs would represent messages from another system. In a web application the structs would represent form data from an HTML page.

A good way to determine which layer a struct is in is to determine if it is a noun (`Device`) or a verb (`AddDevice`). Verbs are effects on your system, which are messages with payloads to validate. Nouns are a representation of an object internal to your system, and are below the validation layer.

```elixir
# Validation layer

%MQTT.AddDevice{}
%MQTT.RemoveDevice{}

# Model layer

%Device{}
```

The schemas can also be versioned.

```elixir
# mqtt/v1/add_device.ex
%MQTT.V1.AddDevice{}

# mqtt/add_device.v1.ex
%MQTT.AddDevice.V1{}
```

Transform data when crossing layers. In the input handler, perform the message validation. If the payload is invalid, it can fail fast and return the error(s) upstream. If it succeeds, transform the message into internal data (struct) and pass it to the business logic layer.

```elixir
def input_received(params) do
  case Speck.validate(MQTT.AddDevice.V1, params) do
    {:ok, message, _meta} ->
      device = Device.create!(message.id, message.rs485_address)
      {:ok, device}

    {:error, errors, _meta} ->
      {:error, errors}
  end
end
```

### Schemas as documentation

Speck supports the "documentation as code" philosophy and is designed to document the input payloads with its description language. The same file that explains the input to an engineer is the same one executed to validate the input. This prevents documentation for people from going out of date with the source code. The schemas can also be used for collaboration when designing or explaining a protocol. They are designed to be reasonably comprehensible by non-Elixir engineers.

Schemas can't be nested. They are designed to be the complete representation of a message. If you find yourself trying to nest schemas, it is likely a code smell for something you should be doing in the business logic or storage layers.

```elixir
struct MQTT.AddDevice.V1

name "add_device"

attribute :uuid,           :string,  format: ~r/\A\d{5}\-\d{5}\-\d{5}\-\d{5}\-\d{5}\z/
attribute :type,           :atom,    values: [:temperature, :humidity, :air_quality]
attribute :rs485_address,  :integer, min: 1, max: 255
attribute :serial_number,  :string,  length: 16
attribute :wifi_ssid,      :string,  optional: true
attribute :low_power_mode, :boolean, optional: true
attribute :dns_servers,    [:string]
attribute :user_data,      :any

attribute :metadata do
  attribute :location,        :string
  attribute :department,      :string
  attribute :commissioned_at, :datetime

  attribute :ports do
    attribute :rs485, :integer, strict: true
  end
end

attribute [:sensors], optional: true do
  attribute :type,    :atom
  attribute :address, :integer
end
```

## Schema syntax

- `struct` - Name of the Elixir struct this schema will compile to.
- `name` (optional) - Name of this message or event on the wire.
- `strict` (optional) - Set `true` if enforcing value type for all attributes.
- `attribute` - An attribute in the input payload. These could also be known as fields, properties, keys.

### Attributes

The top-level input payload is assumed to be a map, since this is common in many cases. If it is not in your case, transform the input into a map before validating it with Speck.

Attributes consist of a name, type, and optional validation arguments:

```text
attribute <name>, <type>, <options>
```

Types:
- `any`
- `boolean`
- `integer`
- `float`
- `string`
- `atom`
- `date` (ISO 8601)
- `time` (ISO 8601)
- `datetime` (ISO 8601)
- `map`

Lists:
- Create a list of any type by wrapping the type in square brackets: `[string]`

Options:
- `strict` - Set `true` if enforcing value type instead of best attempt to coerce.
  - error - `wrong_type`
- `default` - The default value is used if the value is not present in the input.
- `optional` - Set `true` if a value for the attribute is not required.
  - error - `not_present`
- `min` - Minimum value for a number, or minimum length for a string.
  - error - `less_than_min`
- `max` - Maximum value for a number, or maximum length for a string.
  - error - `greater_than_max`
- `length` - Exact length for a string.
  - error - `wrong_length`
- `values` - List of valid values (an enum).
  - error - `invalid_value`
- `format` - Regular expression for the valid format of a string.
  - error - `wrong_format`

The `any` type:
- Intended to be a passthrough attribute where the value is not validated or coerced but the value must be not `nil` at a minimum if `optional: false`. The `any` type is useful if you want to split out schemas where the top level schema is a generic envelope containing a nested data structure that could possibly be of a polymorphic nature. **Example**:

```elixir
struct MQTT.AWS.Shadow.Update.V1

name "aws_shadow_update"

attribute :state do
  attribute :desired, :any
end
```

```elixir
struct MQTT.Light.State.V1

name "light_state"

attribute [:schedule] do
  attribute :start, :datetime
  attribute :stop,  :datetime
end
```

```elixir
with {:ok, shadow, _meta}      <- Speck.validate(MQTT.AWS.Shadow.Update.V1, payload),
     {:ok, light_state, _meta} <- Speck.validate(MQTT.Light.State.V1, shadow.state.desired) do
  # do something with light_state
end
```

### Examples

Example schemas can be found in [/protocol](https://github.com/amclain/speck/tree/main/protocol).

## Order of operations

Speck is designed to allow developers to focus on the data coming out of Speck rather than going into Speck. Therefore, its default behavior is to attempt to coerce a value to the attribute's type and then validate the value. This is known as permissive validation, and can help when working with unruly third-party protocols.

### Strict validation

In some cases, strict validation may be required rather than permissive validation. Enabling Speck's strict validation will require the input values to match their spec's attribute type or else the payload will not be valid.

There are two ways to enable strict validation: globally, or per attribute.

**Global**

Add the top-level `strict true` property. Opt out per attribute.

```elixir
struct MQTT.AddDevice.V1

name "add_device"

strict true

attribute :name, :string
attribute :type, :string, strict: false
```

**Per attribute**

Opt in per attribute by adding `strict: true`.

```elixir
struct MQTT.AddDevice.V1

name "add_device"

attribute :id,   :integer, strict: true
attribute :name, :string
```

## Validation metadata

In certain situations, only having the coerced data may not be enough, and you may need information about the input data as well. Since Speck has already traversed the input data, information about it is collected and returned as validation metadata. Speck provides `Speck.ValidationMetadata.Attribute` for working with metadata attributes that describe the input data structure.

### Device shadows

One scenario where Speck's metadata is helpful is when working with a device shadow, like in AWS IoT Core. This shadow uses a `desired` property for sending data to an embedded device, and `reported` for the device to report its current state. When validating one of these messages with Speck, the schema will not know about new desired properties if they are added in the cloud before the firmware is updated. Unfortunately, AWS will continue to send delta updates until these new desired properties are acknowledged in the reported properties.

In this case, the metadata can be captured along with the validated message.

```elixir
{:ok, message, meta} <- Speck.validate(MQTT.AWS.Shadow.Update.V1, payload)
```

The new, unknown fields will be filtered out of `message` during the validation process, as expected. This message is trusted data that should still be sent down to the business logic layer for processing. However, the unknown fields need to be reported to the device shadow to acknowledge them. This is where `meta` comes in.

Using `meta`, the unknown fields can be selected with a filter, and they can be merged into the `reported` map to send to the shadow.

```elixir
shadow = %{
  state: %{
    reported: %{
      # Real data to report to the shadow ...
    }
  }
}

meta
|> Attribute.list
|> Enum.filter(fn
    # Only  capture the device shadow state, not the metadata.
    {["state" | _rest], :unknown, _value} -> true
    {_path, _status, _value}  -> false
end)
|> Enum.map(fn
  {["state" | rest], status, value} ->
    {["state", "reported"] ++ rest, status, value}
)
|> Attribute.merge(shadow)
```

### Fields as actions

Although typically fields in protocols carry data, sometimes their presence or a `nil` value signifies an action to perform. For example, setting a field `nil` signifies a delete (remove/cleanup) should be performed, versus the field not being present meaning there is no change. Speck's coercion process intentionally obscures this, since the primary goal is to normalize the input into a consistent data structure. This is another situation where Speck's metadata can be used to determine which fields are marked for deletion.

```elixir
{:ok, message, meta} <- Speck.validate(DeltaMessage, payload)

attributes_to_delete =
  meta
  |> Attribute.list
  |> Enum.filter(fn
      {_path, :present, nil}   -> true
      {_path, _status, _value} -> false
  end)
  |> Attribute.merge(%{})
```

The resulting map can then be traversed in the business logic layer, performing removal actions for each component that a nil field represents.

```
%{
  "device_is_installed" => nil,
  "remote_sensors" => [
    %{"temperature_sensor_1" => nil}
  ]
}
```
