defmodule CheironTakeHome.ClinicalTrials do
  @moduledoc "Wrapper for the ClinicalTrials.gov v2 API."

  @url "https://clinicaltrials.gov/api/v2/studies"

  def search(params) do
    http_client().request(
      url: @url,
      method: :get,
      params: build_params(params)
    )
    |> handle_response()
  end

  defp build_params(params) do
    %{"format" => "json"}
    |> maybe_put("query.cond", params[:query_cond])
    |> maybe_put("query.intr", params[:query_intr])
    |> maybe_put("query.term", params[:query_term])
    |> maybe_put("pageSize", params[:page_size])
    |> maybe_put("filter.phase", params[:filter_phase])
    |> maybe_put("filter.overallStatus", params[:filter_status])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp handle_response({:ok, %{status: 200, body: body}}), do: {:ok, body["studies"]}
  defp handle_response({:error, reason}), do: {:error, reason}

  defp http_client, do: Application.get_env(:cheiron_take_home, :http_client)
end
