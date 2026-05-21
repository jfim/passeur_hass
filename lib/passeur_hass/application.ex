defmodule PasseurHass.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: PasseurHass.Finch}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: PasseurHass.Supervisor)
  end
end
