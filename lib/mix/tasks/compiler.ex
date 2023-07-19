defmodule Mix.Tasks.Compile.Speck do
  @moduledoc """
  Compiles Speck schemas
  """

  use Mix.Task.Compiler

  @schema_path Application.compile_env(:speck, :schema_path, "protocol")
  @manifest_path Path.join(Mix.Project.app_path, "speck.manifest")

  @impl Mix.Task.Compiler
  def run(_args) do
    files = Path.wildcard("#{@schema_path}/**/*.ex")
    hashes = hashes(files)
    manifest = load_manifest()

    modified_files =
      hashes
      |> Enum.reject(&Enum.member?(manifest, &1))
      |> Enum.map(fn {_hash, file} -> file end)

    Enum.each(modified_files, fn file ->
      Mix.Shell.IO.info "Compiling #{file}"

      compile(file)
      |> Enum.each(fn {module, bytecode} ->
        path = Path.join([Mix.Project.app_path, "ebin", "#{module}.beam"])

        File.mkdir_p(Path.dirname(path))
        File.write(path, bytecode)
      end)
    end)

    files
    |> hashes()
    |> save_manifest()    

    :ok
  end

  @impl Mix.Task.Compiler
  def manifests do
    [@manifest_path]
  end

  @impl Mix.Task.Compiler
  def clean do
    File.rm_rf(@manifest_path)
  end

  defp compile(file) do
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

      {:attribute, _, _} = attribute_ast, acc ->
        attributes = acc.attributes ++ [build_attribute(attribute_ast)]
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

    Code.compile_quoted(module_ast, file)
  end

  defp build_attribute({:attribute, _, [[name], opts_ast, [do: {:__block__, _, attributes_ast}]]}) do
    {opts, _} = Code.eval_quoted(opts_ast)
    {name, [:map], opts, Enum.map(attributes_ast, &build_attribute/1)}
  end

  defp build_attribute({:attribute, _, [[name], [do: {:__block__, _, attributes_ast}]]}) do
    {name, [:map], [], Enum.map(attributes_ast, &build_attribute/1)}
  end

  defp build_attribute({:attribute, _, [name, opts_ast, [do: {:__block__, _, attributes_ast}]]}) do
    {opts, _} = Code.eval_quoted(opts_ast)
    {name, :map, opts, Enum.map(attributes_ast, &build_attribute/1)}
  end

  defp build_attribute({:attribute, _, [name, [do: {:__block__, _, attributes_ast}]]}) do
    {name, :map, [], Enum.map(attributes_ast, &build_attribute/1)}
  end

  defp build_attribute({:attribute, _, [name, [do: attributes_ast]]}) do
    {name, :map, [], [build_attribute(attributes_ast)]}
  end

  defp build_attribute({:attribute, _, [name, type]}) do
    {name, type, []}
  end

  defp build_attribute({:attribute, _, [name, type, opts_ast]}) do
    {opts, _} = Code.eval_quoted(opts_ast)
    {name, type, opts}
  end

  defp hashes(files) when is_list(files) do
    Enum.map(files, fn file ->
      {hash(file), file}
    end)
  end

  defp hash(file) when is_binary(file) do
    contents = File.read!(file)

    :crypto.hash(:sha256, contents)
    |> Base.encode16
    |> String.downcase
  end

  defp load_manifest do
    case File.read(@manifest_path) do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      {:error, :enoent} -> []
      {:error, reason} -> raise "Failed to load manifest: #{reason}"
    end
  end

  defp save_manifest(hashes) do
    File.write!(@manifest_path, :erlang.term_to_binary(hashes))
  end
end
