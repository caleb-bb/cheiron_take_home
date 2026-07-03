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
      time_granularity: plan["time_granularity"]
    }}
  end

  defp handle_response({:error, reason}), do: {:error, reason}

  defp http_client, do: Application.get_env(:cheiron_take_home, :http_client)
  defp api_key, do: System.get_env("OPENAI_API_KEY")

  defp system_prompt do
    "You interpret natural language questions about clinical trials into structured query plans. " <>
      "Return JSON with: viz_type, query_params, group_by (optional), time_granularity (optional)."
  end
end
