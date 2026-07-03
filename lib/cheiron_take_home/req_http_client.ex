defmodule CheironTakeHome.ReqHttpClient do
  @moduledoc false
  @behaviour CheironTakeHome.HttpClient

  @impl true
  def request(opts) do
    case Req.request(opts) do
      {:ok, %Req.Response{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
