struct TestSchema.Strict

name "strict"

strict true

attribute :param1, :integer
attribute :param2, :float
attribute :param3, :boolean
attribute :param4, :string
attribute :param5, :string, strict: false
attribute :param6, :atom
attribute :param7, :datetime
attribute :param8, :date
attribute :param9, :time
