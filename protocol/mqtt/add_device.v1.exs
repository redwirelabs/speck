struct MQTT.AddDevice.V1

name "add_device"
# version 1

@doc "Server's ID for the device"
attribute :uuid,           :string,  format: ~r/\Ad{5}\-d{5}\-d{5}\-d{5}\-d{5}\z/
attribute :type,           :atom,    values: ["temperature", "humidity", "air_quality"]
attribute :rs485_address,  :integer, min: 1, max: 255
attribute :serial_number,  :string,  length: 16
attribute :wifi_ssid,      :string,  optional: true
attribute :low_power_mode, :boolean, optional: true
attribute :dns_servers,    [:string]

attribute :metadata do
  attribute :location, :string
  attribute :department, :string

  attribute :sensors do
    attribute :temperature, :boolean
  end
end

# attribute [:foo], optional: true do
#   attribute :bar, :string
#   attribute :baz, :string
# end
