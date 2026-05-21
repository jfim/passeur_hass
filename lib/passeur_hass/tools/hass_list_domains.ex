defmodule PasseurHass.Tools.HassListDomains do
  @moduledoc "List all entity domains present in this Home Assistant install, with entity counts"

  use Anubis.Server.Component, type: :tool
  require Logger

  @overall_timeout_ms 30_000

  schema do
  end

  @impl true
  def execute(_params, frame) do
    Logger.info("HASS list_domains")

    task = Task.async(fn -> do_list() end)

    response =
      case Task.yield(task, @overall_timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, {:ok, text}} ->
          Anubis.Server.Response.tool() |> Anubis.Server.Response.text(text)

        {:ok, {:error, reason}} ->
          Logger.warning("HASS list_domains failed: #{reason}")
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(reason)

        {:exit, reason} ->
          msg = "HASS list_domains crashed: #{inspect(reason)}"
          Logger.error(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)

        nil ->
          msg = "Operation timed out after #{@overall_timeout_ms}ms"
          Logger.warning(msg)
          Anubis.Server.Response.tool() |> Anubis.Server.Response.error(msg)
      end

    {:reply, response, frame}
  end

  defp do_list do
    case PasseurHass.HTTP.get_json("/api/states") do
      {:ok, states} ->
        counts =
          Enum.reduce(states, %{}, fn s, acc ->
            case Map.get(s, "entity_id", "") |> String.split(".", parts: 2) do
              [domain, _] -> Map.update(acc, domain, 1, &(&1 + 1))
              _ -> acc
            end
          end)

        {:ok, format_table(counts)}

      {:error, :not_found} ->
        {:error, "Home Assistant returned 404 for /api/states"}

      other ->
        other
    end
  rescue
    e -> {:error, "#{inspect(e.__struct__)}: #{Exception.message(e)}"}
  end

  defp format_table(counts) when map_size(counts) == 0 do
    "# Domains (0)\n\n_No entities reported._\n"
  end

  defp format_table(counts) do
    sorted = counts |> Enum.sort_by(fn {_d, c} -> -c end)
    header = "# Domains (#{map_size(counts)})\n\n"
    table_header = "| domain | count |\n|---|---|\n"
    rows = Enum.map_join(sorted, "\n", fn {d, c} -> "| #{d} | #{c} |" end)
    header <> table_header <> rows <> "\n"
  end
end
