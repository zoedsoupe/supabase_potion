defmodule ArcaneWeb.Router do
  use ArcaneWeb, :router

  import ArcaneWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ArcaneWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ArcaneWeb do
    pipe_through :browser

    live "/", UserManagementLive

    scope "/session" do
      delete "/", SessionController, :signout
      post "/", SessionController, :create
      get "/confirm", SessionController, :confirm
    end
  end
end
