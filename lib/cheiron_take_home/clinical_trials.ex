defmodule CheironTakeHome.ClinicalTrials do
  @moduledoc "Wrapper for the ClinicalTrials.gov v2 API."

  @url "https://clinicaltrials.gov/api/v2/studies"

  @max_pages 5

  def search(params), do: fetch_pages(build_params(params), [], @max_pages)

  defp fetch_pages(_params, acc, 0), do: {:ok, Enum.reverse(acc)}

  defp fetch_pages(params, acc, remaining) do
    case do_request(params) do
      {:ok, studies, next_token} ->
        new_acc = Enum.reverse(studies) ++ acc

        case next_token do
          nil -> {:ok, Enum.reverse(new_acc)}
          token -> fetch_pages(Map.put(params, "pageToken", token), new_acc, remaining - 1)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_request(params) do
    http_client().request(
      url: @url,
      method: :get,
      params: params
    )
    |> handle_response()
  end

  defp build_params(params) do
    %{"format" => "json"}
    |> maybe_put("query.cond", params[:query_cond])
    |> maybe_put("query.intr", params[:query_intr])
    |> maybe_put("query.term", params[:query_term])
    |> maybe_put("pageSize", params[:page_size])
    |> maybe_put_filter_advanced(params)
    |> maybe_put("filter.overallStatus", params[:filter_status])
  end

  defp maybe_put_filter_advanced(query_params, params) do
    case params[:filter_phase] do
      nil -> query_params
      phase -> Map.put(query_params, "filter.advanced", "AREA[Phase]#{phase}")
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp handle_response({:ok, %{status: 200, body: body}}) when is_map(body),
    do: {:ok, body["studies"] || [], body["nextPageToken"]}

  defp handle_response({:ok, %{status: 200, body: body}}),
    do: {:error, %{reason: "API returned 200 but body is not a map: #{inspect(body)}"}}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, %{reason: "API returned #{status}: #{inspect(body)}"}}

  defp handle_response({:error, reason}), do: {:error, reason}

  defp http_client, do: Application.get_env(:cheiron_take_home, :http_client)
end
