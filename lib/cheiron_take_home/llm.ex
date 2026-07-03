defmodule CheironTakeHome.LLM do
  @moduledoc "Wrapper for OpenAI API. Interprets natural language queries into structured query plans."

  @url "https://api.openai.com/v1/chat/completions"

  def interpret(query) do
    http_client().request(
      url: @url,
      method: :post,
      headers: [
        {"authorization", "Bearer #{api_key()}"},
        {"content-type", "application/json"}
      ],
      body: Jason.encode!(%{
        model: "gpt-4o",
        response_format: %{type: "json_object"},
        messages: [
          %{role: "system", content: system_prompt()},
          %{role: "user", content: query}
        ]
      })
    )
    |> handle_response()
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    content =
      get_in(body, ["choices", Access.at(0), "message", "content"])
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    plan = Jason.decode!(content)

    {:ok, %{
      viz_type: plan["viz_type"],
      query_params: plan["query_params"],
      group_by: plan["group_by"],
      time_granularity: plan["time_granularity"],
      edge_type: plan["edge_type"]
    }}
  end

  defp handle_response({:error, reason}), do: {:error, reason}

  defp http_client, do: Application.get_env(:cheiron_take_home, :http_client)
  defp api_key, do: System.get_env("OPENAI_API_KEY")

  defp system_prompt do
    """
    You interpret natural language questions about clinical trials into structured query plans.
    Return JSON with: viz_type, query_params, group_by (optional), time_granularity (optional).

    viz_type MUST be exactly one of: "bar_chart", "time_series", or "network_graph". No other values are allowed.
    Choose "bar_chart" for comparisons, distributions, or categorical breakdowns.
    Choose "time_series" for trends over time or temporal patterns.
    Choose "network_graph" for questions about relationships between entities — e.g., which drugs treat which conditions, which sponsors fund which diseases, or what interventions are used for a condition.

    query_params is an object whose keys MUST come from this list only:
    - "query_cond": condition or disease (e.g., "lung cancer", "diabetes"). Use this for disease/condition searches.
    - "query_intr": intervention or treatment (e.g., "pembrolizumab", "radiation therapy")
    - "query_term": general search terms for anything not covered by the above
    - "filter_phase": trial phase filter (e.g., "PHASE1", "PHASE2", "PHASE3")
    - "filter_status": recruitment status filter (e.g., "RECRUITING", "COMPLETED")
    - "page_size": number of results to return (default 10, max 1000)
    You MUST include at least one of query_cond, query_intr, or query_term so the search is not empty.

    When viz_type is "bar_chart", group_by MUST be one of: "phase", "status". No other values are allowed.
    - "phase" groups trials by their clinical phase (e.g., PHASE1, PHASE2, PHASE3)
    - "status" groups trials by their recruitment status (e.g., RECRUITING, COMPLETED)
    Default to "phase" when the user's question does not clearly map to one of these fields.

    When viz_type is "network_graph", edge_type MUST be one of: "condition_to_intervention", "condition_to_sponsor". No other values are allowed.
    - "condition_to_intervention" links conditions/diseases to their treatments/drugs
    - "condition_to_sponsor" links conditions/diseases to their lead sponsors
    Default to "condition_to_intervention" when the user's question does not clearly map to one of these.
    """
  end
end
