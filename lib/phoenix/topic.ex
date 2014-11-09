defmodule Phoenix.Topic do
  use GenServer
  alias Phoenix.Topic.Server

  @moduledoc """
  Serves as a Notification and PubSub layer for broad use-cases. Used internally
  by Channels for pubsub broadcast.

  ## Example

      iex> Topic.subscribe(self, "user:123")
      :ok
      iex> Process.info(self)[:messages]
      []
      iex> Topic.subscribers("user:123")
      [#PID<0.169.0>]
      iex> Topic.broadcast "user:123", {:user_update, %{id: 123, name: "Shane"}}
      :ok
      iex> Process.info(self)[:messages]
      {:user_update, %{id: 123, name: "Shane"}}

  """


  @server Phoenix.Topic.Server

  @pg_prefix :phx

  @doc """
  Creates a `Phoenix.Topic` for pubsub broadcast to subscribers

    * name - The String name of the topic

  ## Examples

      iex> Topic.create("mytopic")
      :ok

  """
  def create(name) do
    :ok = call {:create, group(name)}
  end

  @doc """
  Checks if a given `Phoenix.Topic` is registered as a process group
  """
  def exists?(name) do
    call {:exists?, group(name)}
  end

  @doc """
  Removes `Phoenix.Topic` from process group if inactive

  ## Examples

      iex> Topic.delete("mytopic")
      :ok
      iex> Topic.delete("activetopic")
      {:error, :active}

  """
  def delete(name) do
    call {:delete, group(name)}
  end

  @doc """
  Adds subsriber pid to given `Phoenix.Topic` process group

  ## Examples

      iex> Topic.subscribe(self, "mytopic")

  """
  def subscribe(pid, name) do
    :ok = create(name)
    call {:subscribe, pid, group(name)}
  end

  @doc """
  Removes subscriber pid from given `Phoenix.Topic` process group

  ## Examples

      iex> Topic.unsubscribe(self, "mytopic")

  """
  def unsubscribe(pid, name) do
    call {:unsubscribe, pid, group(name)}
  end

  @doc """
  Returns the List of subsriber pids of given `Phoenix.Topic` process group

  ## Examples

      iex> Topic.subscribers("mytopic")
      []
      iex> Topic.subscribe(self, "mytopic")
      :ok
      iex> Topic.subscribers("mytopic")
      [#PID<0.41.0>]

  """
  def subscribers(name) do
    case :pg2.get_members(group(name)) do
      {:error, {:no_such_group, _}} -> []
      members -> members
    end
  end

  @doc """
  Broadcasts a message to the given `Phoenix.Topic` process group subscribers

  ## Examples

      iex> Topic.broadcast("mytopic", :hello)

  To exclude the broadcaster from receiving the message, use `broadcast_from/3`
  """
  def broadcast(name, message) do
    broadcast_from(:global, name, message)
  end

  @doc """
  Broadcasts a message to the given `Phoenix.Topic` process group subscribers,
  excluding broadcaster from receiving the message it sent out

  ## Examples

      iex> Topic.broadcast_from(self, "mytopic", :hello)

  """
  def broadcast_from(from_pid, name, message) do
    name
    |> subscribers
    |> Enum.each fn
      pid when pid != from_pid -> send(pid, message)
      _pid ->
    end
  end

  @doc """
  Check if `Phoenix.Topic` is active. To be active it must be created and have subscribers
  """
  def active?(name) do
    call {:active?, group(name)}
  end

  @doc """
  Returns a List of all Phoenix Topics from `:pg2`
  """
  def list do
    :pg2.which_groups |> Enum.filter(&match?({@pg_prefix, _}, &1))
  end

  defp call(message), do: GenServer.call(Server.leader_pid, message)

  defp group(name), do: {@pg_prefix, name}
end

