defmodule Coercer do
  def coerce(schema, params) do
    case do_coerce(:map, params, [], schema.attributes) do
      {fields, errors} when errors == %{} -> 
        struct = struct(schema, fields)
        {:ok, struct}

      {_fields, errors} ->
        {:error, errors}
    end
  end

  defp apply_filters(name, type, raw_value, opts, fields, errors, attributes) do
    cond do
      !is_nil(opts[:default]) && is_nil(raw_value) ->
        {Map.put(fields, name, opts[:default]), errors}

      type == :map ->
        case do_coerce(type, raw_value, opts, attributes) do
          {value, map_errors} when map_errors == %{} ->
            {Map.put(fields, name, value), errors}

          {value, map_errors} ->
            {Map.put(fields, name, value), Map.put(errors, name, map_errors)}
        end

      opts[:optional] && is_nil(raw_value) && type == :boolean ->
        {Map.put(fields, name, false), errors}

      is_nil(opts[:optional]) && is_nil(raw_value) ->
        {fields, Map.put(errors, name, :not_present)}

      opts[:optional] && is_nil(raw_value) ->
        {fields, errors}

      true ->
        case do_coerce(type, raw_value, opts) do
          {:error, error} ->
            {fields, Map.put(errors, name, error)}

          value ->
            {Map.put(fields, name, value), errors}
        end
    end
  end

  defp do_coerce(:map, value, _opts, attributes) do
    Enum.reduce(attributes, {%{}, %{}}, fn
      {name, [:map], opts, attributes}, {fields, errors} ->
        raw_values = value[to_string(name)] || value[name] || []

        coerced_maplist =
          raw_values
          |> Enum.map(&do_coerce(:map, &1, opts, attributes))
          |> Enum.reduce({[], []}, fn
            {value, %{}}, {values, errors} ->
              {values ++ [value], errors}

            {value, error}, {values, errors} ->
              {values ++ [value], errors ++ [error]}
          end)

        case coerced_maplist do
          {value, []} ->
            {Map.put(fields, name, value), errors}

          {value, error} ->
            {Map.put(fields, name, value), Map.put(errors, name, error)}
        end        

      {name, :map, opts, attributes}, {fields, errors} ->
        raw_value = value[to_string(name)] || value[name]
        apply_filters(name, :map, raw_value, opts, fields, errors, attributes)

      {name, type, opts}, {fields, errors} ->
        raw_value = value[to_string(name)] || value[name]
        apply_filters(name, type, raw_value, opts, fields, errors, nil)
    end)
  end

  defp do_coerce([type], value, opts) do
    Enum.map(value, &do_coerce(type, &1, opts))
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
