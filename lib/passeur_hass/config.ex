defmodule PasseurHass.Config do
  @moduledoc "Runtime configuration read from environment variables."

  @url_env "HASS_URL"
  @token_env "HASS_TOKEN"

  @spec hass_url() :: String.t() | nil
  def hass_url, do: System.get_env(@url_env)

  @spec hass_token() :: String.t() | nil
  def hass_token, do: System.get_env(@token_env)
end
