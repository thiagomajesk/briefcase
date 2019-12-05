defmodule Briefcase.Store do
  @moduledoc false

  alias Briefcase.Envelope

  @doc """
  Merge the session store with the values passed in the keyword list.
  """
  @spec merge(map() | nil, keyword(), boolean()) :: map()
  def merge(store, keyword, dirty)

  def merge(nil, keyword, dirty)
      when is_list(keyword) and is_boolean(dirty),
      do: merge(%{}, keyword, dirty)

  def merge(store, keyword, dirty)
      when is_map(store) and is_list(keyword) and is_boolean(dirty) do
    Map.merge(store, Envelope.from(keyword, dirty))
  end

  @doc """
  Marks an entry in the session store represented by the key as dirty or not.
  """
  @spec toggle_dirty(map() | nil, atom()) :: map()
  def toggle_dirty(store, key, dirty \\ true)

  def toggle_dirty(nil, _key, _dirty), do: nil

  def toggle_dirty(store, key, dirty) when is_atom(key) do
    case Map.has_key?(store, key) do
      true ->
        updated_entry = %{store[key] | dirty: dirty}
        put_in(store, [key], updated_entry)

      false ->
        store
    end
  end

  @doc """
  Marks all entries in the session store as dirty.
  """
  @spec make_all_dirty(map()) :: map()
  def make_all_dirty(nil), do: %{}

  def make_all_dirty(store) do
    Enum.into(store, %{}, fn {key, value} -> {key, %{value | dirty: true}} end)
  end

  @doc """
  Removes all entries marked as dirty from the session store.
  """
  @spec clean(map()) :: map()
  def clean(nil), do: %{}

  def clean(store) do
    store
    |> Enum.filter(&is_clean?/1)
    |> Enum.into(%{})
  end

  # Checks if the given entry is dirty or not
  @spec is_clean?(tuple()) :: boolean()
  defp is_clean?({_key, %Envelope{dirty: dirty}}), do: !dirty
end
