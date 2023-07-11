defmodule Coercer.Schema do
  @after_compile __MODULE__

  def __after_compile__(_env, _bytecode) do
    file = "protocol/mqtt/add_device.v1.exs"

    file_ast =
      file
      |> File.read!
      |> Code.string_to_quoted!

    {:__block__, _, top_ast} = file_ast

    context = Enum.reduce(top_ast, %{attributes: []}, fn
      {:struct, _, [{:__aliases__, _, _namespace} = module_ast]}, acc ->
        {module, _} = Code.eval_quoted(module_ast)
        Map.put(acc, :module, module)

      {:name, _, [name]}, acc ->
        Map.put(acc, :name, name)

      # {:attribute, _, [name, [do: {:__block__, _, _attributes}]]}, acc ->
      #   # ----------------------------------------------------------------------
      #   # TODO: Build nested attributes
      #   # ----------------------------------------------------------------------
      #   attributes = acc.attributes ++ [{name, :map}]
      #   Map.put(acc, :attributes, attributes)

      {:attribute, _, [name, type, opts_ast]}, acc ->
        {opts, _} = Code.eval_quoted(opts_ast)
        attributes = acc.attributes ++ [{name, type, opts}]
        Map.put(acc, :attributes, attributes)

      _, acc ->
        acc
    end)

    top_level_attribute_names = Enum.map(context.attributes, &elem(&1, 0))

    module_ast =
      quote do
        defmodule unquote(Macro.escape(context.module)) do
          defstruct unquote(Macro.escape(top_level_attribute_names))

          def attributes, do: unquote(Macro.escape(context.attributes))
        end
      end

    Code.eval_quoted(module_ast, [], [file: file])
  end
end
