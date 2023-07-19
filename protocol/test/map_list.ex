struct TestSchema.MapList

name "map_list"

attribute [:devices] do
  attribute :id,   :integer
  attribute :type, :string, values: ["valid"]
end
