struct TestSchema.Any

name "any"

attribute :param1, :any
attribute :param2, :any, strict: true
attribute :param3, :any, optional: true
