defmodule PgEx.Tests.Base do
  use ExUnit.CaseTemplate

  using do
    quote do
      import PgEx.Tests.Base
    end
  end

  def assert_error({:error, err}, message), do: assert_error(err, message)
  def assert_error(err = %PgEx.Error{}, message) do
    assert err.pg == nil
    assert err.code == nil
    assert err.message == message
  end

  def rand(n \\ 999_999), do: :rand.uniform(n)
  def rand(from, to) when from < 0 do
    case :rand.uniform(2) do
      1 -> :rand.uniform(to)
      2 -> :rand.uniform(from * -1) * -1
    end
  end
end
