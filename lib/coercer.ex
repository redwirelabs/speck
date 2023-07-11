defmodule Coercer do
  def coerce(schema, params) do
    fields = do_coerce(:map, params, [], schema.attributes)
    struct = struct(schema, fields)

    {:ok, struct}
  end

  # This is the entry point for applying global options to coerced values.
  defp do_coerce(name, type, raw_value, opts, struct, attributes) do
    cond do
      opts[:optional] && is_nil(raw_value) && type == :boolean ->
        Map.put(struct, name, false)

      opts[:optional] && is_nil(raw_value) ->
        struct

      type == :map ->
        value = do_coerce(type, raw_value, opts, attributes)
        Map.put(struct, name, value)

      true ->
        value = do_coerce(type, raw_value, opts)
        Map.put(struct, name, value)
    end
  end

  defp do_coerce(:map, value, _opts, attributes) do
    Enum.reduce(attributes, %{}, fn
      {name, :map, opts, attributes}, acc ->
        raw_value = value[to_string(name)] || value[name]
        do_coerce(name, :map, raw_value, opts, acc, attributes)

      {name, type, opts}, acc ->
        raw_value = value[to_string(name)] || value[name]
        do_coerce(name, type, raw_value, opts, acc, nil)
    end)
  end

  defp do_coerce(:boolean, value, _opts) when is_boolean(value), do: value

  defp do_coerce(:integer, value, _opts) when is_integer(value), do: value
  defp do_coerce(:integer, value, _opts) when is_float(value), do: trunc(value)
  defp do_coerce(:integer, value, _opts) when is_binary(value) do
    {value, _} = Integer.parse(value)
    value
  end

  defp do_coerce(:float, value, _opts) when is_float(value), do: value
  defp do_coerce(:float, value, _opts) when is_integer(value), do: value / 1
  defp do_coerce(:float, value, _opts) when is_binary(value) do
    {value, _} = Float.parse(value)
    value
  end

  defp do_coerce(:string, value, _opts), do: to_string(value)

  defp do_coerce(:atom, value, _opts) when is_binary(value), do: String.to_atom(value)
  defp do_coerce(:atom, value, _opts) when is_atom(value), do: value
end
