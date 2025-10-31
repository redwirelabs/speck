struct TestSchema.NestedOptionalMap

name "nested_optional_map"

attribute :id, :integer

attribute :meta, optional: true do
  attribute :more_meta, optional: true do
    attribute :status, :atom, values: [:complete, :incomplete]
  end
end
