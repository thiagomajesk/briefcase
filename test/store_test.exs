defmodule Briefcase.StoreTest do
  use ExUnit.Case

  import Briefcase.Store

  alias Briefcase.Envelope

  describe "when store is empty" do
    test "merge/3 should add a new dirty entry" do
      store = merge(%{}, [foo: "foo"], true)
      expected = Envelope.new("foo", true)
      assert store[:foo] == expected
    end
  end

  describe "when store is nil" do
    test "merge/3 should add a new clean entry" do
      store = merge(nil, [foo: "foo"], false)
      expected = Envelope.new("foo", false)
      assert store[:foo] == expected
    end

    test "clean/1 should return an empty map" do
      assert clean(nil) == %{}
    end
  end

  describe "when store is not empty" do
    test "merge/3 should add a new entry" do
      store = %{foo: Envelope.new("foo", false)}
      store = merge(store, [bar: "bar"], false)
      expected = Envelope.new("bar", false)
      assert store[:bar] == expected
    end

    test "merge/3 should update an existing entry" do
      store = %{foo: Envelope.new("foo", true)}
      store = merge(store, [foo: "foo"], false)
      expected = Envelope.new("foo", false)
      assert store[:foo] == expected
    end
  end

  describe "when store has only dirty entries" do
    test "clean/1 should remove all" do
      store = %{foo: Envelope.new("foo", true), bar: Envelope.new("bar", true)}
      assert clean(store) == %{}
    end
  end

  describe "when store has both dirty and clean entries" do
    test "clean/1 should remove only the dirty entries" do
      store = %{foo: Envelope.new("foo", true), bar: Envelope.new("bar", false)}
      expected = %{bar: Envelope.new("bar", false)}
      assert clean(store) == expected
    end
  end

  test "toggle_dirty/2 should change dirty to true" do
    store = %{bar: Envelope.new("bar", false)}
    store = toggle_dirty(store, :bar, true)
    assert store[:bar].dirty == true
  end

  test "toggle_dirty/2 should change dirty to false" do
    store = %{foo: Envelope.new("foo", true)}
    store = toggle_dirty(store, :foo, false)
    assert store[:foo].dirty == false
  end

  test "make_all_dirty/2" do
    store = %{foo: Envelope.new("foo", false), bar: Envelope.new("bar", false)}
    store = make_all_dirty(store)
    assert store[:foo].dirty == true
    assert store[:bar].dirty == true
  end
end
