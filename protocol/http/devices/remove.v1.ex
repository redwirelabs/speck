struct HTTP.RemoveDevice.V1

name "remove_device"
endpoint "/device/:id"
verb "delete"

attribute :uuid, :string, format: ~r/\Ad{5}\-d{5}\-d{5}\-d{5}\-d{5}\z/
