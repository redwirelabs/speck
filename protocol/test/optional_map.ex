struct TestSchema.OptionalMap

name "optional_map"

attribute :id, :integer
attribute :status, :atom, values: [:complete, :incomplete]

attribute :meta, optional: true do
  attribute :shape, :atom, values: [:circle, :square, :triangle], default: :circle
  attribute :size, :integer
  attribute :color, :string, optional: true
end
