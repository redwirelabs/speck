defmodule ValidationTestTest do
  use ExUnit.Case

  alias ValidationTest.Thermostat

  test "coerces params to struct" do
    params = %{
      "id" => "10",
      "hsp" => 64,
      "csp" => 75,
      "temperature" => 71,
      "humidity" => 39
    }

    {:ok, thermostat} = Coercer.coerce(ValidationTest.Thermostat, params)

    assert thermostat == %Thermostat{
      modbus_id: 10,
      heating_setpoint: 64,
      cooling_setpoint: 75,
      temperature: 71,
      humidity: 39,
    }
  end
end
