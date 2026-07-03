# Queries and outputs (AI generated)

## Lung cancer trials by phase

```elixir
CheironTakeHome.Orchestrator.query("How many lung cancer trials are in each phase?")
```

```json
{
  "data": [
    {"phase": "NA", "trial_count": 4},
    {"phase": "PHASE2", "trial_count": 3},
    {"phase": "PHASE3", "trial_count": 1}
  ],
  "meta": {"source": "clinicaltrials.gov", "total_studies": 10},
  "type": "bar_chart",
  "sort": {"field": "phase", "order": "descending"},
  "encoding": {
    "x": {"label": "Phase", "type": "categorical", "field": "phase"},
    "y": {"label": "Number of Trials", "type": "quantitative", "field": "trial_count"}
  },
  "title": "Lung Cancer Clinical Trials by Phase"
}
```

## Alzheimer's disease trials by recruitment status

```elixir
CheironTakeHome.Orchestrator.query("What's the recruitment status of Alzheimer's disease trials?")
```

```json
{
  "data": [
    {"status": "COMPLETED", "trial_count": 7},
    {"status": "RECRUITING", "trial_count": 3}
  ],
  "meta": {"source": "clinicaltrials.gov", "total_studies": 10},
  "type": "bar_chart",
  "sort": {"field": "status", "order": "descending"},
  "encoding": {
    "x": {"label": "Status", "type": "categorical", "field": "status"},
    "y": {"label": "Number of Trials", "type": "quantitative", "field": "trial_count"}
  },
  "title": "Alzheimer's Disease Clinical Trials by Status"
}
```

## Breast cancer trial activity over time

```elixir
CheironTakeHome.Orchestrator.query("How has clinical trial activity for breast cancer changed over time?")
```

```json
{
  "data": [
    {"count": 1, "period": "1987"},
    {"count": 1, "period": "1994"},
    {"count": 1, "period": "1996"},
    {"count": 2, "period": "1997"},
    {"count": 2, "period": "1999"},
    {"count": 2, "period": "2000"},
    {"count": 1, "period": "2001"},
    {"count": 2, "period": "2002"},
    {"count": 1, "period": "2003"},
    {"count": 1, "period": "2004"},
    {"count": 4, "period": "2005"},
    {"count": 2, "period": "2006"},
    {"count": 3, "period": "2009"},
    {"count": 2, "period": "2010"},
    {"count": 3, "period": "2011"},
    {"count": 4, "period": "2012"},
    {"count": 4, "period": "2013"},
    {"count": 2, "period": "2014"},
    {"count": 6, "period": "2015"},
    {"count": 10, "period": "2016"},
    {"count": 6, "period": "2017"},
    {"count": 4, "period": "2018"},
    {"count": 4, "period": "2019"},
    {"count": 4, "period": "2020"},
    {"count": 5, "period": "2021"},
    {"count": 3, "period": "2022"},
    {"count": 4, "period": "2023"},
    {"count": 6, "period": "2024"},
    {"count": 7, "period": "2025"},
    {"count": 2, "period": "2026"}
  ],
  "meta": {"source": "clinicaltrials.gov", "date_field": "startDateStruct", "total_studies": 100},
  "type": "time_series",
  "encoding": {
    "x": {"label": "Year", "type": "temporal", "field": "period", "granularity": "year"},
    "y": {"label": "Number of Trials Started", "type": "quantitative", "field": "count"}
  },
  "title": "Breast Cancer Clinical Trials Over Time"
}
```

## Immunotherapy trials by phase

```elixir
CheironTakeHome.Orchestrator.query("What phases are immunotherapy trials in?")
```

```json
{
  "data": [
    {"phase": "PHASE2", "trial_count": 7},
    {"phase": "NA", "trial_count": 2},
    {"phase": "PHASE1", "trial_count": 1},
    {"phase": "PHASE3", "trial_count": 1}
  ],
  "meta": {"source": "clinicaltrials.gov", "total_studies": 10},
  "type": "bar_chart",
  "sort": {"field": "phase", "order": "descending"},
  "encoding": {
    "x": {"label": "Phase", "type": "categorical", "field": "phase"},
    "y": {"label": "Number of Trials", "type": "quantitative", "field": "trial_count"}
  },
  "title": "Immunotherapy Clinical Trials by Phase"
}
```

## Lung cancer treatment network

```elixir
CheironTakeHome.Orchestrator.query("What drugs are used to treat lung cancer?")
```

```json
{
  "data": [
    {"source": "Non Small Cell Lung Cancer", "target": "Atezolizumab", "weight": 2},
    {"source": "Solid Tumor Cancer", "target": "Dexamethasone", "weight": 2},
    {"source": "Lung Cancer", "target": "Radiation Therapy", "weight": 2},
    {"source": "Lung Cancer", "target": "Standard Care", "weight": 2},
    {"source": "Lung Cancer", "target": "Irinotecan Hydrochloride", "weight": 2},
    {"source": "Non Small Cell Lung Cancer", "target": "Entrectinib", "weight": 1},
    {"source": "Non Small Cell Lung Cancer", "target": "Lapatinib", "weight": 1},
    {"source": "Non Small Cell Lung Cancer", "target": "Alectinib", "weight": 1},
    {"source": "Adenocarcinoma", "target": "Pemetrexed", "weight": 1},
    {"source": "Breast Cancer", "target": "Atezolizumab", "weight": 1}
  ],
  "meta": {
    "source": "clinicaltrials.gov",
    "total_studies": 100,
    "edge_type": "condition_to_intervention"
  },
  "type": "network_graph",
  "encoding": {
    "source": {"label": "Condition", "type": "categorical", "field": "source"},
    "target": {"label": "Intervention", "type": "categorical", "field": "target"},
    "weight": {"label": "Number of Trials", "type": "quantitative", "field": "weight"}
  },
  "title": "Lung Cancer Clinical Trials Treatment Network"
}
```

## CRISPR clinical trials over time

```elixir
CheironTakeHome.Orchestrator.query("When did CRISPR clinical trials start ramping up?")
```

```json
{
  "data": [
    {"count": 3, "period": "2016"},
    {"count": 2, "period": "2017"},
    {"count": 8, "period": "2018"},
    {"count": 5, "period": "2019"},
    {"count": 6, "period": "2020"},
    {"count": 11, "period": "2021"},
    {"count": 11, "period": "2022"},
    {"count": 13, "period": "2023"},
    {"count": 14, "period": "2024"},
    {"count": 16, "period": "2025"},
    {"count": 8, "period": "2026"},
    {"count": 2, "period": "2027"},
    {"count": 1, "period": "2028"}
  ],
  "meta": {"source": "clinicaltrials.gov", "date_field": "startDateStruct", "total_studies": 100},
  "type": "time_series",
  "encoding": {
    "x": {"label": "Year", "type": "temporal", "field": "period", "granularity": "year"},
    "y": {"label": "Number of Trials Started", "type": "quantitative", "field": "count"}
  },
  "title": "Crispr Clinical Trials Over Time"
}
```

# Setup (AI generated)

## Prerequisites

- Erlang/OTP 26+
- Elixir 1.15+
- An OpenAI API key with access to `gpt-4o`

## Install and run

```bash
mix setup
export OPENAI_API_KEY="sk-..."
mix phx.server
```

The server starts on `http://localhost:4000`. You can also query directly from an IEx session:

```bash
iex -S mix phx.server
iex> CheironTakeHome.Orchestrator.query("How many lung cancer trials are in each phase?")
```

## Configuration

| Variable | Required | Description |
|---|---|---|
| `OPENAI_API_KEY` | Yes | OpenAI API key for query interpretation |
| `PORT` | No | HTTP port (default: 4000) |

# Request/Response Schema (AI generated)

## Request

`POST /api/query`

| Field | Type | Required | Description |
|---|---|---|---|
| `query` | string | Yes | Natural language question about clinical trials. Must be non-empty. |
| `condition` | string | No | Condition or disease (e.g. `"lung cancer"`). Overrides LLM-inferred condition. |
| `drug_name` | string | No | Intervention or drug (e.g. `"Pembrolizumab"`). Overrides LLM-inferred intervention. |
| `trial_phase` | string | No | Trial phase filter (e.g. `"PHASE3"`). |
| `sponsor` | string | No | Sponsor name. Used as a general search term. |
| `start_year` | integer | No | Exclude trials that started before this year. |
| `end_year` | integer | No | Exclude trials that started after this year. |

Structured fields are optional and bypass LLM interpretation for the parameters they cover. When provided, they override the corresponding LLM-inferred values — this gives deterministic search behavior and lower latency when the caller already knows the query parameters.

```json
{"query": "How has trial activity changed over time?", "drug_name": "Pembrolizumab", "start_year": 2015}
```

## Response (success)

`200 OK`

The response wraps a visualization specification under a `visualization` key:

```json
{
  "visualization": {
    "type": "...",
    "title": "...",
    "encoding": { ... },
    "data": [ ... ],
    "meta": { ... },
    "sort": { ... }
  }
}
```

### Visualization spec fields

| Field | Type | Present | Description |
|---|---|---|---|
| `type` | `"bar_chart"`, `"time_series"`, or `"network_graph"` | Always | Visualization type |
| `title` | string | Always | Human-readable title incorporating the search subject |
| `encoding` | object | Always | Maps data fields to visual channels (see below) |
| `data` | array of objects | Always | Data points to render; keys match `encoding` field names |
| `meta` | object | Always | Contains `source` (always `"clinicaltrials.gov"`) and `total_studies` |
| `sort` | object | Bar charts only | Contains `field` and `order` (`"descending"`) |

### Encoding channels

Each channel in `encoding` (keyed by `x`/`y` for charts, or `source`/`target`/`weight` for network graphs) has:

| Field | Type | Description |
|---|---|---|
| `field` | string | Key name in each `data` object |
| `label` | string | Human-readable axis label |
| `type` | `"categorical"`, `"quantitative"`, or `"temporal"` | Data type for rendering |
| `granularity` | `"year"`, `"month"`, or `"quarter"` | Time series x-axis only |

### Bar chart data points

Each object in `data` has a categorical field (the `group_by` value, e.g. `"phase"` or `"status"`) and `"trial_count"` (integer).

### Time series data points

Each object in `data` has `"period"` (string, e.g. `"2024"` or `"2024-Q3"`) and `"count"` (integer).

### Network graph data points

Each object in `data` has `"source"` (string, e.g. a condition name), `"target"` (string, e.g. an intervention or sponsor name), and `"weight"` (integer, number of trials linking the pair). The `meta` object includes `edge_type` (`"condition_to_intervention"` or `"condition_to_sponsor"`).

## Response (error)

`422 Unprocessable Entity` or `400 Bad Request`

```json
{"error": "No data matched the query — try broadening your search terms"}
```

# Design Decisions (AI generated)

**Pipeline architecture.** The system is a linear pipeline: LLM interprets the query into a structured plan, ClinicalTrials.gov returns studies, and the Munger transforms raw data into a viz spec. Each step is a separate module with its own HTTP boundary, making them independently testable and replaceable.

**LLM as a classifier, not a data source.** The LLM's only job is to convert natural language into structured query parameters and a viz type. It never sees trial data and cannot hallucinate data points. All data comes directly from ClinicalTrials.gov.

**Deterministic specs.** The viz spec is designed so that two independent frontend implementations would render the same chart from the same spec. Encoding channels declare field names, types, and labels; the frontend doesn't need to guess what goes on which axis.

**Property-based testing.** The Munger is tested with StreamData property tests that enforce structural invariants: every output label traces to input data, counts sum correctly, encoding fields exist in data points, and type/shape constraints hold. These were mutation-tested against 10 injected bugs, all caught.

**Constrained LLM output.** The system prompt explicitly enumerates valid values for `viz_type`, `group_by`, `query_params` keys, and `time_granularity`. The orchestrator and munger validate these downstream as a safety net, returning typed errors rather than crashing on unexpected LLM output.

# Limitations and Future Work (AI generated)

**Three viz types.** Bar charts, time series, and network graphs are implemented. The assignment also suggests scatter plots and histograms, which could be added with new Munger function heads and LLM prompt constraints.

**No deep citations.** Data points don't trace back to individual `nct_id`s or text excerpts. The data is there in the API response (each study has `nctId` and `briefTitle`), but the Munger aggregates it away. Adding citations would mean carrying study references through the frequency counting.

**Structured fields don't skip the LLM call.** The optional `condition`, `drug_name`, etc. fields override LLM-inferred parameters after the LLM runs. A further optimization would skip the LLM call entirely when the user provides enough structured fields to build the query plan directly.

**Single API page.** Time series queries fetch 100 studies; bar charts fetch 10. For conditions with thousands of trials (e.g., "cancer"), this is a sample, not a census. Pagination support would give more accurate counts.

**No retry/validation on LLM output.** If the LLM returns a malformed plan (wrong `viz_type`, missing `query_params`), the system errors. A production system would validate the plan and retry with a corrective prompt.

**No frontend.** The spec is designed to be renderable by any charting library (D3, Vega-Lite, Recharts), but no demo frontend is included.

# AI Tools (AI generated)

**Claude Code** was used extensively for implementation. The development process was: plan architecture and iterations by hand, write prompts describing what to build, feed prompts to Claude Code, test results in IEx, and iterate. The prompts used are preserved in `/claude_code_prompts`.

**What was deliberate:** Architecture, iteration planning, module boundaries, test strategy (property-based tests with mutation testing), prompt engineering for the LLM system prompt, and all design decisions documented above.

**What was generated and adapted:** Module boilerplate, test scaffolding, HTTP client setup, and incremental bug fixes surfaced through IEx testing. Each generated change was tested in-terminal before being accepted.

**Validation:** Property-based tests with StreamData enforce structural invariants on Munger output. Mutation testing (10 injected bugs, all caught) validated that the property tests are meaningful. Orchestrator tests use Mox to mock HTTP boundaries. Manual IEx testing against the live ClinicalTrials.gov API caught issues that unit tests missed (wrong LLM parameter names, case sensitivity, empty results).

# Development Log (done by hand)

(This was typed by hand with the exception of the sections marked as `(AI generated)`. I did, however, *tak to* Claude Code a lot while writing this.)

## Approach
### Thu Jul  2 17:56:01 2026

Okay, so before I make any real decisions, here's the approach:

1. Read the assignment
2. Map out the architecture at the highest level of abstraction: What's MVP? How do I get there? Do I iterate after? How and why?
3. Spec out each iteration: MVP (meets requirements), and then following versions that meet the optional parts of the assignment for a higher grade
4. Define working process. When do I write tests? how do I iterate? How should each commit look? What do I document?
5. THEN make the decision of which tech to use: repurpose CAKE, from-scratch Elixir with some cues taken from CAKE, Python
6. Take the chosen tech and execute 4 until MVP, then iterate.

## Iterations, first pass
#### Thu Jul  2 18:09:30 2026

### MVP (iteration 1)

ABSTRACTION: Users may input a string. The application returns a JSON map designating type of visualization, title, encoding for that visualization, data to be rendered, and metadata for rendering. The returned spec must be articulated well enough that the front-end can be implemented deterministically (i.e. the front end does the same thing with the same data no matter who designs it). Should support at least **2** visualization types: bar chart and time series.

ADDITIONAL DOCUMENTS: all source code, a README on installation, configuration, explanation of nontrivial design decisions, and options for further development. Also need 3 to 5 example queries with the JSON outputs for each one.

ITERATION: Look at ClinicalTrials.gov's API and map the API's capabilities to the optional requirements.

### ClinicalTrials.gov API

Talking to Claude Chat about this endpoint and also reading the docs. Priorities for this assignment are marked `!!`

The ClinicalTrials.gov API is a clean v2 REST API. The base URL is `https://clinicaltrials.gov/api/v2`. Rate limit is approx 50 requests/minute. Conforms to OpenAPI 3.0. `GET /api/2/studies` is the endpoint we'll use the most. 

#### Tyoed Query Parameters

- `query.cond` (condition/disease) !!
- `query.intr` (intervention/drug - broadly, a treament) !!
- `query.term` (full-text, fallback for anything that does not clearly decompose into `query.cond` or `query.intr`) !! 
- `query.locn` (location)
- `query.spons` (sponsor - likely not important)
- `filter.overallStatus` (RECRUITING, COMPLETED, TERMINATED, etc)
- `filter.phase` (phase of the study, PHASE1, PHASE2, EARLY_PHASE1, NA, etc, important for bar charts) !!
- `filter.ids` (for specific NCT IDs)

#### Response 

##### Core response fields

- `protocolSection` (everything lives in here)
- `identificationModule` → `nctId`, `briefTitle` (for citations, labeling)
- `statusModule` → `overallStatus`, `startDateStruct`, `completionDateStruct` (for time series and status bar charts)
- `designModule` → `phases` (for phase bar charts — this is an array, watch for multi-phase trials)
- `sponsorCollaboratorsModule` → `leadSponsor`, `collaborators` (for network graphs)
- `conditionsModule` → `conditions` (for network graphs linking drugs to diseases)
- `armsInterventionsModule` → `interventions` (for network graphs linking drugs to sponsors/conditions)
- `descriptionModule` → `briefSummary` (for deep citation excerpts)

##### Secondary priority

- `eligibilityModule` → enrollment count, age ranges, sex — could feed scatter plots (enrollment by phase, enrollment over time)
- outcomesModule → primary/secondary outcome measures — interesting for richer queries but adds parsing complexity
- `contactsLocationsModule` → locations — relevant only if you support geographic visualization

### Iteration 2

ABSTRACTION: As Iteration 1, but user input now includes a set of extra fields based on query params. The assignment is graded partially on breadth of coverage, so the more the better. Each of those fields must have names, types, and validation. They may or may not be optional. These fields must meaningfully affect what the application returns. Should support at least an **additional 2** visualization types prompted by the query parameters, e.g. network graphs for sponsors to conditions or a histogram of trial statuses.

### Iteration 3

ABSTRACTION: As Iteration 2, but now we want to support deep citations. That means that, for any given trial, we include at least an `nct_id`. No new visualization types required, although we may add citations to existing types, e.g. a mouseover of a scatterplot may show a tooltip with extra information about a given data point.

### Iteration 4

ABSTRACTION: As Iteration 3, but with an at least **moderately sexy** front-end.

## Iterations, second pass
#### Thu Jul  2 19:41:57 2026 

Given the above considerations, I'm electing to do a from-scratch project in Elixir/Phoenix. Python would be faster in a vacuum but Elixir is my strongest language. The biggest missing piece is LLM wrappers, but I've written those as part of my CAKE project anyway so I can import or quickly rewrite them. At this stage, I can do a second pass on the iterations showing how they'll be implemented in Elixir.

### MVP (Iteration 1)

This holds no state, but the processing is fairly complicated: two API wrappers, a munger, and an input layer. This holds no state so the input layer might as well be the orchestration layer as well. The LLM APi needs its own wrapper and we'll assume OpenAI at this point, although if I had more time I'd make it agnostic about which LLM platform is being used. The architecture at MVP is orchestrator/input layer → LLM wrapper → orchestrator → ClinicalStudies API wrapper → orchestrator → munger → orchestrator/output.


1. Spin up an Elixir/Phoenix project without a front-end using  `mix phx.new . --no-html --no-assets --no-ecto`.
2. Unit testing: property-based tests for the munger (specs for the spec!), mocks for API calls from both API boundary layers. No integration tests yet because we may need to split modules later on and integration tests will just slow that down. Tests for the munger must cover specs for both bar charts and time series. The property-based tests *must force traceability between the spec and the data that came back from the ClinicalTrials API!!*. TESTS MUST FAIL.
3. Build the two API wrappers, two commits, tests pass. The LLM API wrapper defines a struct that contains both the query params for the ClinicalTrials.gov API *and* the visualization choice, with a hardcoded list of allowable choices. The latter may eventually affect the former.
4. Build the munger, property tests pass.
5. Build the orchestrator. Smoke tests at most because anything else is an integration test. If we need smoke tests, build them first.

### Iteration 2

This is where the LLM wrapper earns its keep. The whole point of the LLM here is to NLP the user query into a set of params. In MVP, that's just `query.cond` and `query.intr`. In practice, that cashes out to careful prompt engineering so the LLM gives us the right params. Integration testing of live LLM use is outside the scope of this assignment; however, if I had time, I would generate a large number of LLM responses (say, 1000) periodically (say, once a week) and property-test those, with a tolerance for failures (too many fails = too many retries = fix the prompts!). This, of course, implies retry logic for LLM output if it turns out bad.

1. Revise the LLM wrapper tests to include the extra query param fields; this is the step where we define which are required and which are optional. This is where we add extra visualization types. The LLM TESTS MUST FAIL. Then, revise the wrapper to make them pass.
2. As 1, but with the ClinicalStudies wrapper. 
3. Revise the munger test to cover the two new visualization types with specs appropriate to eac. TESTS MUST FAIL. Revise the munger module to make the tests pass.
4. Integration testing. Which shakes out to "test the orchestrator"

### Iteration 3
This is where we include deep citations. Since deep citations come from the ClinicalTrials API, this means modifying the wrapper thereof.

1. Modify the struct inside of the ClinicalTrials wrapper to include `nctId` and some metadata fields TBD, and change the API calls to include that info
2. Make citations an option the user can select via some flag in the input layer
3. Modify the munger so that each visualization's data key also contains citation metadata and make sure that's returned with the visualization spec.

### Iteration 4
This is just a nice frontend. We may partially build this at the beginning anyway just to ensure that the visualization spec is easy to render.
1. DaisyUI or similar
2. Pre-made components online
3. Chatbox with rendering component at `/home`


## Prompting to MVP
#### Thu Jul  2 21:55:09 2026

This is where I'm recording the actual changes I make and hand off to Claude Code, which is how I'll write most of this. I burned the first 4 hours of development time on planning, research, and architecting. If done correctly, the actual implementation will be the shorter part. I did this by talking to Claude Code about what I wanted it to do in chat, having it generate prompts, feeding those prompts into Claude Code. You can find the prompts I generated under `/claude_code_prompts`.

How do I link to another file in markdown?
To link to another file in markdown, you can use the following syntax:

Replace "Link Text" with the text you want to display as the link, and "path/to/another/file" with the relative or absolute path to the file you want to link to.

### [Prompt 1](claude_code_prompts/prompt_1.md)

We're gonna need `Req` for http requests, `Mox` for mocking API calls, `stream_data` for property testing, and `nimble_options` because I created this repo with Ecto to validate things.  This is the kind of boilerplate busywork that LLMs are for: stub out modules and tests, add dependencies, run CLI commands.

### [Prompt 2](claude_code_prompts/prompt_2.md)

This prompt creates the failing tests for the API wrapper modules. There will be another prompt to make the tests pass. At that point, I'm going to pause prompting in order to stop and test the API modules in-terminal. If everything shakes out ok, then I'll move on. But if the API responses have unexpected shapes, I'll copy the shape of the responses into Claude Chat, ask for new prompts to fix the tests based on those, run those prompts to revise the tests, allow the tests to fail, and then prompt Claude Code to modify the wrapper modules so that those tests will pass.

### [Prompt 3](claude_code_prompts/prompt_3.md)

See above. This is a series of prompts that I gave to Claude Code as a result of it screwing up the modules.

I tested the http client in an `iex` REPL session and it's a good thing I did because it defaults to `nil` in a dev environment which is pants-on-head stupid. After we fixed that, I got this error:

```elixir
iex(1)> CheironTakeHome.LLM.interpret("How many studies are there for lung cancer?")
** (Jason.DecodeError) unexpected byte at position 0: 0x60 ("`")
    (jason 1.4.5) lib/jason.ex:92: Jason.decode!/2
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/llm.ex:27: CheironTakeHome.LLM.handle_response/1
    iex:1: (file)
```

which I fed to Claude Code without commentary. It seems to be working in the REPL now! Woo-hoo! Tests and modules for the API wrappers are up and working! Trials API. The next step is bar chart and time series specs for the munger, which means testing for the munger.

The munger itself will define the viz_specs as hardcoded functions returning maps. I would make those sub-modules like CheironTakeHome.Munger.BarChart​ and define them with a defmodule​ statement inside of the 

### [Prompt 4](claude_code_prompts/prompt_4.md)

Created munger tests. But they only assert traceability to data points returned by the ClinicalTrials API. They don't force the data to actually be something the front-end can render.

### [Prompt 5](claude_code_prompts/prompt_5.md)

Forces the munger test to define a shape that makes front-end rendering determinstic.

### [Prompt 6](claude_code_prompts/prompt_6.md)

Smoke tests for orchestrator and make it pass. I said earlier I could wait on integration tests, but these are pretty simple (hence "smoke tests"). Ideally, these are just here to make sure that the orchestrator calls the functions it's supposed to call in the order it's supposed to call then and returns an error when each step fails. These integration tests, in a real app, would become more complex as the app matures because these pipelines can fail at multiple levels.

Minor changes made to the munger here. `granularity` already occurs in the x-axis of the maps so we don't need it in metadata. `date_field` added to metadata. All tests pass.

### [Prompt 7](claude_code_prompts/prompt_7.md)

These are fairly simple Claude Code prompts but they serve to detect anything very obviously wrong. These property tests enforce invariants, so getting them right gives us a leg to stand on with autogenerated code that makes them pass. Claude Code mutation-tested the properties by introducing bugs that would violate those properties and then running the tests again. For 10 mutations, all bugs were caught, so these property tests seem to be working as designed. These were the mutation tests:

| #  | Mutation                              | Caught by                                                      |
|----|---------------------------------------|----------------------------------------------------------------|
| 1  | BAR: phantom phase                    | "every phase in output appears in input" + "no phantom counts" |
| 2  | BAR: doubled counts                   | "no phantom counts: sum of trial_counts equals input"          |
| 3  | BAR: missing sort key                 | "bar chart structure" (shape helper)                           |
| 4  | BAR: wrong x encoding type            | "bar chart structure" (x must be categorical)                  |
| 5  | TS: phantom period "9999"             | "every time bucket corresponds to input" + "no phantom counts" |
| 6  | TS: doubled counts                    | "no phantom counts: sum equals input studies with dates"       |
| 7  | TS: reverse sort                      | "output data is sorted chronologically"                        |
| 8  | TS: missing granularity               | "time series structure" (shape helper)                         |
| 9  | SHAPE: empty title                    | shape helper on both bar + time series                         |
| 10 | COHERENCE: encoding field not in data | encoding-data coherence helper                                 |

### Piecemeal prompts

I got this when trying to test via `iex` REPL:

```elixir
iex(1)> CheironTakeHome.Orchestrator.query("What causes lung cancer?")
** (FunctionClauseError) no function clause matching in CheironTakeHome.Orchestrator.to_viz_type/1    
    
    The following arguments were given to CheironTakeHome.Orchestrator.to_viz_type/1:
    
        # 1
        "text_summary"
    
    Attempted function clauses (showing 2 out of 2):
    
        defp to_viz_type("bar_chart")
        defp to_viz_type("time_series")
    
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/orchestrator.ex:43: CheironTakeHome.Orchestrator.to_viz_type/1
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/orchestrator.ex:36: CheironTakeHome.Orchestrator.split_query_plan/1
    (cheiron_take_home 0.1.0) lib/cheiron_take_home/orchestrator.ex:6: CheironTakeHome.Orchestrator.query/1
    iex:1: (file)
```

Claude Code surfaced two things:

1. The orchestrator has no fallback for unrecognized viz types — it crashes instead of returning an {:error, ...} tuple.
2. The LLM's system prompt doesn't tell it which viz_type values are valid, so it can return anything.

This is a series of prompts that I used to fill in the last few nooks and crannies to reach MVP.

-------------------------------------------------------------------------------

I noticed an error where empty lists were being quietly returned. After prompting a bit and running diagnostics, Claude Code applied these fixes:

```
1. Empty data returns an error — Both bar_chart and time_series branches in Munger.build/2 now
check if data == [] and return {:error, :empty_result}.
2. Unsupported group_by is rejected early — A new function head in Munger.build/2 validates
group_by against @supported_group_by and returns {:error, {:unsupported_group_by, ...}} for
unknown values. The silent catch-all extract_group_values(_, _) is removed.
3. LLM prompt constrained — The system prompt now tells the LLM that group_by must be "phase" or
"status", defaulting to "phase" when the question doesn't clearly map.
4. Added "status" grouping support — New extract_group_values/2 clause for "status" so the Munger
can group by recruitment status.
5. Controller error formatting — Added format_error clauses for the two new error types.
```

