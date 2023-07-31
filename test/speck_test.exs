defmodule Speck.Test do
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
        "1.0.0.1",
      ],
      "metadata" => %{
        "location"        => "Warehouse 1",
        "department"      => "Logistics",
        "commissioned_at" => "2023-05-15 18:15:04Z",
        "ports"           => %{
          "rs485" => 4
        }
      },
      "sensors" => [
        %{"type" => "temperature", "address" => 51},
        %{"type" => "humidity",    "address" => 72},
      ]
    }

    assert Speck.validate(MQTT.AddDevice.V1, params) ==
      {:ok, %MQTT.AddDevice.V1{
        uuid:           "11111-22222-33333-44444-55555",
        type:           :air_quality,
        rs485_address:  5,
        serial_number:  "DEVICE1234567890",
        wifi_ssid:      nil,
        low_power_mode: false,
        dns_servers:    [
          "1.1.1.1",
          "1.0.0.1",
        ],
        metadata: %{
          location:        "Warehouse 1",
          department:      "Logistics",
          commissioned_at: ~U[2023-05-15 18:15:04Z],
          ports:           %{
            rs485: 4
          }
        },
        sensors: [
          %{type: :temperature, address: 51},
          %{type: :humidity,    address: 72},
        ]
      }}
  end

  test "can have a default value" do
    params = %{}

    assert Speck.validate(TestSchema.Default, params) ==
      {:ok, %TestSchema.Default{
        param1: 2,
        param2: 2.4,
        param3: "foo",
        param4: :foo,
        param5: true,
        param6: ~U[2023-05-15 01:02:03Z],
        param7: ~D[2023-05-15],
      }}
  end

  test "returns error if a required value isn't present" do
    params = %{}

    assert Speck.validate(MQTT.AddDevice.V1, params) ==
      {:error, %{
        uuid:          :not_present,
        type:          :not_present,
        rs485_address: :not_present,
        serial_number: :not_present,
        dns_servers:   :not_present,
        metadata: %{
          location:        :not_present,
          department:      :not_present,
          commissioned_at: :not_present,
          ports: %{
            rs485: :not_present,
          }
        }
      }}
  end

  test "returns error if value is the wrong type and can't be coerced" do
    params = %{
      "param1" => "invalid",
      "param2" => "invalid",
      "param3" => "invalid",
      "param4" => 2.7,
      "param5" => 2.7,
    }

    assert Speck.validate(TestSchema.WrongType, params) ==
      {:error, %{
        param1: :wrong_type,
        param2: :wrong_type,
        param3: :wrong_type,
        param4: :wrong_type,
        param5: :wrong_type,
      }}
  end

  test "can coerce a list of values" do
    params = %{
      "device_ids" => [1, 5, "8"]
    }

    assert Speck.validate(TestSchema.List, params) ==
      {:ok, %TestSchema.List{
        device_ids: [1, 5, 8]
      }}
  end

  test "returns errors if a list can't be coerced" do
    params = %{
      "device_ids" => [-3, 0, 4, 19]
    }

    assert Speck.validate(TestSchema.List, params) ==
      {:error, %{
        device_ids: [
          %{index: 0, reason: :less_than_min},
          %{index: 1, reason: :less_than_min},
          %{index: 3, reason: :greater_than_max},
        ]
      }}
  end

  test "can coerce a list of maps" do
    params = %{
      "devices" => [
        %{"id" =>  1,  "type" => "valid"},
        %{"id" =>  2,  "type" => "valid"},
        %{"id" => "3", "type" => "valid"},
      ]
    }

    assert Speck.validate(TestSchema.MapList, params) ==
      {:ok, %TestSchema.MapList{
        devices: [
          %{id: 1, type: "valid"},
          %{id: 2, type: "valid"},
          %{id: 3, type: "valid"},
        ]
      }}
  end

  test "returns errors if items in a list of maps can't be coerced" do
    params = %{
      "devices" => [
        %{"id" => 12345,     "type" => "valid"},
        %{"id" => "invalid", "type" => "invalid"},
        %{"id" => "invalid", "type" => "valid"},
        %{},
      ]
    }

    assert Speck.validate(TestSchema.MapList, params) ==
      {:error, %{
        devices: [
          %{index: 1, attribute: :id,   reason: :wrong_type},
          %{index: 1, attribute: :type, reason: :invalid_value},
          %{index: 2, attribute: :id,   reason: :wrong_type},
          %{index: 3, attribute: :id,   reason: :not_present},
          %{index: 3, attribute: :type, reason: :not_present},
        ]
      }}
  end

  test "returns an error if attributes are not present" do
    params = %{}

    assert Speck.validate(TestSchema.NotPresent, params) ==
      {:error, %{
        param1: :not_present,
        param2: :not_present,
        param3: :not_present,
        param4: :not_present,
        param5: :not_present,
        param6: :not_present,
        param7: :not_present,
      }}
  end

  test "falsy values coerce successfully" do
    params = %{
      "param1" => false,
      "param2" => "",
      "param3" => 0,
      "param4" => [false, false, false],
      "param5" => 0,
    }

    assert Speck.validate(TestSchema.FalsyValues, params) ==
      {:ok, %TestSchema.FalsyValues{
        param1: false,
        param2: "",
        param3: 0,
        param4: [false, false, false],
        param5: ~U[1970-01-01 00:00:00Z],
      }}
  end

  describe "datetime" do
    test "can parse ISO 8601 with zulu (UTC) offset" do
      params = %{
        "param1" => "2023-05-15 01:02:03Z"
      }

      assert Speck.validate(TestSchema.DateTime, params) ==
        {:ok, %TestSchema.DateTime{
          param1: ~U[2023-05-15 01:02:03Z]
        }}
    end

    test "can parse ISO 8601 with offset" do
      params = %{
        "param1" => "2023-05-15 11:15:04-07"
      }

      assert Speck.validate(TestSchema.DateTime, params) ==
        {:ok, %TestSchema.DateTime{
          param1: ~U[2023-05-15 18:15:04Z]
        }}
    end

    test "can parse ISO 8601 without offset" do
      params = %{
        "param1" => "2023-05-15 01:02:03"
      }

      assert Speck.validate(TestSchema.DateTime, params) ==
        {:ok, %TestSchema.DateTime{
          param1: ~N[2023-05-15 01:02:03]
        }}
    end

    test "can parse unix timestamp in seconds" do
      params = %{
        "param1" => 1684112523
      }

      assert Speck.validate(TestSchema.DateTime, params) ==
        {:ok, %TestSchema.DateTime{
          param1: ~U[2023-05-15 01:02:03Z]
        }}
    end

    test "passes through DateTime and NaiveDateTime structs" do
      params = %{
        "param1" => ~U[2023-05-15 01:02:03Z]
      }

      assert Speck.validate(TestSchema.DateTime, params) ==
        {:ok, %TestSchema.DateTime{
          param1: ~U[2023-05-15 01:02:03Z]
        }}

      params = %{
        "param1" => ~N[2023-05-15 01:02:03]
      }

      assert Speck.validate(TestSchema.DateTime, params) ==
        {:ok, %TestSchema.DateTime{
          param1: ~N[2023-05-15 01:02:03]
        }}
    end

    test "returns an error if the value can't be parsed" do
      params = %{
        "param1" => "invalid"
      }

      assert Speck.validate(TestSchema.DateTime, params) ==
        {:error, %{param1: :wrong_format}}
    end
  end

  describe "date" do
    test "can parse ISO 8601" do
      params = %{
        "param1" => "2023-05-15"
      }

      assert Speck.validate(TestSchema.Date, params) ==
        {:ok, %TestSchema.Date{
          param1: ~D[2023-05-15]
        }}
    end

    test "passes through Date struct" do
      params = %{
        "param1" => ~D[2023-05-15]
      }

      assert Speck.validate(TestSchema.Date, params) ==
        {:ok, %TestSchema.Date{
          param1: ~D[2023-05-15]
        }}
    end

    test "returns an error if the value can't be parsed" do
      params = %{
        "param1" => "invalid"
      }

      assert Speck.validate(TestSchema.Date, params) ==
        {:error, %{param1: :wrong_format}}
    end
  end

  describe "min limit" do
    test "coerces params that meet the min limit" do
      params = %{
        "param_integer"  => 1,
        "param_float"    => 1.4,
        "param_string"   => "ab",
        "param_datetime" => "2023-05-15 00:00:00",
        "param_date"     => "2023-05-15",
      }

      assert Speck.validate(TestSchema.MinMax, params) ==
        {:ok, %TestSchema.MinMax{
          param_integer:  1,
          param_float:    1.4,
          param_string:   "ab",
          param_datetime: ~N[2023-05-15 00:00:00],
          param_date:     ~D[2023-05-15],
        }}
    end

    test "returns error if less than min limit" do
      params = %{
        "param_integer"  => 0,
        "param_float"    => -1.6,
        "param_string"   => "a",
        "param_datetime" => "1970-01-01 00:00:00",
        "param_date"     => "1970-01-01",
      }

      assert Speck.validate(TestSchema.MinMax, params) ==
        {:error, %{
          param_integer:  :less_than_min,
          param_float:    :less_than_min,
          param_string:   :less_than_min,
          param_datetime: :less_than_min,
          param_date:     :less_than_min,
        }}
    end
  end

  describe "max limit" do
    test "coerces params that meet the max limit" do
      params = %{
        "param_integer"  => 10,
        "param_float"    => 9.7,
        "param_string"   => "abcdefgh",
        "param_datetime" => "2023-05-15 00:00:00",
        "param_date"     => "2023-05-15",
      }

      assert Speck.validate(TestSchema.MinMax, params) ==
        {:ok, %TestSchema.MinMax{
          param_integer:  10,
          param_float:    9.7,
          param_string:   "abcdefgh",
          param_datetime: ~N[2023-05-15 00:00:00],
          param_date:     ~D[2023-05-15],
        }}
    end

    test "returns error if greater than max limit" do
      params = %{
        "param_integer"  => 11,
        "param_float"    => 15.3,
        "param_string"   => "ABCDEFGHIJK",
        "param_datetime" => "2050-01-01 00:00:00",
        "param_date"     => "2050-01-01",
      }

      assert Speck.validate(TestSchema.MinMax, params) ==
        {:error, %{
          param_integer:  :greater_than_max,
          param_float:    :greater_than_max,
          param_string:   :greater_than_max,
          param_datetime: :greater_than_max,
          param_date:     :greater_than_max,
        }}
    end
  end

  describe "length" do
    test "coerces params that meet the required length" do
      params = %{"param" => "abc"}

      assert Speck.validate(TestSchema.Length, params) ==
        {:ok, %TestSchema.Length{param: "abc"}}
    end

    test "returns an error if not equal to the required length" do
      params = %{"param" => "a"}

      assert Speck.validate(TestSchema.Length, params) ==
        {:error, %{param: :wrong_length}}
    end
  end

  describe "format" do
    test "coerces params that meet the required format" do
      params = %{"param" => "abc"}

      assert Speck.validate(TestSchema.Format, params) ==
        {:ok, %TestSchema.Format{param: "abc"}}
    end

    test "returns an error if not in the required format" do
      params = %{"param" => "ABC_DEF"}

      assert Speck.validate(TestSchema.Format, params) ==
        {:error, %{param: :wrong_format}}
    end
  end

  describe "valid values" do
    test "coerces params that are valid values" do
      params = %{
        "param_string" => "foo",
        "param_atom"   => "bar",
      }

      assert Speck.validate(TestSchema.ValidValues, params) ==
        {:ok, %TestSchema.ValidValues{
          param_string: "foo",
          param_atom:   :bar
        }}
    end

    test "returns an error if not in the list of valid values" do
      params = %{
        "param_string" => "invalid",
        "param_atom"   => "invalid",
      }

      assert Speck.validate(TestSchema.ValidValues, params) ==
        {:error, %{
          param_string: :invalid_value,
          param_atom:   :invalid_value,
        }}
    end
  end
end
