if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshExclusiveArc.Install do
    @moduledoc """
    Installs AshExclusiveArc into your project.

    Adds `:ash_exclusive_arc` to your formatter configuration.

    ## Usage

        mix ash_exclusive_arc.install
    """
    @shortdoc "Installs AshExclusiveArc"

    use Igniter.Mix.Task

    @impl true
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{}
    end

    alias Igniter.Project.Formatter, as: ProjectFormatter

    @impl true
    def igniter(igniter) do
      ProjectFormatter.import_dep(igniter, :ash_exclusive_arc)
    end
  end
end
