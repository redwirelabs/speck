struct HTTP.CreateDevice.V1

name "create_device"
endpoint "/devices"
verb "post"

attribute :uuid,          :string,  format: ~r/\Ad{5}\-d{5}\-d{5}\-d{5}\-d{5}\z/
attribute :type,          :atom,    values: [:temperature, :humidity, :air_quality]
attribute :rs485_address, :integer, min: 1, max: 255
attribute :serial_number, :string,  length: 16
attribute :location,      :string,  optional: true
