defmodule EventsWeb.UserController do
  use EventsWeb, :controller

  plug EventsWeb.Plugs.RequireUser when action not in [:new, :create]

  require Logger

  # This was auto generated by phx.gen.html from Context
  #
  # Controller actions take 2 arguments: the conn struct, and params
  #
  # `render` is the core action of the controller which dictates
  # which template to serve. View modules correspond to controller naming
  # (i.e. EventsWeb.UserController -> EventsWeb.UserView)

  alias Events.Photos
  alias Events.Users
  alias Events.Users.User

  alias EventsWeb.{SessionController, Util.Formatting}

  def index(conn, _params) do
    users = Users.listRealUsers()
    render(conn, "index.html", users: users)
  end

  def new(conn, _params) do
    changeset = Users.change_user(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    upload = user_params["photo"]

    user_params =
      if upload do
        {:ok, hash} = Photos.savePhoto(upload.filename, upload.path)

        user_params
        |> Map.put("photo_hash", hash)
      else
        user_params
        |> Map.put("photo_hash", "default")
      end

    case Users.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:success, "Account created successfully")
        |> SessionController.create(%{"email" => user.email})

      # |> redirect(to: Routes.user_path(conn, :show, user))

      {:error, changeset} ->
        conn
        |> put_flash(:error, Formatting.humanizeChangesetErrors(changeset))
        |> render("new.html", changeset: changeset)
    end
  end

  # Since actions dispatch on when matched to a path at the route
  # *as long as you declare the route in the router*
  def photo(conn, %{"id" => id}) do
    hash = conn.assigns[:currentUser].photo_hash
    Logger.debug("USER CONTRROLLER PHOTO ---> #{inspect(hash)}")
    unless Enum.member?(["", "default"], hash) do
      {:ok, _metadata, data} = Photos.retrievePhoto(hash)
      conn # we can just retrieve the photo and send back down the wire
      |> put_resp_content_type("image/jpeg")
      |> send_resp(200, data)
    else
      # TODO send back default photo
      {:ok, data} = Photos.retrieveDefaultPhoto()
      conn 
      |> put_resp_content_type("image/jpeg")
      |> send_resp(200, data)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    render(conn, "show.html", user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    changeset = Users.change_user(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"user" => user_params} = params) do
    Logger.debug("USER CONTROLLER UPDATE ---> #{inspect(params)}")
    # this is a Plug.Upload Struct
    upload = user_params["photo"]

    user_params =
      if upload do
        {:ok, hash} = Photos.savePhoto(upload.filename, upload.path)

        user_params
        |> Map.put("photo_hash", hash)
      else
        user_params
      end

    user = Users.get_user!(conn.assigns[:currentUser].id)

    case Users.update_user(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:success, "User updated successfully")
        |> redirect(to: Routes.user_path(conn, :show, user))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    {:ok, _user} = Users.delete_user(user)

    conn
    |> put_flash(:info, "User deleted successfully")
    |> redirect(to: Routes.user_path(conn, :index))
  end
end
