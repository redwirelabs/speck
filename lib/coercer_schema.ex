defmodule Coercer.Schema do
  defmacro __using__(_args) do
    quote do
      import Coercer.Schema, only: [attribute: 2, attribute: 3]

      Module.register_attribute(__MODULE__, :attributes, [])
      Module.register_attribute(__MODULE__, :reversed_attributes,
        accumulate: true,
        persist: false
      )

      @before_compile Coercer.Schema
    end
  end

  defmacro __before_compile__(env) do
    reversed_attributes =
      Module.get_attribute(env.module, :reversed_attributes, [])
      |> Enum.reverse
    
    Module.put_attribute(env.module, :attributes, reversed_attributes)

    quote do
      defstruct Enum.map(@attributes, &elem(&1, 0))

      @doc false
      def attributes, do: @attributes
    end
  end

  defmacro attribute(name, type, opts \\ []) do
    quote do
      @reversed_attributes {unquote(name), unquote(type), unquote(opts)}
    end
  end
end
