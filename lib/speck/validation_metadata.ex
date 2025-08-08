defmodule Speck.ValidationMetadata do
  @moduledoc """
  Metadata about the validation that was performed.

  This is an opaque struct intended to be used by Speck's helper functions.
  """

  defstruct [:attributes]
end
