struct TestSchema.OptionalMapList

name "optional_map_list"

attribute :status, :atom, values: [:pending, :failed]

attribute [:transactions], optional: true do
  attribute :id,     :integer
  attribute :amount, :integer
end
