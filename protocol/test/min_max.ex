struct TestSchema.MinMax

name "min_max"

attribute :param_integer,  :integer,  min: 1,                     max: 10
attribute :param_float,    :float,    min: 1.4,                   max: 9.7
attribute :param_string,   :string,   min: 2,                     max: 8
attribute :param_datetime, :datetime, min: "2020-01-01 00:00:00", max: "2030-01-01 00:00:00"
attribute :param_date,     :date,     min: "2020-01-01",          max: "2030-01-01"
attribute :param_time,     :time,     min: "05:00:00",            max: "14:00:00"
