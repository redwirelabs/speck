defmodule Coercer do
  def coerce(schema, params) do
    struct = Enum.reduce(schema.attributes, struct(schema), fn
      {name, type, opts}, struct ->
        raw_value = params[to_string(name)] || params[name]
        run(name, type, raw_value, opts, struct)
    end)

    {:ok, struct}
  end

  defp run(name, type, raw_value, opts, struct) do
    cond do
      opts[:optional] && is_nil(raw_value) ->
        struct

      true ->
        value = do_coerce(type, raw_value, opts)
        Map.put(struct, name, value)
    end
  end

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
