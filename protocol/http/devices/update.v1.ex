struct HTTP.UpdateDevice.V1

name "update_device"
endpoint "/device/:id"
verb "put"
version 1

attribute :uuid,          :string,  format: ~r/\Ad{5}\-d{5}\-d{5}\-d{5}\-d{5}\z/
attribute :type,          :atom,    optional: true, values: ["temperature", "humidity", "air_quality"]
attribute :rs485_address, :integer, optional: true, min: 1, max: 255
attribute :serial_number, :string,  optional: true, length: 16
attribute :location,      :string,  optional: true
