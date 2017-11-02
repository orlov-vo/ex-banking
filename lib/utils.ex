defmodule Utils do
  @moduledoc """
  The module contains helper functions and macros
  """

  @doc """
  Check the `value`. If it contains an error returns true
  """
  @spec is_error(value :: any) :: boolean
  defmacro is_error(value) do
    quote do
      (is_atom(unquote(value)) and unquote(value) == :error)
      or (is_tuple(unquote(value)) and elem(unquote(value), 0) == :error)
    end
  end
end
