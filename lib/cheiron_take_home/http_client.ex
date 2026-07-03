defmodule CheironTakeHome.HttpClient do
  @moduledoc "Behaviour for HTTP calls. Exists solely so Mox can mock it."

  @callback request(keyword()) :: {:ok, map()} | {:error, term()}
end
