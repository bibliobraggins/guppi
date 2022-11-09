defmodule GuppiTest do
  use ExUnit.Case
  doctest Guppi

  test "greets the world" do
    assert Guppi.hello() == :world
  end
end
