defmodule Briefcase.Envelope do
  @moduledoc false
  alias Briefcase.Envelope

  defstruct dirty: true, value: nil

  @type t :: %Envelope{dirty: boolean(), value: term()}

  @doc """
  Creates a new `%Briefcase.Envelope` struct with the given params.
  """
  @spec new(term(), boolean()) :: Envelope.t()
  def new(value, dirty \\ true) do
    %Envelope{dirty: dirty, value: value}
  end

  @doc """
  Transforms a keyword list into a list of `%Briefcase.Envelope`.
  """
  @spec from(keyword(), boolean()) :: Collectable.t()
  def from(keyword, dirty \\ true) when is_list(keyword) do
    Enum.into(keyword, %{}, fn {key, value} -> {key, Envelope.new(value, dirty)} end)
  end

end
