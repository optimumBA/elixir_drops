alias ElixirDrops.Drops
alias ElixirDrops.Workers.ScreenshotGeneratorWorker

drops = Drops.list_drops(%{}, %{}, 10000)

check_for_code_block = fn body ->
  pattern = ~r/```(?:\w+\n)?(.+?)```/s

  case Regex.run(pattern, body, capture: :first) do
    nil -> false
    _ -> true
  end
end

drops
|> Stream.filter(&check_for_code_block.(&1.body))
|> Enum.each(fn drop ->
  %{drop_id: drop.id}
  |> ScreenshotGeneratorWorker.new()
  |> Oban.insert()
end)
