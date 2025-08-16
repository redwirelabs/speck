struct TestSchema.ValidationMetadata

attribute :attribute_1, :integer
attribute :attribute_3, :integer, optional: true
attribute :attribute_4, [:integer]

attribute :partially_known_nested do
  attribute :attribute_5, :integer
end

attribute [:list_attribute_1] do
  attribute :attribute_9, :integer, optional: true
end

attribute [:list_attribute_2] do
  attribute :attribute_10, :integer
end
