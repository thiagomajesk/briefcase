defmodule BriefcaseTest do
  use ExUnit.Case

  import Plug.Conn
  import Plug.Test

  alias Briefcase.Envelope

  @session_key "briefcase_store"

  describe "when the store has only dirty entries" do
    setup :get_transient_store

    test "should clean the store before redirect", context do
      result =
        context[:store]
        |> send_redirect()
        |> get_session(@session_key)

      assert(result == %{})
    end
  end

  describe "when the store has not dirty entries" do
    setup :get_persistent_store

    test "should not clean the store before redirect", context do
      result =
        context[:store]
        |> send_redirect()
        |> get_session(@session_key)

      expected = %{foo: Envelope.new("foo", false), bar: Envelope.new("bar", false)}
      assert(result == expected)
    end
  end

  describe "when the store is empty" do
    test "pack/2 should add a new briefcase to the store" do
      store =
        conn(:get, "/")
        |> init_test_session(%{})
        |> Briefcase.pack(hello: :world)
        |> get_session(@session_key)

      expected = Envelope.new(:world, false)
      assert(store[:hello] == expected)
    end

    test "pack/2 should merge the new briefcase in the store" do
      store =
        conn(:get, "/")
        |> init_test_session(%{@session_key => %{}})
        |> Briefcase.pack(hello: :world)
        |> get_session(@session_key)

      expected = Envelope.new(:world, false)
      assert(store[:hello] == expected)
    end
  end

  test "peek/3 should not mark entry dirty", context do
    with store <- %{foo: Envelope.new("foo", false)},
         conn <- conn(:get, "/"),
         conn <- init_test_session(conn, %{@session_key => store}),
         {conn, value} <- Briefcase.peek(conn, :foo),
         result <- get_session(conn, @session_key) do
      assert(result[:foo].dirty == false)
    end
  end

  test "unpack/3 should mark entry dirty", context do
    with store <- %{foo: Envelope.new("foo", false)},
         conn <- conn(:get, "/"),
         conn <- init_test_session(conn, %{@session_key => store}),
         {conn, value} <- Briefcase.unpack(conn, :foo),
         result <- get_session(conn, @session_key) do
      assert(result[:foo].dirty == true)
    end
  end

  defp get_persistent_store(_context) do
    [
      store: %{
        foo: Envelope.new("foo", false),
        bar: Envelope.new("bar", false)
      }
    ]
  end

  defp get_transient_store(_context) do
    [
      store: %{
        foo: Envelope.new("foo", true),
        bar: Envelope.new("bar", true)
      }
    ]
  end

  defp send_redirect(store) do
    conn(:get, "/")
    |> init_test_session(%{@session_key => store})
    |> Briefcase.call([])
    |> resp(301, "Redirect")
    |> send_resp()
  end
end
