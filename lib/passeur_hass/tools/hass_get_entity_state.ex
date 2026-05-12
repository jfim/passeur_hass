defmodule PasseurHass.Tools.HassGetEntityState do
  @moduledoc "Get the full state and attributes of a single Home Assistant entity"

  use Anubis.Server.Component, type: :tool
  require Logger

  @overall_timeout_ms 30_000

  schema do
    field(:entity_id, {:required, :string},
      description: "Entity ID, e.g. \"sensor.outside_aqi\""
    )
  end

  @impl true
  def execute(%{entity_id: entity_id} = _params, frame) do
    Logger.info("HASS get_entity_state: #{entity_id}")

    task = Task.async(fn -> do_get(entity_id) end)

    response =
      case Task.yield(task, @overall_timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, {:ok, text}} ->
          Anubis.Server.Response.tool() |> Anubis.Server.Response.text(text)

        {:ok, {:error, reason}} ->
          Logger.warning("HASS get_entity_state failed: #{reason}")
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(reason)

        {:exit, reason} ->
          msg = "HASS get_entity_state crashed: #{inspect(reason)}"
          Logger.error(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)

        nil ->
          msg = "Operation timed out after #{@overall_timeout_ms}ms"
          Logger.warning(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)
      end

    {:reply, response, frame}
  end

  defp do_get(entity_id) do
    path = "/api/states/" <> URI.encode(entity_id)

    case PasseurHass.HTTP.get_json(path) do
      {:ok, state} -> {:ok, format_state(state)}
      {:error, :not_found} -> {:error, "Entity not found: #{entity_id}"}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "#{inspect(e.__struct__)}: #{Exception.message(e)}"}
  end

  defp format_state(%{} = state) do
    entity_id = Map.get(state, "entity_id", "(unknown)")
    state_value = Map.get(state, "state", "")
    last_changed = Map.get(state, "last_changed", "")
    last_updated = Map.get(state, "last_updated", "")
    attrs = Map.get(state, "attributes", %{})

    header = "# #{entity_id}\n\n"

    meta = """
    - **state**: #{format_value(state_value)}
    - **last_changed**: #{last_changed}
    - **last_updated**: #{last_updated}
    """

    attrs_section =
      case map_size(attrs) do
        0 ->
          "\n## Attributes\n\n_(none)_\n"

        _ ->
          rows =
            attrs
            |> Enum.sort_by(fn {k, _} -> k end)
            |> Enum.map(fn {k, v} -> "- **#{k}**: #{format_value(v)}" end)
            |> Enum.join("\n")

          "\n## Attributes\n\n" <> rows <> "\n"
      end

    header <> meta <> attrs_section
  end

  defp format_value(v) when is_binary(v), do: v
  defp format_value(v) when is_number(v) or is_boolean(v) or is_atom(v), do: to_string(v)
  defp format_value(v), do: Jason.encode!(v)
end
