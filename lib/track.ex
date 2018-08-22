defmodule Track do
  @moduledoc """
  `Track`'s main module.
  """

  require Logger

  @doc """
  Application main entry point.
  """

  def main(args \\ []) do
    case run(args) do
      :ok -> nil
      output -> output |> IO.puts()
    end
  end

  def run(args) do
    {options, args} = Cli.Parse.extract_application_options(args)

    if options[:verbose] do
      Logger.configure(level: :debug)
    else
      Logger.configure(level: :warn)
    end

    api_options = get_api_options(options)

    children = [
      {
        Api.Service,
        api_options: api_options
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Track.Supervisor)

    case Cli.Commands.args_to_command(args) do
      {:error, error} ->
        [
          ">: #{error}",
          Cli.Help.generate_usage_message()
        ]
        |> Enum.join("\n")

      {_action, :ok} ->
        :ok

      {_action, {:output, output}} ->
        output

      {action, {:error, message}} ->
        ">: Failed to process action [#{action}]: #{message}"
    end
  end

  def get_api_options(options) do
    default_options = %{
      store: Persistence.Log,
      store_options: %{log_file_path: Application.get_env(:track, :config)[:log_file_path]}
    }

    api_options =
      case options[:config] do
        nil ->
          default_options

        config_file ->
          log_file_path =
            File.stream!(config_file, [:utf8])
            |> Stream.filter(fn line -> String.starts_with?(line, "log_file_path=") end)
            |> Stream.flat_map(fn line ->
              line
              |> String.replace("\"", "")
              |> String.trim()
              |> String.split("=")
              |> Enum.take(-1)
            end)
            |> Enum.to_list()
            |> Enum.take(-1)

          case log_file_path do
            [log_file_path | _] ->
              %{
                store: Persistence.Log,
                store_options: %{log_file_path: log_file_path}
              }

            [] ->
              Logger.warn(
                "No [log_file_path] found in [#{config_file}]; using default: [#{
                  default_options[:store_options][:log_file_path]
                }]"
              )

              default_options
          end
      end

    current_log_file_path = get_in(api_options, [:store_options, :log_file_path])

    case Regex.run(~r/\${?(\w+)}?/, current_log_file_path) do
      [match, env_var] ->
        env_var = System.get_env(env_var)

        put_in(
          api_options,
          [:store_options, :log_file_path],
          current_log_file_path |> String.replace(match, env_var)
        )

      _ ->
        api_options
    end
  end
end
