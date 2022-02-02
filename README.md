# Briefcase

Briefcase is a simple plug for transporting temporary data through requests. You can read more about the motivation behind Briefcase in [this thread](https://elixirforum.com/t/is-prg-a-valid-technique-in-phoenix/27249/24).

**Important Note:** This is code is still highly experimental

## Use case

Imagine the following scenario: You are building your own blog which has posts and comments. A common implementation could be having RESTfull resources like so:

```elixir
resource "/posts", PostController do
  resource /comments", CommentController
end
```

Now, let's imagine that you want to see all recent comments when you access a post:

```elixir
def show(conn, %{"post_id" => post_id}) do
 comments = Posts.recent_comments(post_id)
 render(conn, "show.html", comments: comments)
end
```

So far so good... After you create a post, you can access it and see a list of recent comments. Now, we want to add a commment box so users can comment on those posts: 

```elixir
def show(conn, %{"post_id" => post_id}) do
 comments = Posts.recent_comments(post_id)
 comment_changeset = Posts.change_comment()
 render(conn, "show.html", comments: comments, comment_changeset: comment_changeset)
end
```

For the sake of the example, let's say we want to limit the comments to no more than 300 caracteres. After those validations are in place, we'll have something like this:

```elixir
def create(conn, %{"post_id" => post_id, "commment" => comment_params}) do
  post = Posts.get_post!(post_id)
  case Posts.create_comment(post, comment_params) do
    {:ok, comment} -> redirect(to: Routes.post_path(conn, :show, post)
    {:error, %Ecto.Changeset{} = changeset} -> redirect(to: Routes.post_path(conn, :show, post)
  end
end
``` 

Now notice that, because we have a separate resource to create comments, we want to return back to the post page to see that our comment was properly created. However, what happens if a user tries to create a invalid comment? If that the case, we should be able to show a helpfull message so the user can fix what's wrong and try again. 
One way of doing that is to re-render the post page again, passing the recent comments and every other assign that its necessary to render that page again. Although _there are various ways of doing that¹_, what if we delegate the rendering responsability only to the `show` action of `PostController`? We do that by redirecting the user to the action which knows what is required for that page to properly function. Ok, but now that we are redirecting the user back to the post page, we won't be able to return the validated changeset which contains helpfull error message to our user, and that's where the PRG pattern commes to the rescue.

> ¹ A common alternative is to abstract the code into a separate, helper function that can be called from both controllers and helps compose the assigns necessary to render the page. However, this might not be the best option for some use cases.

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

## TODOs

- [ ] Add option to save session store to database instead of cookie
