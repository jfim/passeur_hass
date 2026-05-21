defmodule PasseurHass.Tools.HassListEntitiesByDomain do
  @moduledoc "List Home Assistant entities in a given domain (e.g. sensor, climate, light)"

  use Anubis.Server.Component, type: :tool
  require Logger

  @overall_timeout_ms 30_000

  schema do
    field(:domain, {:required, :string},
      description: "Domain prefix (e.g. \"sensor\", \"climate\", \"light\", \"binary_sensor\")"
    )
  end

  @impl true
  def execute(%{domain: domain} = _params, frame) do
    Logger.info("HASS list_entities_by_domain: #{domain}")

    task = Task.async(fn -> do_list(domain) end)

    response =
      case Task.yield(task, @overall_timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, {:ok, text}} ->
          Anubis.Server.Response.tool() |> Anubis.Server.Response.text(text)

        {:ok, {:error, reason}} ->
          Logger.warning("HASS list_entities_by_domain failed: #{reason}")
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(reason)

        {:exit, reason} ->
          msg = "HASS list_entities_by_domain crashed: #{inspect(reason)}"
          Logger.error(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)

        nil ->
          msg = "Operation timed out after #{@overall_timeout_ms}ms"
          Logger.warning(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)
      end

    {:reply, response, frame}
  end

  defp do_list(domain) do
    with {:ok, states} <- PasseurHass.HTTP.get_json("/api/states") do
      prefix = domain <> "."

      matches =
        states
        |> Enum.filter(fn s -> String.starts_with?(Map.get(s, "entity_id", ""), prefix) end)
        |> Enum.sort_by(fn s -> Map.get(s, "entity_id", "") end)

      {:ok, format_table(domain, matches)}
    else
      {:error, :not_found} -> {:error, "Home Assistant returned 404 for /api/states"}
      other -> other
    end
  rescue
    e -> {:error, "#{inspect(e.__struct__)}: #{Exception.message(e)}"}
  end

  defp format_table(domain, []), do: "_No entities in domain `#{domain}`._\n"

  defp format_table(domain, entities) do
    header = "# Entities in domain: #{domain}\n\n"
    table_header = "| entity_id | friendly_name | state | unit |\n|---|---|---|---|\n"
    rows = Enum.map_join(entities, "\n", &format_row/1)
    header <> table_header <> rows <> "\n"
  end

  defp format_row(%{} = s) do
    entity_id = Map.get(s, "entity_id", "")
    attrs = Map.get(s, "attributes") || %{}
    friendly = Map.get(attrs, "friendly_name", "") |> escape_cell()
    state = Map.get(s, "state", "") |> escape_cell()
    unit = Map.get(attrs, "unit_of_measurement", "") |> escape_cell()
    "| #{entity_id} | #{friendly} | #{state} | #{unit} |"
  end

  defp escape_cell(value) when is_binary(value), do: String.replace(value, "|", "\\|")
  defp escape_cell(value), do: value |> to_string() |> String.replace("|", "\\|")
end
