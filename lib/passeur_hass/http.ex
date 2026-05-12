defmodule PasseurHass.HTTP do
  @moduledoc false

  @request_timeout_ms 15_000
  @user_agent "PasseurHass/0.1"

  @spec get_json(String.t(), [{String.t(), String.t()}]) ::
          {:ok, map() | list()} | {:error, String.t()}
  def get_json(path, query_params \\ []) do
    with {:ok, base} <- hass_base(),
         {:ok, token} <- hass_token() do
      url = build_url(base <> path, query_params)

      request =
        Finch.build(:get, url, [
          {"authorization", "Bearer " <> token},
          {"user-agent", @user_agent},
          {"accept", "application/json"}
        ])

      case Finch.request(request, PasseurHass.Finch, receive_timeout: @request_timeout_ms) do
        {:ok, %Finch.Response{status: 404}} ->
          {:error, :not_found}

        {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
          case Jason.decode(body) do
            {:ok, decoded} -> {:ok, decoded}
            {:error, _} -> {:error, "Home Assistant returned invalid JSON"}
          end

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, "Home Assistant returned HTTP #{status}#{body_snippet(body)}"}

        {:error, %Mint.TransportError{reason: :timeout}} ->
          {:error, "Request timed out"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  rescue
    e -> {:error, "Request raised #{inspect(e.__struct__)}: #{Exception.message(e)}"}
  end

  defp hass_base do
    case PasseurHass.Config.hass_url() do
      nil -> {:error, "HASS_URL environment variable is not set"}
      "" -> {:error, "HASS_URL environment variable is not set"}
      url -> {:ok, String.trim_trailing(url, "/")}
    end
  end

  defp hass_token do
    case PasseurHass.Config.hass_token() do
      nil -> {:error, "HASS_TOKEN environment variable is not set"}
      "" -> {:error, "HASS_TOKEN environment variable is not set"}
      token -> {:ok, token}
    end
  end

  defp body_snippet(body) when is_binary(body) do
    trimmed = body |> String.trim() |> String.slice(0, 200)
    if trimmed == "", do: "", else: ": #{trimmed}"
  end

  defp body_snippet(_), do: ""

  defp build_url(base, []), do: base
  defp build_url(base, params), do: base <> "?" <> URI.encode_query(params)
end
