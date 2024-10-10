defmodule Speck.MixProject do
  use Mix.Project

  def project do
    [
      app: :speck,
      version: "1.0.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env == :prod,
      compilers: Mix.compilers ++ [:speck],
      xref: [exclude: [:crypto]],
      aliases: aliases(),
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: [
        plt_add_apps: [:mix],
        list_unused_filters: true,
        plt_file: {:no_warn, plt_file_path()},
      ],
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      "docs.show": ["docs", &open("doc/index.html", &1)],
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
    ]
  end

  defp description do
    """
    Input validation & protocol documentation
    """
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE.txt"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/redwirelabs/speck"},
      maintainers: ["Alex McLain"],
      files: [
        "lib",
        "mix.exs",
        "LICENSE.txt",
        "README.md",
      ]
    ]
  end

  # Open a file with the default application for its type.
  defp open(file, _args) do
    open_command =
      System.find_executable("xdg-open") # Linux
      || System.find_executable("open")  # Mac
      || raise "Could not find executable 'open' or 'xdg-open'"

    System.cmd(open_command, [file])
  end

  # Path to the dialyzer .plt file.
  defp plt_file_path do
    [Mix.Project.build_path(), "plt", "dialyxir.plt"]
    |> Path.join()
    |> Path.expand()
  end
end
