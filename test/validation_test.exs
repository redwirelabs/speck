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

    assert Coercer.coerce(MQTT.AddDevice.V1, params) == expected
  end

  test "returns error if value is the wrong type and can't be coerced" do
    params = %{
      "param1" => "invalid",
      "param2" => "invalid",
      "param3" => "invalid",
    }

    expected = {:error, %{
      param1: :wrong_type,
      param2: :wrong_type,
      param3: :wrong_type
    }}

    assert Coercer.coerce(TestSchema.WrongType, params) == expected  
  end

  describe "min limit" do
    test "coerces params that meet the min limit" do
      params = %{
        "param_integer" => 1,
        "param_float"   => 1.4,
        "param_string"  => "ab"
      }

      assert Coercer.coerce(TestSchema.MinMax, params) ==
        {:ok, %TestSchema.MinMax{
          param_integer: 1,
          param_float:   1.4,
          param_string:  "ab"
        }}
    end

    test "returns error if less than min limit" do
      params = %{
        "param_integer" => 0,
        "param_float"   => -1.6,
        "param_string"  => "a"
      }

      assert Coercer.coerce(TestSchema.MinMax, params) ==
        {:error, %{
          param_integer: :less_than_min,
          param_float:   :less_than_min,
          param_string:  :less_than_min
        }}
    end
  end

  describe "max limit" do
    test "coerces params that meet the max limit" do
      params = %{
        "param_integer" => 10,
        "param_float"   => 9.7,
        "param_string"  => "abcdefgh"
      }

      assert Coercer.coerce(TestSchema.MinMax, params) ==
        {:ok, %TestSchema.MinMax{
          param_integer: 10,
          param_float:   9.7,
          param_string:  "abcdefgh"
        }}
    end

    test "returns error if greater than max limit" do
      params = %{
        "param_integer" => 11,
        "param_float"   => 15.3,
        "param_string"  => "ABCDEFGHIJK"
      }

      assert Coercer.coerce(TestSchema.MinMax, params) ==
        {:error, %{
          param_integer: :greater_than_max,
          param_float:   :greater_than_max,
          param_string:  :greater_than_max
        }}
    end
  end
end
