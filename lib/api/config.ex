defmodule Api.Config do
  @moduledoc """
  Simple read-only configuration storage service.

  All config is supplied at init time and can later be retrieved using `Api.Config.get/2`.

  Expected options:
  - `:api_options` - the configuration to store
  """

  use GenServer

  def start_link(options) do
    api_options = options[:api_options]
    GenServer.start_link(__MODULE__, api_options, options)
  end

  def init(options) do
    {:ok, options}
  end

  @doc """
  Retrieves the config stored for `key` from the supplied `config` service.
  """

  def get(config, key) do
    GenServer.call(config, {:get, key})
  end

  def handle_call(request, _from, options) do
    case request do
      {:get, key} -> {:reply, Map.fetch(options, key), options}
    end
  end
end
