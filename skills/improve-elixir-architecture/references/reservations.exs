# Run standalone: elixir /absolute/path/to/references/reservations.exs
#
# Before: each caller aggregates duplicate lines, validates quantities, checks
# every item, then subtracts stock. A caller that checks duplicate lines
# independently can oversubscribe an item; one that subtracts as it checks can
# accidentally accept only part of a request.
#
# After: one pure operation owns the all-or-nothing transition. Its private
# functions remain small. Callers and tests use the same reserve/2 interface.
#
# This demonstrates a functional boundary, NOT concurrent inventory control.
# A real application must separately own authoritative state and atomic writes
# through an appropriate database operation or process. Two callers using the
# same input map do not acquire an exclusive reservation by calling this function.

defmodule ArchitectureExample.Reservations do
  @moduledoc """
  Plans an all-or-nothing reservation from a trusted stock snapshot.

  Stock is a map of SKU strings to non-negative counts. Requests are a nonempty
  list of {SKU, positive quantity} pairs. Duplicate SKUs are combined. Unknown
  SKUs have zero availability. Failure produces no updated stock.
  """

  @type stock :: %{optional(String.t()) => non_neg_integer()}
  @type error :: :invalid_request | {:insufficient_stock, String.t()}

  @spec reserve(stock(), term()) :: {:ok, stock()} | {:error, error()}
  def reserve(stock, requests) when is_map(stock) do
    with {:ok, quantities} <- quantities(requests),
         :ok <- check_availability(stock, quantities) do
      updated =
        Enum.reduce(quantities, stock, fn {sku, count}, acc ->
          Map.update!(acc, sku, &(&1 - count))
        end)

      {:ok, updated}
    end
  end

  defp quantities([_ | _] = requests), do: quantities(requests, %{})
  defp quantities(_), do: {:error, :invalid_request}

  defp quantities([], acc), do: {:ok, acc}

  defp quantities([{sku, count} | rest], acc)
       when is_binary(sku) and byte_size(sku) > 0 and is_integer(count) and count > 0 do
    quantities(rest, Map.update(acc, sku, count, &(&1 + count)))
  end

  defp quantities(_, _), do: {:error, :invalid_request}

  defp check_availability(stock, quantities) do
    case Enum.find(quantities, fn {sku, count} -> count > Map.get(stock, sku, 0) end) do
      nil -> :ok
      {sku, _} -> {:error, {:insufficient_stock, sku}}
    end
  end
end

ExUnit.start()

defmodule ArchitectureExample.ReservationsTest do
  use ExUnit.Case, async: true
  alias ArchitectureExample.Reservations

  test "combines duplicate lines before reserving and preserves unrelated stock" do
    stock = %{"chair" => 5, "desk" => 2}

    assert {:ok, %{"chair" => 0, "desk" => 2}} =
             Reservations.reserve(stock, [{"chair", 2}, {"chair", 3}])
  end

  test "duplicate lines cannot individually pass a stock check and oversubscribe" do
    assert {:error, {:insufficient_stock, "chair"}} =
             Reservations.reserve(%{"chair" => 4}, [{"chair", 2}, {"chair", 3}])
  end

  test "one unavailable item rejects the entire request" do
    stock = %{"chair" => 5, "desk" => 1}

    assert {:error, {:insufficient_stock, "desk"}} =
             Reservations.reserve(stock, [{"chair", 2}, {"desk", 2}])
  end

  test "unknown stock is unavailable" do
    assert {:error, {:insufficient_stock, "lamp"}} =
             Reservations.reserve(%{}, [{"lamp", 1}])
  end

  test "rejects requests that do not meet the input contract" do
    for request <- [
          [],
          nil,
          [{"chair", 0}],
          [{"chair", -1}],
          [{"chair", 1.5}],
          [{"chair", "2"}],
          [{"", 1}],
          [:chair],
          [{"chair", 1} | :bad_tail]
        ] do
      assert {:error, :invalid_request} =
               Reservations.reserve(%{"chair" => 5}, request)
    end
  end
end
