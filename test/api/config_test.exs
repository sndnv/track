defmodule Api.ConfigTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    start_supervised!({
      Api.Config,
      name: Config, api_options: %{option_one: 1, option_two: "2", option_three: "three"}
    })

    :ok
  end

  test "retrieves existing keys" do
    assert Api.Config.get(Config, :option_one) == {:ok, 1}
    assert Api.Config.get(Config, :option_two) == {:ok, "2"}
    assert Api.Config.get(Config, :option_three) == {:ok, "three"}
  end

  test "fails to retrieve missing keys" do
    assert Api.Config.get(Config, :missing_option) == :error
    assert Api.Config.get(Config, :another_missing_option) == :error
  end
end
