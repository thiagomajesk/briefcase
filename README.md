# Briefcase

Briefcase is a simple plug for transporting temporary data through requests. You can read more about the motivation behind Briefcase in [this thread](https://elixirforum.com/t/is-prg-a-valid-technique-in-phoenix/27249/24).

**Important Note:** This is code is still highly experimental

## Setup

Since the package is not published on hex, the only way you can use it right now is by referencing the repository directly in in your `mix.exs` file:

```elixir
defp deps do
  [
    {:briefcase, github: "thiagomajesk/briefcase"}
  ]
end
```

You can also import Briefcase in your `"project_web.ex"` file to make life a little bit easier when using it:

```elixir
def controller do
  quote do
    use Phoenix.Controller, namespace: ProjectWeb

    import Plug.Conn
    import ProjectWeb.Gettext
    import Briefcase, only: [pack: 2, unpack: 3, peek: 3]
    alias ProjectWeb.Router.Helpers, as: Routes
  end
end
```

You should also, enable the plug globally in the browser pipeline in your `router.ex` file:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_flash
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug Briefcase
end
```

> Since this plug relies heavily on the session, the recommended way of configuring it is globally. That way you won't have to worry about having artifacts living on the session for more time than they are supposed to.

## Examples

### Implementing the PRG (Post Redirect Get) pattern in Phoenix

You can use Briefcase to implement the [PRG](https://en.wikipedia.org/wiki/Post/Redirect/Get) pattern in your Phoenix controllers:


```elixir
def new(conn, _params) do
  # You can pass a default param to unpack/3 that will be used as a fallback
  # (Notice that the modified %Plug.Conn{} struct is also returned)
  {conn, changeset} = unpack(conn, :validation_errors, Context.change_resource(%Resource{}))
  render(conn, "new.html", changeset: changeset)
end

def create(conn, %{"resource" => resource_params}) do
  case Context.create_resource(resource_params) do
    {:ok, resource} ->
      conn
      |> put_flash(:info, "Resource created successfully.")
      |> redirect(to: Routes.resource_path(conn, :show, resource))

    {:error, %Ecto.Changeset{} = changeset} ->
      conn
      |> pack([validation_errors: changeset])
      |> redirect(to: Routes.resource_path(conn, :new))
  end
end
```

## How it works

Briefcase works by saving data temporarily in the session and watching if it has been consumed. After you consume the stored content with `unpack/3`, it will be marked for deletion. This will typically happen after your controller yields a response.   
The content stored by Briefcase is meant to be short-lived, this means that on the beginning of each request, any content that was not already marked as "dirty" will be, unless you use `peek/2` to consume its contents and remove the "dirty state". 

The life-cycle is shortly explained bellow:

```elixir
# Recycling¹
def first_action(conn, _params) do
  conn
    |> pack([first: value]) # Packs the content (not dirty)
    |> redirect(to: Routes.resource_path(conn, :second_action))
    # Cleanup²
end

# Recycling¹
def first_action(conn, _params) do
  # Retrieves the stored content without making it "dirty".
  # Since the "first" key was marked dirty in the beginning of this request, 
  # using peek/2 will prevent its deletion at the end of this request
  {conn, _value} = peek(conn, :first) # not "dirty" anymore
 
  conn
    |> pack([second: value]) # pack new content (not dirty)
    |> redirect(to: Routes.resource_path(conn, :third_action))
    # Cleanup²
end

# Recycling¹
def second_action(conn, _params) do

  {conn, _first_value} = unpack(conn, :first) # makes "first" dirty
  {conn, _second_value} = unpack(conn, :second) # makes "second" dirty

  redirect(conn, to: Routes.resource_path(conn, :index))
  # Cleanup² (the contents of "first" and "second" will be removed here)
end
```

> ¹**Recycling**: Any content not already marked as dirty becomes dirty before this request is processed  

> ²**Cleanup**: After the response, deletes any content that was previously marked as "dirty" 