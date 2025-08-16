defmodule Speck.ValidationMetadata do
  @moduledoc """
  Metadata about the validation that was performed.

  This is an opaque struct intended to be used by Speck's helper functions.
  """

  defstruct [:attributes]

  @type t :: %__MODULE__{}
end

defimpl Inspect, for: Speck.ValidationMetadata do
  def inspect(_meta, _opts) do
    "%Speck.ValidationMetadata{...}"
  end
end
