defmodule Speck.ValidationMetadata.Attribute.Test do
  use ExUnit.Case

  alias Speck.ValidationMetadata.Attribute

  describe "use case" do
    test "can merge unknown attributes back into a device shadow" do
      shadow_reported = %{
        "attribute_1" => 11,
        "partially_known_nested" => %{
          "attribute_5" => 15
        },
        "list_attribute_1" => [
          %{"attribute_9" => 19},
          %{"attribute_9" => 20}
        ]
      }

      payload = %{
        "attribute_1" => 1,
        "unknown_attribute_2" => 2,
        "attribute_4" => [5, 10, 15],
        "partially_known_nested" => %{
          "attribute_5" => 5,
          "unknown_attribute_6" => 6
        },
        "unknown_nested" => %{
          "unknown_attribute_7" => 7
        },
        "list_attribute_1" => [
          %{"unknown_attribute_8" => 8},
          %{"attribute_9" => 9},
        ]
      }

      {:ok, _, meta} = Speck.validate(TestSchema.ValidationMetadata, payload)

      merged_attributes =
        meta
        |> Attribute.list
        |> Enum.filter(fn
            {_path, :unknown, _value} -> true
            {_path, _status, _value}  -> false
        end)
        |> Attribute.merge(shadow_reported)

      assert merged_attributes == %{
        "attribute_1" => 11,
        "unknown_attribute_2" => 2,
        "partially_known_nested" => %{
          "attribute_5" => 15,
          "unknown_attribute_6" => 6
        },
        "unknown_nested" => %{
          "unknown_attribute_7" => 7
        },
        "list_attribute_1" => [
          %{"attribute_9" => 19, "unknown_attribute_8" => 8},
          %{"attribute_9" => 20}
        ]
      }
    end

    test "can find attributes that should be deleted" do
      payload = %{
        "attribute_3" => nil,
        "attribute_1" => 1,
        "unknown_attribute_2" => 2,
        "attribute_4" => [5, 10, 15],
        "partially_known_nested" => %{
          "attribute_5" => 5,
          "unknown_attribute_6" => 6
        },
        "list_attribute_1" => [
          %{"attribute_9" => nil},
        ]
      }

      {:ok, _, meta} = Speck.validate(TestSchema.ValidationMetadata, payload)

      delete_attributes =
        meta
        |> Attribute.list
        |> Enum.filter(fn
            {_path, :present, nil}   -> true
            {_path, _status, _value} -> false
        end)
        |> Attribute.merge(%{})

      assert delete_attributes == %{
        "attribute_3" => nil,
        "list_attribute_1" => [
          %{"attribute_9" => nil}
        ]
      }
    end
  end
end
