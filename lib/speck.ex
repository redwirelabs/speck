defmodule Speck do
  @moduledoc """
  Input validation & protocol documentation
  """

  alias Speck.ValidationMetadata

  @doc """
  Validate and coerce the params according to a schema.
  """
  @spec validate(schema :: module, params :: map) ::
      {:ok, struct, ValidationMetadata.t}
    | {:error, map, ValidationMetadata.t}
  def validate(schema, params) do
    opts = [strict: schema.strict()]

    do_validate(:map, params, opts, schema.attributes())
    |> then(fn {fields, errors, meta} ->
      {fields, errors, meta_add_unknown_fields(meta, params)}
    end)
    |> case do
      {fields, errors, meta} when errors == %{} ->
        struct = struct(schema, fields)

        {:ok, struct, %ValidationMetadata{attributes: meta}}

      {_fields, errors, meta} ->
        {:error, errors, %ValidationMetadata{attributes: meta}}
    end
  end

  defp apply_filters(name, type, raw_value, field_present, opts, fields, errors, attributes) do
    field_status = if field_present, do: :present, else: :not_present

    cond do
      !is_nil(opts[:default]) && is_nil(raw_value) ->
        {
          Map.put(fields, name, opts[:default]),
          errors,
          make_meta(name, field_status, raw_value)
        }

      type == :map && is_nil(raw_value) && opts[:optional] ->
        {
          Map.put(fields, name, nil),
          errors,
          [make_meta(name, field_status, raw_value)]
        }

      type == :map ->
        case do_validate(type, raw_value, opts, attributes) do
          {value, map_errors, meta} when map_errors == %{} ->
            {
              Map.put(fields, name, value),
              errors,
              meta_append_namespace(meta, name)
            }

          {value, map_errors, meta} ->
            {
              Map.put(fields, name, value),
              Map.put(errors, name, map_errors),
              meta_append_namespace(meta, name)
            }
        end

      is_nil(opts[:optional]) && is_nil(raw_value) ->
        {
          fields,
          Map.put(errors, name, :not_present),
          make_meta(name, field_status, raw_value)
        }

      opts[:optional] && is_nil(raw_value) ->
        {
          Map.put(fields, name, nil),
          errors,
          make_meta(name, field_status, raw_value)
        }

      is_list(type) ->
        raw_value
        |> Enum.with_index
        |> Enum.map(fn {value, index} ->
          {value, error, _meta} =
            apply_filters(:item, hd(type), value, true, opts, fields, %{}, nil)

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
            {
              Map.put(fields, name, value),
              errors,
              make_meta(name, field_status, raw_value)
            }

          {_value, error} ->
            {
              fields,
              Map.put(errors, name, error),
              make_meta(name, field_status, raw_value)
            }
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
            {
              fields,
              Map.put(errors, name, error),
              make_meta(name, field_status, raw_value)
            }

          value ->
            {value, _error = nil}
            |> apply_valid_values(opts[:values])
            |> apply_format(opts[:format])
            |> apply_length(opts[:length])
            |> apply_min(opts[:min])
            |> apply_max(opts[:max])
            |> case do
              {value, nil} ->
                {
                  Map.put(fields, name, value),
                  errors,
                  make_meta(name, field_status, raw_value)
                }

              {value, error} ->
                {
                  Map.put(fields, name, value),
                  Map.put(errors, name, error),
                  make_meta(name, field_status, raw_value)
                }
            end
        end
    end
  end

  defp do_strict_validate(:any, value, _opts), do: value
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
    Enum.reduce(attributes, {_values = %{}, _errors = %{}, _meta = []}, fn
      {name, [:map], opts, attributes}, {fields, errors, meta} ->
        merged_opts = Keyword.merge(global_opts, opts)
        raw_values  = get_raw_value(value, name) || []

        coerced_maplist =
          raw_values
          |> Enum.map(&do_validate(:map, &1, merged_opts, attributes))
          |> Enum.with_index
          |> Enum.reduce({_values = [], _errors = [], _meta = []}, fn
            {{value, error, this_meta}, index}, {values, errors, meta2}
              when error == %{} and errors == [] ->
                {
                  values ++ [value],
                  errors,
                  meta2 ++ meta_append_namespace(this_meta, index)
                }

            {{_value, error, this_meta}, index}, {values, errors, meta2}
              when error == %{} ->
                {
                  values,
                  errors,
                  meta2 ++ meta_append_namespace(this_meta, index)
                }

            {{_value, error, this_meta}, index}, {_values, errors, meta2} ->
              map_errors = Enum.reduce(error, [], fn {k, v}, acc ->
                acc ++ [%{index: index, attribute: k, reason: v}]
              end)

              {
                [],
                errors ++ map_errors,
                meta2 ++ meta_append_namespace(this_meta, index)
              }
          end)
          |> then(fn {fields, errors, meta2} ->
            {fields, errors, meta ++ meta_append_namespace(meta2, name)}
          end)

        case coerced_maplist do
          {[], [], meta2} ->
            raw_value = get_raw_value(value, name)
            status    = if is_present?(value, name), do: :present, else: :not_present
            value     = if opts[:optional] && is_nil(raw_value), do: nil, else: []
            new_meta  = meta2 ++ [make_meta(name, status, raw_value)]

            {Map.put(fields, name, value), errors, new_meta}

          {value, [], meta2} ->
            {Map.put(fields, name, value), errors, meta2}

          {value, error, meta2} ->
            {Map.put(fields, name, value), Map.put(errors, name, error), meta2}
        end

      {name, :map, opts, attributes}, {fields, errors, meta} ->
        merged_opts = Keyword.merge(global_opts, opts)
        raw_value   = get_raw_value(value, name)
        present     = is_present?(value, name)

        {fields2, errors2, meta2} =
          apply_filters(name, :map, raw_value, present, merged_opts, fields, errors, attributes)

        {fields2, errors2, meta ++ meta2}

      {name, type, opts}, {fields, errors, meta} ->
        merged_opts = Keyword.merge(global_opts, opts)
        raw_value   = get_raw_value(value, name)
        present     = is_present?(value, name)

        {fields2, errors2, meta2} =
          apply_filters(name, type, raw_value, present, merged_opts, fields, errors, nil)

        {fields2, errors2, meta ++ [meta2]}
    end)
  end

  defp do_validate(:any, value, _opts), do: value

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

  defp is_present?(nil, _key), do: false
  defp is_present?(map, key) when is_map_key(map, key), do: true
  defp is_present?(map, key), do: Map.has_key?(map, to_string(key))

  defp make_meta(name, status, value) when is_list(name) do
    {name, status, value}
  end

  defp make_meta(name, status, value) when is_integer(name) do
    {[name], status, value}
  end

  defp make_meta(name, status, value) do
    {[to_string(name)], status, value}
  end

  defp meta_append_namespace(meta, name) when is_list(meta) do
    Enum.map(meta, &meta_append_namespace(&1, name))
  end

  defp meta_append_namespace({path, status, value} = _meta, name)
    when is_binary(name) or is_number(name) do
      {[name] ++ path, status, value}
  end

  defp meta_append_namespace(meta, name) do
    meta_append_namespace(meta, to_string(name))
  end

  defp meta_add_unknown_fields(meta, input) do
    input_meta = input_fields_present(input)

    Enum.reduce(input_meta, meta, fn {path, _status, raw_value}, acc ->
      case has_field?(path, meta) do
        true -> acc
        _    -> acc ++ [make_meta(path, :unknown, raw_value)]
      end
    end)
  end

  defp input_fields_present(input) do
    Enum.reduce(input, [], fn
      # Guard against structs to prevent special types like date/time from
      # getting matched here.
      {key, value}, acc when is_map(value) and not is_struct(value) ->
        acc ++ meta_append_namespace(input_fields_present(value), key)

      {key, value}, acc when is_list(value) ->
        value
        |> Enum.with_index
        |> Enum.reduce_while([], fn
          {value2, index}, acc2 when is_map(value2) and not is_struct(value) ->
            meta = meta_append_namespace(input_fields_present(value2), index)
            {:cont, acc2 ++ meta}

          {_value2, _index}, acc2 ->
            # Lists of primitives aren't indexed in the path, so exit early
            # if this is not a list of maps.
            {:halt, acc2}
        end)
        |> then(fn acc2 -> acc ++ meta_append_namespace(acc2, key) end)

      {key, value}, acc ->
        acc ++ [make_meta(key, nil, value)]
    end)
  end

  defp has_field?(search_path, meta) do
    Enum.reduce_while(meta, false, fn
      {path, _status, _value}, acc ->
        case path_match?(search_path, path) do
          true -> {:halt, true}
          _    -> {:cont, acc}
        end
    end)
  end

  defp path_match?([], []),
    do: true

  defp path_match?([:_ | rest1], [_any | rest2]),
    do: path_match?(rest1, rest2)

  defp path_match?([value | rest1], [value | rest2]),
    do: path_match?(rest1, rest2)

  defp path_match?(_, _),
    do: false
end
