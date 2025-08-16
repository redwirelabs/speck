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

    assert {
      :ok,
      %MQTT.AddDevice.V1{
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
      },
      _meta
    } = Speck.validate(MQTT.AddDevice.V1, params)
  end

  test "can have a default value" do
    params = %{}

    assert {
      :ok,
      %TestSchema.Default{
        param1: 2,
        param2: 2.4,
        param3: "foo",
        param4: :foo,
        param5: true,
        param6: ~U[2023-05-15 01:02:03Z],
        param7: ~D[2023-05-15],
        param8: ~T[01:02:03],
      },
      _meta
    } = Speck.validate(TestSchema.Default, params)
  end

  test "returns error if a required value isn't present" do
    params = %{}

    assert {
      :error,
      %{
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
      },
      _meta
    } = Speck.validate(MQTT.AddDevice.V1, params)
  end

  test "returns error if value is the wrong type and can't be coerced" do
    params = %{
      "param1" => "invalid",
      "param2" => "invalid",
      "param3" => "invalid",
      "param4" => 2.7,
      "param5" => 2.7,
      "param6" => 2.7,
      "param7" => %{},
      "param8" => {:type, :ipv4}
    }

    assert {
      :error,
      %{
        param1: :wrong_type,
        param2: :wrong_type,
        param3: :wrong_type,
        param4: :wrong_type,
        param5: :wrong_type,
        param6: :wrong_type,
        param7: :wrong_type,
        param8: :wrong_type,
      },
      _meta
    } = Speck.validate(TestSchema.WrongType, params)
  end

  test "can coerce a list of values" do
    params = %{
      "device_ids" => [1, 5, "8"]
    }

    assert {
      :ok,
      %TestSchema.List{device_ids: [1, 5, 8]},
      _meta
    } = Speck.validate(TestSchema.List, params)
  end

  test "return nil if optional list is not present" do
    params = %{
      "status" => "failed",
    }

    assert {
      :ok,
      %TestSchema.OptionalMapList{
        status: :failed,
        transactions: nil,
      },
      _meta
    } = Speck.validate(TestSchema.OptionalMapList, params)
  end

  test "returns errors if a list can't be coerced" do
    params = %{
      "device_ids" => [-3, 0, 4, 19]
    }

    assert {
      :error,
      %{
        device_ids: [
          %{index: 0, reason: :less_than_min},
          %{index: 1, reason: :less_than_min},
          %{index: 3, reason: :greater_than_max},
        ]
      },
      _meta
    } = Speck.validate(TestSchema.List, params)
  end

  test "can coerce a list of maps with a single attribute" do
    params = %{
      "devices" => [
        %{"type" => "imx6"},
        %{"type" => "imx8"},
        %{"type" => "am62"},
      ]
    }

    assert {
      :ok,
      %TestSchema.MapListSingleAttribute{
        devices: [
          %{type: "imx6"},
          %{type: "imx8"},
          %{type: "am62"},
        ]
      },
      _meta
    } = Speck.validate(TestSchema.MapListSingleAttribute, params)
  end

  test "can coerce a list of maps with multiple attributes" do
    params = %{
      "devices" => [
        %{"id" =>  1,  "type" => "valid"},
        %{"id" =>  2,  "type" => "valid"},
        %{"id" => "3", "type" => "valid"},
      ]
    }

    assert {
      :ok,
      %TestSchema.MapList{
        devices: [
          %{id: 1, type: "valid"},
          %{id: 2, type: "valid"},
          %{id: 3, type: "valid"},
        ]
      },
      _meta
    } = Speck.validate(TestSchema.MapList, params)
  end

  test "can coerce a map with attribute type of any" do
    params = %{
      "param1" => %{},
      "param2" => "valid"
    }

    assert {
      :ok,
      %TestSchema.Any{param1: %{}, param2: "valid"},
      _meta
    } = Speck.validate(TestSchema.Any, params)
  end

  test "returns errors if required params of type any are missing" do
    params = %{}

    assert {:error, %{param1: :not_present, param2: :not_present}, _meta} =
      Speck.validate(TestSchema.Any, params)
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

    assert {
      :error,
      %{
        devices: [
          %{index: 1, attribute: :id,   reason: :wrong_type},
          %{index: 1, attribute: :type, reason: :invalid_value},
          %{index: 2, attribute: :id,   reason: :wrong_type},
          %{index: 3, attribute: :id,   reason: :not_present},
          %{index: 3, attribute: :type, reason: :not_present},
        ]
      },
      _meta
    } = Speck.validate(TestSchema.MapList, params)
  end

  test "returns an error if attributes are not present" do
    params = %{}

    assert {
      :error,
      %{
        param1: :not_present,
        param2: :not_present,
        param3: :not_present,
        param4: :not_present,
        param5: :not_present,
        param6: :not_present,
        param7: :not_present,
        param8: :not_present,
      },
      _meta
    } = Speck.validate(TestSchema.NotPresent, params)
  end

    test "can coerce a struct when values pass strict validation" do
      params = %{
        "param1" => 1,
        "param2" => 2.0,
        "param3" => true,
        "param4" => "valid",
        "param5" => 1,
        "param6" => :valid,
        "param7" => ~U[1970-01-01 00:00:00Z],
        "param8" => ~D[1970-01-01],
        "param9" => ~T[00:00:00],
      }

      assert {
        :ok,
        %TestSchema.Strict{
          param1: 1,
          param2: 2.0,
          param3: true,
          param4: "valid",
          param5: "1",
          param6: :valid,
          param7: ~U[1970-01-01 00:00:00Z],
          param8: ~D[1970-01-01],
          param9: ~T[00:00:00],
        },
        _meta
      } = Speck.validate(TestSchema.Strict, params)
    end

  test "returns error if strict value is the wrong type" do
    params = %{
      "param1" => "invalid",
      "param2" => "invalid",
      "param3" => "invalid",
      "param4" => 2.7,
      "param5" => 2.7,
      "param6" => 2.7,
      "param7" => 2.7,
      "param8" => %{},
      "param9" => {:type, :ipv4}
    }

    assert {:error,
      %{
        param1: :wrong_type,
        param2: :wrong_type,
        param3: :wrong_type,
        param4: :wrong_type,
        param6: :wrong_type,
        param7: :wrong_type,
        param8: :wrong_type,
        param9: :wrong_type,
      },
      _meta
    } = Speck.validate(TestSchema.Strict, params)
  end

  test "falsy values coerce successfully" do
    params = %{
      "param1" => false,
      "param2" => "",
      "param3" => 0,
      "param4" => [false, false, false],
      "param5" => 0,
    }

    assert {
      :ok,
      %TestSchema.FalsyValues{
        param1: false,
        param2: "",
        param3: 0,
        param4: [false, false, false],
        param5: ~U[1970-01-01 00:00:00Z],
      },
      _meta
    } = Speck.validate(TestSchema.FalsyValues, params)
  end

  describe "datetime" do
    test "can parse ISO 8601 with zulu (UTC) offset" do
      params = %{
        "param1" => "2023-05-15 01:02:03Z"
      }

      assert {
        :ok,
        %TestSchema.DateTime{param1: ~U[2023-05-15 01:02:03Z]},
        _meta
      } = Speck.validate(TestSchema.DateTime, params)
    end

    test "can parse ISO 8601 with offset" do
      params = %{
        "param1" => "2023-05-15 11:15:04-07"
      }

      assert {
        :ok,
        %TestSchema.DateTime{param1: ~U[2023-05-15 18:15:04Z]},
        _meta
      } = Speck.validate(TestSchema.DateTime, params)
    end

    test "can parse ISO 8601 without offset" do
      params = %{
        "param1" => "2023-05-15 01:02:03"
      }

      assert {
        :ok,
        %TestSchema.DateTime{param1: ~N[2023-05-15 01:02:03]},
        _meta
      } = Speck.validate(TestSchema.DateTime, params)
    end

    test "can parse unix timestamp in seconds" do
      params = %{
        "param1" => 1684112523
      }

      assert {
        :ok,
        %TestSchema.DateTime{param1: ~U[2023-05-15 01:02:03Z]},
        _meta
      } = Speck.validate(TestSchema.DateTime, params)
    end

    test "passes through DateTime and NaiveDateTime structs" do
      params = %{
        "param1" => ~U[2023-05-15 01:02:03Z]
      }

      assert {
        :ok,
        %TestSchema.DateTime{param1: ~U[2023-05-15 01:02:03Z]},
        _meta
      } = Speck.validate(TestSchema.DateTime, params)

      params = %{
        "param1" => ~N[2023-05-15 01:02:03]
      }

      assert {
        :ok,
        %TestSchema.DateTime{param1: ~N[2023-05-15 01:02:03]},
        _meta
      } = Speck.validate(TestSchema.DateTime, params)
    end

    test "returns an error if the value can't be parsed" do
      params = %{
        "param1" => "invalid"
      }

      assert {:error, %{param1: :wrong_format}, _meta} =
        Speck.validate(TestSchema.DateTime, params)
    end
  end

  describe "date" do
    test "can parse ISO 8601" do
      params = %{
        "param1" => "2023-05-15"
      }

      assert {
        :ok,
        %TestSchema.Date{param1: ~D[2023-05-15]},
        _meta
      } = Speck.validate(TestSchema.Date, params)
    end

    test "passes through Date struct" do
      params = %{
        "param1" => ~D[2023-05-15]
      }

      assert {
        :ok,
        %TestSchema.Date{param1: ~D[2023-05-15]},
        _meta
      } = Speck.validate(TestSchema.Date, params)
    end

    test "returns an error if the value can't be parsed" do
      params = %{
        "param1" => "invalid"
      }

      assert {:error, %{param1: :wrong_format}, _meta} =
        Speck.validate(TestSchema.Date, params)
    end
  end

  describe "time" do
    test "can parse ISO 8601" do
      params = %{
        "param1" => "01:02:03"
      }

      assert {
        :ok,
        %TestSchema.Time{param1: ~T[01:02:03]},
        _meta
      } = Speck.validate(TestSchema.Time, params)
    end

    test "passes through Time struct" do
      params = %{
        "param1" => ~T[01:02:03]
      }

      assert {
        :ok,
        %TestSchema.Time{param1: ~T[01:02:03]},
        _meta
      } = Speck.validate(TestSchema.Time, params)
    end

    test "returns an error if the value can't be parsed" do
      params = %{
        "param1" => "invalid"
      }

      assert {:error, %{param1: :wrong_format}, _meta} =
        Speck.validate(TestSchema.Time, params)
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
        "param_time"     => "11:00:00",
      }

      assert {
        :ok,
        %TestSchema.MinMax{
          param_integer:  1,
          param_float:    1.4,
          param_string:   "ab",
          param_datetime: ~N[2023-05-15 00:00:00],
          param_date:     ~D[2023-05-15],
          param_time:     ~T[11:00:00],
        },
        _meta
      } = Speck.validate(TestSchema.MinMax, params)
    end

    test "returns error if less than min limit" do
      params = %{
        "param_integer"  => 0,
        "param_float"    => -1.6,
        "param_string"   => "a",
        "param_datetime" => "1970-01-01 00:00:00",
        "param_date"     => "1970-01-01",
        "param_time"     => "01:00:00",
      }

      assert {
        :error,
        %{
          param_integer:  :less_than_min,
          param_float:    :less_than_min,
          param_string:   :less_than_min,
          param_datetime: :less_than_min,
          param_date:     :less_than_min,
          param_time:     :less_than_min,
        },
        _meta
      } = Speck.validate(TestSchema.MinMax, params)
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
        "param_time"     => "11:00:00",
      }

      assert {
        :ok,
        %TestSchema.MinMax{
          param_integer:  10,
          param_float:    9.7,
          param_string:   "abcdefgh",
          param_datetime: ~N[2023-05-15 00:00:00],
          param_date:     ~D[2023-05-15],
          param_time:     ~T[11:00:00],
        },
        _meta
      } = Speck.validate(TestSchema.MinMax, params)
    end

    test "returns error if greater than max limit" do
      params = %{
        "param_integer"  => 11,
        "param_float"    => 15.3,
        "param_string"   => "ABCDEFGHIJK",
        "param_datetime" => "2050-01-01 00:00:00",
        "param_date"     => "2050-01-01",
        "param_time"     => "18:00:00",
      }

      assert {
        :error,
        %{
          param_integer:  :greater_than_max,
          param_float:    :greater_than_max,
          param_string:   :greater_than_max,
          param_datetime: :greater_than_max,
          param_date:     :greater_than_max,
          param_time:     :greater_than_max,
        },
        _meta
      } = Speck.validate(TestSchema.MinMax, params)
    end
  end

  describe "length" do
    test "coerces params that meet the required length" do
      params = %{"param" => "abc"}

      assert {:ok, %TestSchema.Length{param: "abc"}, _meta} =
        Speck.validate(TestSchema.Length, params)
    end

    test "returns an error if not equal to the required length" do
      params = %{"param" => "a"}

      assert {:error, %{param: :wrong_length}, _meta} =
        Speck.validate(TestSchema.Length, params)
    end
  end

  describe "format" do
    test "coerces params that meet the required format" do
      params = %{"param" => "abc"}

      assert {:ok, %TestSchema.Format{param: "abc"}, _meta} =
        Speck.validate(TestSchema.Format, params)
    end

    test "returns an error if not in the required format" do
      params = %{"param" => "ABC_DEF"}

      assert {:error, %{param: :wrong_format}, _meta} =
        Speck.validate(TestSchema.Format, params)
    end
  end

  describe "valid values" do
    test "coerces params that are valid values" do
      params = %{
        "param_string" => "foo",
        "param_atom"   => "bar",
      }

      assert {
        :ok,
        %TestSchema.ValidValues{param_string: "foo", param_atom:   :bar},
        _meta
      } = Speck.validate(TestSchema.ValidValues, params)
    end

    test "returns an error if not in the list of valid values" do
      params = %{
        "param_string" => "invalid",
        "param_atom"   => "invalid",
      }

      assert {
        :error,
        %{
          param_string: :invalid_value,
          param_atom:   :invalid_value,
        },
        _meta
      } = Speck.validate(TestSchema.ValidValues, params)
    end
  end

  test "generates metadata about the validated attributes" do
    params = %{
      attribute_1: 1,
      unknown_attribute_2: 2,
      attribute_4: [5, 10, 15],
      partially_known_nested: %{
        attribute_5: 5,
        unknown_attribute_6: 6
      },
      unknown_nested: %{
        unknown_attribute_7: 7
      },
      list_attribute_1: [
        %{unknown_attribute_8: 8},
        %{attribute_9: 9},
      ]
    }

    assert {:ok, message, meta} =
      Speck.validate(TestSchema.ValidationMetadata, params)

    assert message == %TestSchema.ValidationMetadata{
      attribute_1: 1,
      attribute_4: [5, 10, 15],
      partially_known_nested: %{
        attribute_5: 5
      },
      list_attribute_1: [
        %{},
        %{attribute_9: 9}
      ],
      list_attribute_2: []
    }

    assert Enum.member?(meta.attributes,
      {["attribute_1"], :present, 1}
    )
    assert Enum.member?(meta.attributes,
      {["attribute_3"], :not_present, nil}
    )
    assert Enum.member?(meta.attributes,
      {["attribute_4"], :present, [5, 10, 15]}
    )
    assert Enum.member?(meta.attributes,
      {["partially_known_nested", "attribute_5"], :present, 5}
    )
    assert Enum.member?(meta.attributes,
      {["list_attribute_1", 0, "attribute_9"], :not_present, nil}
    )
    assert Enum.member?(meta.attributes,
      {["list_attribute_1", 1, "attribute_9"], :present, 9}
    )
    assert Enum.member?(meta.attributes,
      {["list_attribute_2"], :not_present, nil}
    )
    assert Enum.member?(meta.attributes,
      {["unknown_attribute_2"], :unknown, 2}
    )
    assert Enum.member?(meta.attributes,
      {["partially_known_nested", "unknown_attribute_6"], :unknown, 6}
    )
    assert Enum.member?(meta.attributes,
      {["unknown_nested", "unknown_attribute_7"], :unknown, 7}
    )
    assert Enum.member?(meta.attributes,
      {["list_attribute_1", 0, "unknown_attribute_8"], :unknown, 8}
    )
  end

  test "metadata shows when attribues have nil values present" do
    params = %{
      attribute_1: 1,
      attribute_3: nil,
      attribute_4: [5],
      partially_known_nested: %{
        attribute_5: 5,
      },
      list_attribute_1: [
        %{attribute_9: nil},
      ],
      list_attribute_2: []
    }

    assert {:ok, message, meta} =
      Speck.validate(TestSchema.ValidationMetadata, params)

    assert message == %TestSchema.ValidationMetadata{
      attribute_1: 1,
      attribute_3: nil,
      attribute_4: [5],
      partially_known_nested: %{
        attribute_5: 5
      },
      list_attribute_1: [%{}],
      list_attribute_2: []
    }

    assert Enum.member?(meta.attributes,
      {["attribute_1"], :present, 1}
    )
    assert Enum.member?(meta.attributes,
      {["attribute_3"], :present, nil}
    )
    assert Enum.member?(meta.attributes,
      {["attribute_4"], :present, [5]}
    )
    assert Enum.member?(meta.attributes,
      {["partially_known_nested", "attribute_5"], :present, 5}
    )
    assert Enum.member?(meta.attributes,
      {["list_attribute_1", 0, "attribute_9"], :present, nil}
    )
    assert Enum.member?(meta.attributes,
      {["list_attribute_2"], :present, []}
    )
  end
end
