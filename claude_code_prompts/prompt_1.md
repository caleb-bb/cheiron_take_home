# Claude Code Prompt: Minimal Scaffold for cheiron_take_home

## Context
The Phoenix project `cheiron_take_home` already exists. Created with `mix phx.new cheiron_take_home --no-html --no-assets --no-ecto`. Compiles and tests pass.

## Task: Ensure dependencies are present, create module stubs and test stubs. Nothing else.

### Step 0: Assess
Read this entire prompt. Confirm you understand the task by listing the steps you'll take. Do not begin until you've confirmed.

### Step 1: Ensure these dependencies are in mix.exs
Check the existing `deps` list. Ensure ALL of the following are present. Add any that are missing. Do NOT remove or modify any existing deps:

- `{:req, "~> 0.5"}`
- `{:jason, "~> 1.4"}`
- `{:nimble_options, "~> 1.1"}`
- `{:mox, "~> 1.1", only: [:test]}`
- `{:stream_data, "~> 1.1", only: [:test, :dev]}`

Run `mix deps.get` then `mix compile`. Zero errors.

### Step 2: Create module stubs
Create these four files. Each contains ONLY a `defmodule` with a `@moduledoc`. No functions, no structs, no callbacks.

- `lib/cheiron_take_home/llm.ex` — `CheironTakeHome.LLM` — "Wrapper for OpenAI API. Interprets natural language queries into structured query plans."
- `lib/cheiron_take_home/clinical_trials.ex` — `CheironTakeHome.ClinicalTrials` — "Wrapper for the ClinicalTrials.gov v2 API."
- `lib/cheiron_take_home/munger.ex` — `CheironTakeHome.Munger` — "Transforms raw ClinicalTrials.gov data plus visualization intent into a structured visualization spec."
- `lib/cheiron_take_home/orchestrator.ex` — `CheironTakeHome.Orchestrator` — "Routes user input through the pipeline: LLM interpretation, API retrieval, munging, output."

### Step 3: Create test stubs
Create these four files. Each uses `ExUnit.Case, async: true` and contains zero test cases.

- `test/cheiron_take_home/llm_test.exs` — `CheironTakeHome.LLMTest`
- `test/cheiron_take_home/clinical_trials_test.exs` — `CheironTakeHome.ClinicalTrialsTest`
- `test/cheiron_take_home/munger_test.exs` — `CheironTakeHome.MungerTest`
- `test/cheiron_take_home/orchestrator_test.exs` — `CheironTakeHome.OrchestratorTest`

### Step 4: Verify
Run `mix compile` — zero errors.
Run `mix test` — all tests pass.

### Step 5: Stage only
```bash
git add -A
```

Do NOT commit. Do NOT run `git commit`. Stage only.

### HARD STOP
Do NOT proceed past this point. Do NOT write any function implementations, structs, behaviours, or test cases. Do NOT commit. Report what you did and stop.
