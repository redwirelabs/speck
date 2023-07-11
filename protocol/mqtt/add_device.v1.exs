struct MQTT.AddDevice.V1

name "add_device"
# version 1

@doc "Server's ID for the device"
attribute :uuid,          :string,  format: ~r/\Ad{5}\-d{5}\-d{5}\-d{5}\-d{5}\z/
attribute :type,          :atom,    values: ["temperature", "humidity", "air_quality"]
attribute :rs485_address, :integer, min: 1, max: 255
attribute :serial_number, :string,  length: 16
attribute :location,      :string,  optional: true

# attribute :some_list, [:string]

# attribute :foo do
#   attribute :bar, :string
#   attribute :baz, :string
# end

# attribute [:foo], max: 10 do
#   attribute :bar, :string
#   attribute :baz, :string
# end
