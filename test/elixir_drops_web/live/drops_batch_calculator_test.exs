defmodule ElixirDropsWeb.DropsBatchCalculatorTest do
  use ExUnit.Case, async: true

  alias ElixirDropsWeb.DropsBatchCalculator

  describe "calculate_batch_size/2" do
    test "returns minimum 6 items for very small viewports" do
      assert DropsBatchCalculator.calculate_batch_size(320, 400) == 6
    end

    test "returns correct batch size for mobile viewport" do
      # 1 column, ~2 rows visible
      assert DropsBatchCalculator.calculate_batch_size(375, 667) == 6
    end

    test "returns correct batch size for tablet viewport" do
      # 2 columns, (1024-200)/350 = 2 rows visible, (2*2) + 2 = 6
      assert DropsBatchCalculator.calculate_batch_size(768, 1024) == 6
    end

    test "returns correct batch size for desktop viewport (3 columns)" do
      # 3 columns, (900-200)/350 = 2 rows visible, (3*2) + 3 = 9
      assert DropsBatchCalculator.calculate_batch_size(1200, 900) == 9
    end

    test "returns correct batch size for large desktop viewport (4 columns)" do
      # 4 columns, (1080-200)/350 = 2 rows visible, (4*2) + 4 = 12
      assert DropsBatchCalculator.calculate_batch_size(1600, 1080) == 12
    end

    test "returns correct batch size for ultra-wide viewport (5 columns)" do
      # 5 columns, (1080-200)/350 = 2 rows visible, (5*2) + 5 = 15
      assert DropsBatchCalculator.calculate_batch_size(1920, 1080) == 15
    end

    test "respects maximum limit of 40 items" do
      # 5 columns, (2160-200)/350 = 5 rows visible, (5*5) + 5 = 30
      assert DropsBatchCalculator.calculate_batch_size(3840, 2160) == 30
    end

    test "handles edge case viewport sizes" do
      # Exactly at breakpoint
      assert DropsBatchCalculator.calculate_batch_size(480, 800) == 6
      assert DropsBatchCalculator.calculate_batch_size(768, 800) == 6
      assert DropsBatchCalculator.calculate_batch_size(1400, 800) == 9
      assert DropsBatchCalculator.calculate_batch_size(1800, 800) == 12

      # Just above breakpoint (481 = 2 columns, 769 = 3 columns, 1401 = 4 columns, 1801 = 5 columns)
      assert DropsBatchCalculator.calculate_batch_size(481, 800) == 6
      assert DropsBatchCalculator.calculate_batch_size(769, 800) == 9
      assert DropsBatchCalculator.calculate_batch_size(1401, 800) == 12
      assert DropsBatchCalculator.calculate_batch_size(1801, 800) == 15
    end
  end
end
