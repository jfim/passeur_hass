# Passeur HASS

Read-only MCP tools for [Passeur](https://github.com/jfim/passeur) that expose Home Assistant entity state via the [REST API](https://developers.home-assistant.io/docs/api/rest/).

## Tools

| Tool | Description |
|------|-------------|
| `hass_list_entities_by_domain` | List entities in a given domain (e.g. `sensor`, `climate`, `light`) |
| `hass_search_entities` | Substring search across `entity_id` and `friendly_name` |
| `hass_get_entity_state` | Get the full state and attributes of a single entity |
| `hass_list_domains` | List entity domains present in the install, with counts |

All tools are read-only. There is no `call_service` and no actuation.

## Configuration

| Env var | Description |
|---------|-------------|
| `HASS_URL` | Base URL of the Home Assistant instance (e.g. `http://homeassistant.local:8123`) |
| `HASS_TOKEN` | Long-lived access token (Profile → Security → Long-Lived Access Tokens) |

## Usage

Add to your MCP server project:

```elixir
# mix.exs
{:passeur_hass, git: "https://github.com/jfim/passeur_hass.git"}
```

Register the tools in your MCP server:

```elixir
defmodule MyServer.MCPServer do
  use Anubis.Server,
    name: "MyServer",
    version: "0.1.0",
    capabilities: [:tools]

  component PasseurHass.Tools.HassListEntitiesByDomain
  component PasseurHass.Tools.HassSearchEntities
  component PasseurHass.Tools.HassGetEntityState
  component PasseurHass.Tools.HassListDomains

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
```

## License

MIT
