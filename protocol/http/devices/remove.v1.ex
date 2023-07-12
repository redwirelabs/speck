struct HTTP.RemoveDevice.V1

name "remove_device"
endpoint "/device/:id"
verb "delete"
version 1

attribute :uuid, :string, format: ~r/\Ad{5}\-d{5}\-d{5}\-d{5}\-d{5}\z/
