defmodule ValidationTest.Thermostat do
  use Coercer.Schema
  require Coercer.Schema

  defstruct [
    :modbus_id,
    :heating_setpoint,
    :cooling_setpoint,
    :temperature,
    :humidity
  ]

  attribute :modbus_id, :integer, "id"
  attribute :heating_setpoint, :integer, "hsp"
  attribute :cooling_setpoint, :integer, "csp"
  attribute :temperature, :integer
  attribute :humidity, :integer

  # attribute :heating_setpoint, :integer, ["id", "something", "hsp"]
  # attribute :devices, [Device]

  # @impl Coercer
  def attributes do
    [
      {:modbus_id, :integer, "id"},
      {:heating_setpoint, :integer, "hsp"},
      {:cooling_setpoint, :integer, "csp"},
      {:temperature, :integer},
      {:humidity, :integer},
    ]
  end

  # @impl Coercer
  # def validate(params) do
  #   params
  #   |> required([:modbus_id, :heating_setpoint, :cooling_setpoint, :temperature, :humidity])
  #   |> validate_non_negative_integer(:modbus_id)
  # end

  # defp validate_non_negative_integer(name, value) do
  #   case value < 0 do
  #     false ->
  #       error(value, "not positive")

  #     _ ->
  #       value
  #   end
  # end
end
