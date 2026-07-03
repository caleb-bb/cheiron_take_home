# Claude Code Prompt: Patch Munger Tests with Shape and Coherence Assertions

## Context
The file `test/cheiron_take_home/munger_test.exs` already exists with property-based tests covering traceability (phantom count prevention, phase/period membership). The tests currently fail because `CheironTakeHome.Munger.build/2` does not exist. This is intentional — the tests define the contract.

The tests are missing structural validation: encoding-data coherence, encoding channel completeness, type-specific shape invariants. This prompt adds those without changing existing tests.

## Task: Add private assertion helpers and call them from the existing property tests.

### Step 0: Assess
Read `test/cheiron_take_home/munger_test.exs` in full. Confirm you understand the existing tests and what you're adding. List your steps. Do not begin until you've confirmed.

### Step 1: Add private assertion helpers AFTER the generators, BEFORE the describe blocks

Add these private functions between the `studies_gen` generator and the first `describe` block:

```elixir
  # --- Shape Assertion Helpers ---

  # Universal: every viz spec must have these keys with these types
  defp assert_viz_spec_shape(viz_spec) do
    assert is_binary(viz_spec.type) and viz_spec.type != ""
    assert is_binary(viz_spec.title) and viz_spec.title != ""
    assert is_map(viz_spec.encoding)
    assert is_list(viz_spec.data) and length(viz_spec.data) > 0
    assert is_map(viz_spec.meta)
  end

  # Every field declared in encoding must appear as a key in every data point
  defp assert_encoding_data_coherence(viz_spec) do
    encoding_fields =
      viz_spec.encoding
      |> Map.values()
      |> Enum.map(& &1.field)
      |> MapSet.new()

    Enum.each(viz_spec.data, fn data_point ->
      data_keys = data_point |> Map.keys() |> MapSet.new()

      assert MapSet.subset?(encoding_fields, data_keys),
             "Data point missing fields declared in encoding: #{inspect(MapSet.difference(encoding_fields, data_keys))}"
    end)
  end

  # Each encoding channel must have field, label, and type
  defp assert_encoding_channels(viz_spec) do
    Enum.each(viz_spec.encoding, fn {_channel, channel_spec} ->
      assert is_binary(channel_spec.field), "Encoding channel missing :field"
      assert is_binary(channel_spec.label), "Encoding channel missing :label"
      assert channel_spec.type in ["categorical", "quantitative", "temporal"],
             "Encoding channel :type must be categorical, quantitative, or temporal — got #{inspect(channel_spec.type)}"
    end)
  end

  # Bar chart: x is categorical, y is quantitative, sort key exists, y values are non-negative integers
  defp assert_bar_chart_shape(viz_spec) do
    assert viz_spec.encoding.x.type == "categorical"
    assert viz_spec.encoding.y.type == "quantitative"
    assert Map.has_key?(viz_spec, :sort), "Bar chart spec missing :sort key"

    y_field = viz_spec.encoding.y.field

    Enum.each(viz_spec.data, fn point ->
      val = point[y_field]
      assert is_integer(val) and val >= 0,
             "Bar chart y-axis value must be a non-negative integer, got: #{inspect(val)}"
    end)
  end

  # Time series: x is temporal with granularity, y is quantitative, y values non-negative integers
  defp assert_time_series_shape(viz_spec) do
    assert viz_spec.encoding.x.type == "temporal"

    assert Map.has_key?(viz_spec.encoding.x, :granularity),
           "Time series x-axis encoding missing :granularity"

    assert viz_spec.encoding.x.granularity in ["year", "month", "quarter"],
           "Time series granularity must be year, month, or quarter — got #{inspect(viz_spec.encoding.x.granularity)}"

    assert viz_spec.encoding.y.type == "quantitative"

    y_field = viz_spec.encoding.y.field

    Enum.each(viz_spec.data, fn point ->
      val = point[y_field]
      assert is_integer(val) and val >= 0,
             "Time series y-axis value must be a non-negative integer, got: #{inspect(val)}"
    end)
  end
```

### Step 2: Replace the "output has required viz_spec keys" test in the bar chart describe block

Find this test inside `describe "build/2 with bar_chart viz_type grouped by phase"`:

```elixir
    property "output has required viz_spec keys" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert is_binary(viz_spec.type)
        assert is_binary(viz_spec.title)
        assert is_map(viz_spec.encoding)
        assert is_list(viz_spec.data)
      end
    end
```

Replace it with:

```elixir
    property "output has valid shape, encoding channels, encoding-data coherence, and bar chart structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :bar_chart, group_by: "phase"}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_bar_chart_shape(viz_spec)
      end
    end
```

### Step 3: Replace the "output has required viz_spec keys" test in the time series describe block

Find this test inside `describe "build/2 with time_series viz_type"`:

```elixir
    property "output has required viz_spec keys" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert is_binary(viz_spec.type)
        assert is_binary(viz_spec.title)
        assert is_map(viz_spec.encoding)
        assert is_list(viz_spec.data)
      end
    end
```

Replace it with:

```elixir
    property "output has valid shape, encoding channels, encoding-data coherence, and time series structure" do
      check all(studies <- studies_gen()) do
        viz_intent = %{viz_type: :time_series, time_granularity: :year}
        {:ok, viz_spec} = CheironTakeHome.Munger.build(studies, viz_intent)

        assert_viz_spec_shape(viz_spec)
        assert_encoding_channels(viz_spec)
        assert_encoding_data_coherence(viz_spec)
        assert_time_series_shape(viz_spec)
      end
    end
```

### Step 4: Do NOT touch any other existing tests
The traceability properties (phantom counts, phase membership, time bucket membership, chronological sort) remain exactly as they are. Do not modify them.

### Step 5: Verify tests still FAIL
Run `mix test test/cheiron_take_home/munger_test.exs`. All tests must still fail because `Munger.build/2` does not exist. If any test passes, report it.

### Step 6: Stage only
```bash
git add -A
```

Do NOT commit.

### HARD STOP
Do NOT implement `Munger.build/2`. Do NOT modify the Munger module. Report what you did, including the test failure output, and stop.

