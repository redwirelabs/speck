defmodule Speck do
  @moduledoc """
  Input validation & protocol documentation
  """

  @doc """
  Validate and coerce the params according to a schema.
  """
  @spec validate(schema :: module, params :: map) :: {:ok, struct}, {:error, map}
  def validate(schema, params) do
    opts = [strict: schema.strict()]

    case do_validate(:map, params, opts, schema.attributes()) do
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

      is_list(type) ->
        raw_value
        |> Enum.with_index
        |> Enum.map(fn {value, index} ->
          {value, error} =
              apply_filters(:item, hd(type), value, opts, fields, %{}, nil)

          {index, value[:item], error[:item]}
        end)
        |> Enum.reduce({_values = [], _errors = []}, fn
          {_index, value, error}, {values, errors}
            when is_nil(error) and errors == [] ->
              {values ++ [value], errors}

          {_index, _value, error}, {_values, errors}
            when is_nil(error) ->
              {[], errors}

          {index, _value, error}, {_values, errors} ->
            {[], errors ++ [%{index: index, reason: error}]}
        end)
        |> case do
          {value, []} ->
            {Map.put(fields, name, value), errors}

          {_value, error} ->
            {fields, Map.put(errors, name, error)}
        end

      true ->
        strict_validation = opts[:strict]

        validate_fn =
          case strict_validation do
            true -> &do_strict_validate/3
            _ -> &do_validate/3
          end

        case validate_fn.(type, raw_value, opts) do
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
                {Map.put(fields, name, value), errors}

              {value, error} ->
                {Map.put(fields, name, value), Map.put(errors, name, error)}
            end
        end
    end
  end

  defp do_strict_validate(:boolean, value, _opts) when is_boolean(value), do: value
  defp do_strict_validate(:integer, value, _opts) when is_integer(value), do: value
  defp do_strict_validate(:float, value, _opts) when is_float(value), do: value
  defp do_strict_validate(:string, value, _opts) when is_binary(value), do: value
  defp do_strict_validate(:atom, value, _opts) when is_atom(value), do: value
  defp do_strict_validate(:date, %Date{} = value, _opts), do: value
  defp do_strict_validate(:time, %Time{} = value, _opts), do: value
  defp do_strict_validate(:datetime, %DateTime{} = value, _opts), do: value
  defp do_strict_validate(_type, _value, _opts), do: {:error, :wrong_type}

  defp do_validate(:map, value, global_opts, attributes) do
    Enum.reduce(attributes, {%{}, %{}}, fn
      {name, [:map], opts, attributes}, {fields, errors} ->
        merged_opts = Keyword.merge(global_opts, opts)
        raw_values  = get_raw_value(value, name) || []

        coerced_maplist =
          raw_values
          |> Enum.map(&do_validate(:map, &1, merged_opts, attributes))
          |> Enum.with_index
          |> Enum.reduce({_values = [], _errors = []}, fn
            {{value, error}, _index}, {values, errors}
              when error == %{} and errors == [] ->
                {values ++ [value], errors}

            {{_value, error}, _index}, {values, errors}
              when error == %{} ->
                {values, errors}

            {{_value, error}, index}, {_values, errors} ->
              map_errors = Enum.reduce(error, [], fn {k, v}, acc ->
                acc ++ [%{index: index, attribute: k, reason: v}]
              end)

              {[], errors ++ map_errors}
          end)

        case coerced_maplist do
          {value, []} ->
            {Map.put(fields, name, value), errors}

          {value, error} ->
            {Map.put(fields, name, value), Map.put(errors, name, error)}
        end

      {name, :map, opts, attributes}, {fields, errors} ->
        merged_opts = Keyword.merge(global_opts, opts)
        raw_value   = get_raw_value(value, name)

        apply_filters(name, :map, raw_value, merged_opts, fields, errors, attributes)

      {name, type, opts}, {fields, errors} ->
        merged_opts = Keyword.merge(global_opts, opts)
        raw_value   = get_raw_value(value, name)

        apply_filters(name, type, raw_value, merged_opts, fields, errors, nil)
    end)
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

  defp do_validate(:string, value, _opts) when is_map(value), do: {:error, :wrong_type}
  defp do_validate(:string, value, _opts) when is_tuple(value), do: {:error, :wrong_type}
  defp do_validate(:string, value, _opts) when is_pid(value), do: {:error, :wrong_type}
  defp do_validate(:string, value, _opts), do: to_string(value)

  defp do_validate(:atom, value, _opts) when is_binary(value), do: String.to_atom(value)
  defp do_validate(:atom, value, _opts) when is_atom(value), do: value

  defp do_validate(:date, value, _opts) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date}               -> date
      {:error, :invalid_format} -> {:error, :wrong_format}
      error                     -> error
    end
  end

  defp do_validate(:date, %Date{} = value, _opts) do
    value
  end

  defp do_validate(:time, value, _opts) when is_binary(value) do
    case Time.from_iso8601(value) do
      {:ok, time}               -> time
      {:error, :invalid_format} -> {:error, :wrong_format}
      error                     -> error
    end
  end

  defp do_validate(:time, %Time{} = value, _opts) do
    value
  end

  defp do_validate(:datetime, value, _opts) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, datetime}           -> datetime
          {:error, :invalid_format} -> {:error, :wrong_format}
          error                     -> error
        end

      {:error, :invalid_format} ->
        {:error, :wrong_format}

      error ->
        error
    end
  end

  defp do_validate(:datetime, value, _opts) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, datetime} -> datetime
      error           -> error
    end
  end

  defp do_validate(:datetime, %DateTime{} = value, _opts) do
    value
  end

  defp do_validate(:datetime, %NaiveDateTime{} = value, _opts) do
    value
  end

  defp do_validate(_type, _value, _opts), do: {:error, :wrong_type}

  defp apply_min({value, nil = _error}, limit) when not is_nil(limit) do
    v =
      case value do
        _ when is_float(value)   -> value
        _ when is_integer(value) -> value
        _ when is_binary(value)  -> String.length(value)
        %Date{}                  -> value
        %Time{}                  -> value
        %DateTime{}              -> value
        %NaiveDateTime{}         -> value
      end

    error? =
      case v do
        %Date{}          -> Date.compare(v, limit) == :lt
        %Time{}          -> Time.compare(v, limit) == :lt
        %DateTime{}      -> DateTime.compare(v, limit) == :lt
        %NaiveDateTime{} -> NaiveDateTime.compare(v, limit) == :lt
        _                -> v < limit
      end

    error = if error?, do: :less_than_min, else: nil

    {value, error}
  end

  defp apply_min({value, error}, _limit) do
    {value, error}
  end

  defp apply_max({value, nil = _error}, limit) when not is_nil(limit) do
    v =
      case value do
        _ when is_float(value)   -> value
        _ when is_integer(value) -> value
        _ when is_binary(value)  -> String.length(value)
        %Date{}                  -> value
        %Time{}                  -> value
        %DateTime{}              -> value
        %NaiveDateTime{}         -> value
      end

    error? =
      case v do
        %Date{}          -> Date.compare(v, limit) == :gt
        %Time{}          -> Time.compare(v, limit) == :gt
        %DateTime{}      -> DateTime.compare(v, limit) == :gt
        %NaiveDateTime{} -> NaiveDateTime.compare(v, limit) == :gt
        _                -> v > limit
      end

    error = if error?, do: :greater_than_max, else: nil

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

  defp get_raw_value(map, key) when is_map_key(map, key), do: map[key]
  defp get_raw_value(map, key), do: map[to_string(key)]
end
