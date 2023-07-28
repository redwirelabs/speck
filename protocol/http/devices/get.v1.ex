struct HTTP.GetDevice.V1

name "get_device"
endpoint "/device/:uuid"
verb "get"

attribute :uuid, :string, format: ~r/\A\d{5}\-\d{5}\-\d{5}\-\d{5}\-\d{5}\z/
