defmodule Briefcase.EnvelopeTest do
  use ExUnit.Case

  alias Briefcase.Envelope

  test "from/2" do
    temp_data = Envelope.from(foo: "foo")
    assert temp_data[:foo] == Envelope.new("foo", true)

    temp_data = Envelope.from([bar: "bar"], false)
    assert temp_data[:bar] == Envelope.new("bar", false)
  end
end
