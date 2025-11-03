defmodule Speck.ValidationMetadata.Attribute do
  @moduledoc """
  Work with validation metadata attributes
  """

  @type t :: {
    path :: [String.t | non_neg_integer],
    status :: :present | :not_present | :unknown,
    raw_value :: term
  }

  @doc """
  Returns a list of metadata attributes.
  """
  @spec list(meta :: Speck.ValidationMetadata.t) :: [t]
  def list(meta) do
    meta.attributes
  end

  @doc """
  Merge the values from metadata attributes into a given map.

  ## Opts
  - `:merge_strategy` - Determines whether a value in the params or attributes
    takes priority when both are present. Defaults to `:param_priority`.
  """
  @spec merge(
    attributes :: [t],
    params :: map,
    opts :: [merge_strategy: :param_priority | :attribute_priority]
  ) :: map
  def merge(attributes, params, opts \\ []) do
    merge_strategy = Keyword.get(opts, :merge_strategy, :param_priority)

    Enum.reduce(attributes, params, fn {path, _status, value}, acc ->
      merge(acc, path, value, merge_strategy)
    end)
  end

  defp merge(nil = _params, [path], value, _strategy) do
    %{path => value}
  end

  defp merge(nil = _params, [attribute | path], value, strategy)
    when not is_integer(attribute) do
      %{attribute => merge(%{}, path, value, strategy)}
  end

  defp merge(params, [path], value, strategy) when is_map(params) do
    params_with_key_strings = to_key_strings(params)

    skip_put =
         strategy == :param_priority
      && Map.has_key?(params_with_key_strings, path)

    case skip_put do
      true -> params_with_key_strings
      _    -> Map.put(params_with_key_strings, path, value)
    end
  end

  defp merge(params, [index | path], value, strategy) when is_integer(index) do
    params2  = params || []
    item     = Enum.at(params2, index)
    new_item = merge(item, path, value, strategy)

    case item do
      nil -> List.insert_at(params2, -1, new_item)
      _   -> List.replace_at(params2, index, new_item)
    end
  end

  defp merge(params, [attribute | path], value, strategy) do
    params2 = to_key_strings(params)
    Map.put(params2, attribute, merge(params2[attribute], path, value, strategy))
  end

  defp to_key_strings(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.into(%{})
  end
end
