struct TestSchema.ValidValues

name "valid_values"

attribute :param_string, :string, values: ["foo", "bar"]
attribute :param_atom,   :atom,   values: [:foo, :bar]
