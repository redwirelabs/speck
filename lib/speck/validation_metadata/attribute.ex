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
  """
  @spec merge(attributes :: [t], params :: map) :: map
  def merge(attributes, params) do
    Enum.reduce(attributes, params, fn {path, _status, value}, acc ->
      merge(acc, path, value)
    end)
  end

  defp merge(nil = _params, [path], value) do
    %{path => value}
  end

  defp merge(nil = _params, [attribute | path], value)
    when not is_integer(attribute) do
      %{attribute => merge(%{}, path, value)}
  end

  defp merge(params, [path], value) when is_map(params) do
    params
    |> to_key_strings()
    |> Map.put(path, value)
  end

  defp merge(params, [index | path], value) when is_integer(index) do
    params2  = params || []
    item     = Enum.at(params2, index)
    new_item = merge(item, path, value)

    case item do
      nil -> List.insert_at(params2, -1, new_item)
      _   -> List.replace_at(params2, index, new_item)
    end
  end

  defp merge(params, [attribute | path], value) do
    params2 = to_key_strings(params)
    Map.put(params2, attribute, merge(params2[attribute], path, value))
  end

  defp to_key_strings(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.into(%{})
  end
end
