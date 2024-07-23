defmodule ElixirDrops.AccountsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures

  alias ElixirDrops.Accounts
  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Accounts.UserToken

  @valid_attrs %{
    avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
    email: "some_email@gmail.com",
    github_username: "github_username",
    github_id: 1_456_872,
    name: "user"
  }
  @invalid_attrs %{
    avatar: nil,
    email: "my_emailgmail.com",
    github_username: nil,
    github_id: 0
  }

  defp create_user_and_token(_attrs) do
    user = user_fixture()
    token = Accounts.generate_user_session_token(user)
    %{user: user, token: token}
  end

  describe "users changeset & register" do
    test "changesets with valid attrs" do
      changeset1 = Accounts.change_user(%User{}, @valid_attrs)
      assert changeset1.valid?
    end

    test "changesets with invalid attrs" do
      changeset1 = Accounts.change_user(%User{}, @invalid_attrs)
      refute changeset1.valid?
    end

    test "validates github_id uniqueness" do
      _user = user_fixture()

      new_user = %{
        avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
        email: "new@gmail.com",
        github_id: 1_456_872,
        github_username: "new_username",
        name: "username"
      }

      {:error, changeset} = Accounts.register_user(new_user)
      assert "has already been taken" in errors_on(changeset).github_id
    end

    test "register_user/1 with valid data creates a user" do
      {:ok, %User{} = user} = Accounts.register_user(@valid_attrs)

      assert user.avatar == "https://avatars.githubusercontent.com/u/1456872?v=4"
      assert user.email == "some_email@gmail.com"
      assert user.github_username == "github_username"
      assert user.github_id == 1_456_872
    end

    test "register_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(@invalid_attrs)
    end
  end

  describe "generate_user_session_token/1" do
    setup [:create_user_and_token]

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
    end

    test "sets a github session token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
    end

    test "verify_session_token_query/1 gives some query", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert UserToken.verify_session_token_query(token)
    end

    test "build_session_token/1 returns github token", %{user: user} do
      {_token, %{token: token, context: context, user_id: user_id}} =
        UserToken.build_session_token(user)

      assert user_id == user.id
      assert context == "session"

      assert {:ok, _query} = UserToken.verify_session_token_query(token)
    end
  end

  describe "get_user_by_session_token/1" do
    setup [:create_user_and_token]

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "doesn't return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "doesn't return user when token in nil" do
      refute Accounts.get_user_by_session_token(nil)
    end

    test "doesn't return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_github_session_token/2" do
    setup [:create_user_and_token]

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "doesn't return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "doesn't return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete session tokens" do
    setup [:create_user_and_token]

    test "deletes the token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end

    test "deletes all tokens for the given user", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert Accounts.clear_all_tokens_for_user(user) == :ok
      assert Accounts.get_user_by_session_token(token) == nil
    end
  end

  describe "get users" do
    setup [:create_user_and_token]

    test "get_user!/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id) == user
    end

    test "get_user!/1 raises NoResultsError exception if user doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("14444444-edaa-444a-a333-7a77758ad305")
      end
    end

    test "get_user_by_github_id/1 returns the user with given github_username", %{user: user} do
      {:ok, ret_user} = Accounts.get_user_by_github_id(user.github_id)
      assert user == ret_user
    end

    test "get_user_by_github_id/1 returns error if user doesn't exist", %{user: _user} do
      {:error, reason} = Accounts.get_user_by_github_id(4444)
      assert reason == "User not found!"
    end

    test "get_or_create_user/1 creates new user with valid params" do
      {:ok, retur_user} =
        Accounts.get_or_create_user(%{
          avatar: "https://avatars.githubusercontent.com/u/12345678?v=4",
          email: "user@email.com",
          github_username: "gt_username",
          github_id: 12_345_678,
          name: "username"
        })

      assert retur_user.avatar == "https://avatars.githubusercontent.com/u/12345678?v=4"
      assert retur_user.email == "user@email.com"
      assert retur_user.github_username == "gt_username"
      assert retur_user.github_id == 12_345_678
    end

    test "get_or_create_user/1 returns user if user already exists", %{user: user1} do
      {:ok, user2} = Accounts.get_or_create_user(@valid_attrs)

      assert user1.email == user2.email
      assert user1.github_username == user2.github_username
      assert user1.github_id == user2.github_id
    end
  end

  describe "update users" do
    setup [:create_user_and_token]

    test "update_user/2 with valid data updates the user", %{user: user} do
      update_attrs = %{
        email: "some_updated_email@gmail.com",
        github_username: "updated_github_username"
      }

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.email == "some_updated_email@gmail.com"
      assert user.github_username == "updated_github_username"
    end

    test "update_user/2 with invalid data returns error changeset", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "change_user/1 returns a user changeset", %{user: user} do
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end
end
