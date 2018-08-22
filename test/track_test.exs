defmodule TrackTest do
  @moduledoc false

  use ExUnit.Case

  test "runs the application" do
    assert Track.run(["list"]) |> String.split("\n") |> Enum.count() >= 1

    assert Track.run(["list", "--verbose"]) |> String.split("\n") |> Enum.count() >= 1

    config_file = "run/existing-config-file"

    assert File.touch(config_file) == :ok
    assert Track.run(["list", "--config", config_file]) |> String.split("\n") |> Enum.count() >= 1

    assert File.write(config_file, "some-param=1") == :ok
    assert Track.run(["list", "--config", config_file]) |> String.split("\n") |> Enum.count() >= 1

    assert File.write(config_file, "invalid-param") == :ok
    assert Track.run(["list", "--config", config_file]) |> String.split("\n") |> Enum.count() >= 1

    target_log_file = "$PWD/run/#{UUID.uuid4()}_test.log"
    assert File.write(config_file, "log_file_path=#{target_log_file}") == :ok
    assert Track.run(["list", "--config", config_file]) |> String.split("\n") |> Enum.count() >= 1

    assert File.rm(config_file) == :ok

    assert_raise File.Error, fn ->
      Track.run(["list", "--config", "missing-config-file"])
    end

    assert Track.run(["start"]) |> String.split("\n") |> Enum.count() == 1

    assert Track.run(["invalid"]) |> String.split("\n") |> Enum.count() == 3

    assert Track.run([]) |> String.split("\n") |> Enum.count() == 3
  end
end
