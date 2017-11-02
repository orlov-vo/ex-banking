defmodule EtsUtils do
  @doc """
  Create a new table if it isn't exists
  """
  @spec create_table_if_not_exists(table :: atom) :: :ok
  def create_table_if_not_exists(table, type \\ :ordered_set) when is_atom(table) do
    if :ets.info(table) == :undefined do
      :ets.new(table, [type, :public, :named_table])
    end
    :ok
  end
end
