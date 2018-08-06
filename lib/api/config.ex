defmodule Api.Config do
  @moduledoc false

  use GenServer

  def start_link(options) do
    api_options = options[:api_options]
    GenServer.start_link(__MODULE__, api_options, options)
  end

  def init(options) do
    {:ok, options}
  end

  def get(config, key) do
    GenServer.call(config, {:get, key})
  end

  def handle_call(request, _from, options) do
    case request do
      {:get, key} -> {:reply, Map.fetch(options, key), options}
    end
  end
end
