defmodule Validation.Test do
  use ExUnit.Case

  test "coerces params to struct" do
    params = %{
      "uuid"          => "11111-22222-33333-44444-55555",
      "type"          => "air_quality",
      "rs485_address" => "5",
      "serial_number" => "DEVICE1234567890"
      # location      => not present
    }

    {:ok, device} = Coercer.coerce(MQTT.AddDevice.V1, params)

    assert device == %MQTT.AddDevice.V1{
      uuid:          "11111-22222-33333-44444-55555",
      type:          :air_quality,
      rs485_address: 5,
      serial_number: "DEVICE1234567890",
      location:      nil
    }
  end
end
