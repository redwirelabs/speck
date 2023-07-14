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
        %{type: :humidity,    address: 72},
      ]
    }
  end

  test "can have a default value" do
    params = %{}

    {:ok, struct} = Coercer.coerce(TestSchema.Default, params)

    assert struct == %TestSchema.Default{
      param1: 2,
      param2: 2.4,
      param3: "foo",
      param4: :foo,
      param5: true
    }
  end

  test "returns error if a required value isn't present" do
    params = %{}

    expected = {:error, %{
      uuid:          :not_present,
      type:          :not_present,
      rs485_address: :not_present,
      serial_number: :not_present,
      dns_servers:   :not_present,
      metadata: %{
        location:   :not_present,
        department: :not_present,
        ports: %{
          rs485: :not_present
        }
      }
    }}

    assert expected == Coercer.coerce(MQTT.AddDevice.V1, params)
  end
end
