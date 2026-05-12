defmodule PasseurHass.Tools.HassSearchEntities do
  @moduledoc "Search Home Assistant entities by substring across entity_id and friendly_name"

  use Anubis.Server.Component, type: :tool
  require Logger

  @overall_timeout_ms 30_000
  @default_limit 50

  schema do
    field(:query, {:required, :string},
      description: "Case-insensitive substring matched against entity_id and friendly_name"
    )

    field(:limit, :integer, description: "Maximum results returned (default 50)")
  end

  @impl true
  def execute(%{query: query} = params, frame) do
    Logger.info("HASS search_entities: #{query}")

    limit = Map.get(params, :limit) || @default_limit

    task = Task.async(fn -> do_search(query, limit) end)

    response =
      case Task.yield(task, @overall_timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, {:ok, text}} ->
          Anubis.Server.Response.tool() |> Anubis.Server.Response.text(text)

        {:ok, {:error, reason}} ->
          Logger.warning("HASS search_entities failed: #{reason}")
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(reason)

        {:exit, reason} ->
          msg = "HASS search_entities crashed: #{inspect(reason)}"
          Logger.error(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)

        nil ->
          msg = "Operation timed out after #{@overall_timeout_ms}ms"
          Logger.warning(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)
      end

    {:reply, response, frame}
  end

  defp do_search(query, limit) do
    with {:ok, states} <- PasseurHass.HTTP.get_json("/api/states") do
      needle = String.downcase(query)

      matched =
        states
        |> Enum.filter(&matches?(&1, needle))
        |> Enum.sort_by(fn s -> Map.get(s, "entity_id", "") end)

      total = length(matched)
      shown = Enum.take(matched, limit)

      {:ok, format_table(query, shown, total, limit)}
    else
      {:error, :not_found} -> {:error, "Home Assistant returned 404 for /api/states"}
      other -> other
    end
  rescue
    e -> {:error, "#{inspect(e.__struct__)}: #{Exception.message(e)}"}
  end

  defp matches?(%{} = s, needle) do
    entity_id = Map.get(s, "entity_id", "") |> String.downcase()
    friendly = s |> Map.get("attributes", %{}) |> Map.get("friendly_name", "") |> to_string() |> String.downcase()
    String.contains?(entity_id, needle) or String.contains?(friendly, needle)
  end

  defp format_table(query, [], _total, _limit) do
    "# Search Results for: #{query}\n\n_No matching entities._\n"
  end

  defp format_table(query, entities, total, limit) do
    header = "# Search Results for: #{query}\n\n"
    table_header = "| entity_id | friendly_name | state | unit |\n|---|---|---|---|\n"
    rows = entities |> Enum.map(&format_row/1) |> Enum.join("\n")

    footer =
      if total > limit do
        "\n\n_… #{total - limit} more matches not shown. Narrow your query._\n"
      else
        "\n"
      end

    header <> table_header <> rows <> footer
  end

  defp format_row(%{} = s) do
    entity_id = Map.get(s, "entity_id", "")
    attrs = Map.get(s, "attributes", %{})
    friendly = Map.get(attrs, "friendly_name", "") |> escape_cell()
    state = Map.get(s, "state", "") |> escape_cell()
    unit = Map.get(attrs, "unit_of_measurement", "") |> escape_cell()
    "| #{entity_id} | #{friendly} | #{state} | #{unit} |"
  end

  defp escape_cell(value) when is_binary(value), do: String.replace(value, "|", "\\|")
  defp escape_cell(value), do: value |> to_string() |> String.replace("|", "\\|")
end
