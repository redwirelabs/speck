defmodule Coercer do
  def coerce(schema, params) do
    struct = Enum.reduce(schema.attributes, struct(schema), fn
      {name, type, source_name}, struct ->
        value = params[source_name]
        value = do_coerce(type, value)
        Map.put(struct, name, value)

      {name, type}, struct ->
        value = params[name] || params[to_string(name)]
        value = do_coerce(type, value)
        Map.put(struct, name, value)
    end)

    # case result do
    #   {struct, []} ->
    #     {:ok, struct}

    #   {_struct, errors} ->
    #     {:error, ...}
    # end

    {:ok, struct}
  end

  def do_coerce(:integer, value) when is_integer(value), do: value
  def do_coerce(:integer, value) when is_float(value), do: trunc(value)
  def do_coerce(:integer, value) when is_binary(value) do
    {value, _} = Integer.parse(value)
    value
  end

  def do_coerce(:float, value) when is_float(value), do: value
  def do_coerce(:float, value) when is_integer(value), do: value / 1
  def do_coerce(:float, value) when is_binary(value) do
    {value, _} = Float.parse(value)
    value
  end

  def do_coerce(:string, value), do: to_string(value)
end
