defmodule Validation.Test do
  use ExUnit.Case

  test "coerces params to struct" do
    params = %{
      "uuid"           => "11111-22222-33333-44444-55555",
      "type"           => "air_quality",
      "rs485_address"  => "5",
      "serial_number"  => "DEVICE1234567890",
      # low_power_mode => not present
      "dns_servers"    => [
        "1.1.1.1",
        "1.0.0.1"
      ],
      "metadata" => %{
        "location"   => "Warehouse 1",
        "department" => "Logistics",
        "ports"      => %{
          "rs485" => 4
        }
      },
      "sensors" => [
        %{"type" => "temperature", "address" => 51},
        %{"type" => "humidity",    "address" => 72}
      ]
    }

    {:ok, device} = Coercer.coerce(MQTT.AddDevice.V1, params)

    assert device == %MQTT.AddDevice.V1{
      uuid:           "11111-22222-33333-44444-55555",
      type:           :air_quality,
      rs485_address:  5,
      serial_number:  "DEVICE1234567890",
      wifi_ssid:      nil,
      low_power_mode: false,
      dns_servers:    [
        "1.1.1.1",
        "1.0.0.1"
      ],
      metadata: %{
        location:   "Warehouse 1",
        department: "Logistics",
        ports:      %{
          rs485: 4
        }
      },
      sensors: [
        %{type: :temperature, address: 51},
        %{type: :humidity, address: 72},
      ]
    }
  end
end
