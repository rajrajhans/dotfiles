IEx.configure colors: [ eval_result: [:cyan,
:bright ]]

defmodule :_util do
  def cls(), do: clear()
  def ra(), do: recompile()
  defmacro tc(expression) do
    quote do
      {t, res} = :timer.tc(fn -> unquote(expression) end)
      {res, t / 1000_000}
    end
  end
end

import :_util
