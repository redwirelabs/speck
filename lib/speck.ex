defmodule Speck do
  def validate(schema, params) do
    case do_validate(:map, params, [], schema.attributes) do
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
        case do_validate(type, raw_value, opts, attributes) do
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
        case do_validate(type, raw_value, opts) do
          {:error, error} ->
            {fields, Map.put(errors, name, error)}

          value ->
            {value, _error = nil}
            |> apply_valid_values(opts[:values])
            |> apply_format(opts[:format])
            |> apply_length(opts[:length])
            |> apply_min(opts[:min])
            |> apply_max(opts[:max])
            |> case do
              {value, nil} ->
                {Map.put(fields, name, value), %{}}

              {value, error} ->
                {Map.put(fields, name, value), Map.put(errors, name, error)}
            end
        end
    end
  end

  defp do_validate(:map, value, _opts, attributes) do
    Enum.reduce(attributes, {%{}, %{}}, fn
      {name, [:map], opts, attributes}, {fields, errors} ->
        raw_values = value[to_string(name)] || value[name] || []

        coerced_maplist =
          raw_values
          |> Enum.map(&do_validate(:map, &1, opts, attributes))
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

  defp do_validate([type], value, opts) do
    Enum.map(value, &do_validate(type, &1, opts))
  end

  defp do_validate(:boolean, value, _opts) when is_boolean(value), do: value

  defp do_validate(:integer, value, _opts) when is_integer(value), do: value
  defp do_validate(:integer, value, _opts) when is_float(value), do: trunc(value)
  defp do_validate(:integer, value, _opts) when is_binary(value) do
    case Integer.parse(value) do
      {value, _} -> value
      :error     -> {:error, :wrong_type}
    end
  end

  defp do_validate(:float, value, _opts) when is_float(value), do: value
  defp do_validate(:float, value, _opts) when is_integer(value), do: value / 1
  defp do_validate(:float, value, _opts) when is_binary(value) do
    case Float.parse(value) do
      {value, _} -> value
      :error     -> {:error, :wrong_type}
    end
  end

  defp do_validate(:string, value, _opts), do: to_string(value)

  defp do_validate(:atom, value, _opts) when is_binary(value), do: String.to_atom(value)
  defp do_validate(:atom, value, _opts) when is_atom(value), do: value

  defp do_validate(_type, _value, _opts), do: {:error, :wrong_type}

  defp apply_min({value, nil = _error}, limit) when not is_nil(limit) do
    v =
      cond do
        is_float(value)   -> value
        is_integer(value) -> value
        is_binary(value)  -> String.length(value)
      end

    error = if v >= limit, do: nil, else: :less_than_min

    {value, error}
  end

  defp apply_min({value, error}, _limit) do
    {value, error}
  end

  defp apply_max({value, nil = _error}, limit) when not is_nil(limit) do
    v =
      cond do
        is_float(value)   -> value
        is_integer(value) -> value
        is_binary(value)  -> String.length(value)
      end

    error = if v <= limit, do: nil, else: :greater_than_max

    {value, error}
  end

  defp apply_max({value, error}, _limit) do
    {value, error}
  end

  defp apply_length({value, nil = _error}, limit) when not is_nil(limit) do
    error = if String.length(value) == limit, do: nil, else: :wrong_length
    {value, error}
  end

  defp apply_length({value, error}, _limit) do
    {value, error}
  end

  defp apply_format({value, nil = _error}, format) when not is_nil(format) do
    error = if Regex.match?(format, value), do: nil, else: :wrong_format
    {value, error}
  end

  defp apply_format({value, error}, _format) do
    {value, error}
  end

  defp apply_valid_values({value, nil = _error}, valid_values) when not is_nil(valid_values) do
    error = if Enum.member?(valid_values, value), do: nil, else: :invalid_value
    {value, error}
  end

  defp apply_valid_values({value, error}, _valid_values) do
    {value, error}
  end
end
