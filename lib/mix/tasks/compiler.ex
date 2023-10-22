defmodule Mix.Tasks.Compile.Speck do
  @moduledoc """
  Compiles Speck schemas
  """

  use Mix.Task.Compiler

  @impl Mix.Task.Compiler
  def run(_args) do
    schema_path  = Application.get_env(:speck, :schema_path, "protocol")
    schema_files = Path.wildcard("#{schema_path}/**/*.ex")
    hashes       = hashes(schema_files)
    manifest     = load_manifest()

    modified_files =
      hashes -- Enum.map(manifest, fn {hash, schema_file, _module} -> {hash, schema_file} end)

    compiled_files =
      Enum.map(modified_files, fn {_hash, schema_file} ->
        Mix.Shell.IO.info "Compiling #{schema_file}"

        schema_file
        |> compile()
        |> Enum.map(fn {module, bytecode} ->
          module_path = module_path(module)

          File.mkdir_p(Path.dirname(module_path))
          File.write!(module_path, bytecode)

          new_hash = hash(schema_file)

          {new_hash, schema_file, module}
        end)
      end)
      |> List.flatten

    removed_files =
      Enum.map(manifest, fn {_hash, schema_file, _module} -> schema_file end) -- schema_files

    new_manifest =
      manifest
      |> Enum.reject(fn {_hash, schema_file, _module} ->
        Enum.member?(removed_files, schema_file)
      end)
      |> Enum.reject(fn {_hash, schema_file, _module} ->
        Enum.find(modified_files, fn {_h, sf} -> schema_file == sf end)
      end)
      |> Enum.concat(compiled_files)

    save_manifest(new_manifest)

    # BEAM file cleanup scenarios to check for when modifying this code:
    #
    # - Deleting a schema should delete the corresponding BEAM file.
    #
    #   Delete protocol/test/date.ex and make sure
    #   _build/dev/lib/speck/ebin/Elixir.TestSchema.Date.beam is removed
    #   by the compiler.
    #
    # - Renaming a schema's struct should delete the BEAM file for the
    #   struct's old name and create a BEAM file with the new name.
    #
    #   Open protocol/test/date.ex and change the struct name to
    #   TestSchema.Date.V2. Check in _build/dev/lib/speck/ebin that
    #   Elixir.TestSchema.Date.beam has been removed and
    #   Elixir.TestSchema.Date.V2.beam has been created.
    #
    # - Deleting a schema and then renaming another schema's struct to the
    #   deleted one should remove the renamed schema's old BEAM file.
    #
    #   Delete protocol/test/date.ex. Open protocol/test/datetime.ex and rename
    #   the struct to TestSchema.Date. Check in _build/dev/lib/speck/ebin that
    #   Elixir.TestSchema.DateTime.beam has been removed and that
    #   Elixir.TestSchema.Date.beam was recompiled.

    files_to_clean =
      (manifest -- new_manifest)
      |> Enum.reject(fn {_hash, _schema_file, module} ->
        Enum.find(compiled_files, fn {_h, _sf, m} -> module == m end)
      end)

    Enum.each(files_to_clean, fn {_hash, _schema_file, module} ->
      File.rm(module_path(module))
    end)

    :ok
  end

  @impl Mix.Task.Compiler
  def manifests do
    [manifest_path()]
  end

  @impl Mix.Task.Compiler
  def clean do
    File.rm_rf(manifest_path())
  end

  defp manifest_path do
    Path.join(Mix.Project.app_path, "speck.manifest")
  end

  defp module_path(module) do
    Path.join([Mix.Project.app_path, "ebin", "#{module}.beam"])
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
          @moduledoc false
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

  defp build_attribute({:attribute, _, [name, type, opts_ast]})
    when type in [:date, :time, :datetime] do
      {opts, _} = Code.eval_quoted(opts_ast)

      opts =
        opts
        |> maybe_coerce_opt(:min, type)
        |> maybe_coerce_opt(:max, type)
        |> maybe_coerce_opt(:default, type)

      {name, type, opts}
  end

  defp build_attribute({:attribute, _, [name, type, opts_ast]}) do
    {opts, _} = Code.eval_quoted(opts_ast)
    {name, type, opts}
  end

  defp maybe_coerce_opt(opts, key, type) do
    if is_nil(opts[key]),
      do:   opts,
      else: Keyword.put(opts, key, coerce(type, opts[key]))
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
    case File.read(manifest_path()) do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      {:error, :enoent} -> []
      {:error, reason} -> raise "Failed to load manifest: #{reason}"
    end
  end

  defp save_manifest(manifest) do
    File.write!(manifest_path(), :erlang.term_to_binary(manifest))
  end

  defp coerce(:date, value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date}               -> date
      {:error, :invalid_format} -> {:error, :wrong_format}
      error                     -> error
    end
  end

  defp coerce(:date, %Date{} = value) do
    value
  end

  defp coerce(:time, value) when is_binary(value) do
    case Time.from_iso8601(value) do
      {:ok, time}               -> time
      {:error, :invalid_format} -> {:error, :wrong_format}
      error                     -> error
    end
  end

  defp coerce(:time, %Time{} = value) do
    value
  end

  defp coerce(:datetime, value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, datetime} -> datetime
          error           -> error
        end

      error ->
        error
    end
  end

  defp coerce(:datetime, value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, datetime} -> datetime
      error           -> error
    end
  end

  defp coerce(:datetime, %DateTime{} = value) do
    value
  end

  defp coerce(:datetime, %NaiveDateTime{} = value) do
    value
  end
end
