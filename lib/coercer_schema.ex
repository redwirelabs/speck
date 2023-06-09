defmodule Coercer.Schema do
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def __attributes, do: @__attributes
    end
  end

  defmacro __using__(_args) do
    quote do
      import Coercer.Schema, only: [attribute: 2, attribute: 3]
      # require Coercer.Schema

      # def attribute(name, type), do: IO.inspect {name, type}
      # def attribute(name, type, source_name), do: IO.inspect {name, type, source_name}
    end
  end

  defmacro attribute(name, type) do
    quote do
      IO.inspect {unquote(name), unquote(type)}
    end
  end

  defmacro attribute(name, type, source_name) do
    quote do
      IO.inspect {unquote(name), unquote(type), unquote(source_name)}
    end
  end
end
