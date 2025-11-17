alias ElixirDrops.Accounts
alias ElixirDrops.Drops.Drop
alias ElixirDrops.Drops

user = Accounts.get_user!("04b0a689-9482-4e78-9454-1a2d8dd2ca11")
list = 1..18

screenshot = %{
  status: "completed",
  meta_url:
    "https://fly.storage.tigris.dev/wandering-firefly-1822/drop-meta-image-latest-14a99118-9071-466c-b96b-71ac08cf7264.png",
  internal_url:
    "https://fly.storage.tigris.dev/wandering-firefly-1822/drop-internal-image-latest-14a99118-9071-466c-b96b-71ac08cf7264.png"
}

Enum.each(list, fn item ->
  Drops.create_drop(%Drop{}, user, %{
    title: "Handling Mux #{item} Video Uploads in #{item}, in LiveView",
    body: "Registering the LiveView process #{item} the responsible LiveView",
    screenshot: screenshot
  })
end)
