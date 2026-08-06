# Skill: add a document-assessment scale to scaleLLMflow

## Purpose

Use this guide as context when adding a new scientific document-assessment scale
to `scaleLLMflow`. The goal is a reproducible workflow that sends article text
to an LLM, records the exact prompt used, extracts item-level scores, and
produces an auditable result.

## Inputs to establish first

Before editing files, identify:

- the canonical scale name and its item numbering;
- the permitted response values and whether any items are excluded from the
  official total;
- the evidence and decision rules for every item;
- the required LLM output format (prefer a strict, machine-readable format);
- the target provider/model and the prompt version or source document;
- any training articles and answer key available for validation.

Do not infer scoring rules from a single article. Preserve the source scale's
meaning, item order, and response encoding.

## Required implementation

Create one directory per scale and one directory per model prompt:

```text
library/scaleLLMflow/inst/scales/<scale_name>/<model_name>/
  prompt.md
  metadata.json
```

Use lowercase, filesystem-safe names. The prompt must state:

1. the role of the rater and the scale definition;
2. the evidence rules and decision criteria for every item;
3. the permitted values, including how to handle insufficient evidence or
   not-applicable cases;
4. whether an item is reported but excluded from the official total;
5. the exact output schema, including every item on every response;
6. an instruction to use only the extracted article text supplied by the
   workflow and not outside knowledge.

The `metadata.json` should record at least:

```json
{
  "scale": "example",
  "model": "gemini-2.5-flash",
  "provider": "gemini",
  "prompt_version": "v001",
  "status": "registered",
  "items": 10,
  "source_prompt": "path/to/source/prompt.md"
}
```

Never change the default model `gemini-2.5-flash` unless the task explicitly
requires a different test. Never store API keys in the library.

## Parser and workflow contract

The shared workflow in `R/workflow.R` handles PDF/text extraction, prompt
resolution, prompt snapshots, LLM calls, audit logs, and dataset iteration.
Existing `*_AuditLog.txt` files are intentionally skipped; do not remove that
behavior.

The shared parser in `R/parse.R` expects item scores to be recoverable from the
LLM response. If the new prompt uses the standard line format, emit one line
per item, for example:

```text
* Item 1: 1.0 | Justification: ...
```

If the prompt uses JSON or another format, add a narrow parser branch that:

- recognizes only the new scale's schema;
- maps its values to the scale's permitted numeric encoding;
- preserves missing/invalid values as `NA` rather than guessing;
- leaves MQS and other existing scales unchanged;
- allows audit logs to retain the original raw response.

If the scale has a different number of items, make the default explicit in the
workflow (as PEDro does with 11 items), while still allowing callers to pass an
explicit `items` vector.

## Validation checklist

Run from the repository root:

```powershell
R CMD INSTALL "library/scaleLLMflow"
```

Then verify in R:

```r
library(scaleLLMflow)
available_scales()
available_models("example")
resolve_prompt("example", "gemini-2.5-flash")
```

Run at least one article with a distinct output directory and inspect:

- `prompt_used.md` contains the resolved prompt and model metadata;
- the audit log preserves the expected text format;
- every item is present and has a valid encoded score;
- totals agree with the item scores and exclusion rules;
- the consensus CSV has the expected columns and item order;
- an existing audit log is skipped on a repeat run.

For a training scale, compare results against the answer key and document the
dataset, prompt version, model, provider, and validation outcome. Keep each
prompt/model test in a distinct output folder. Do not overwrite previous
results.

## Documentation and handoff

Update `library/scaleLLMflow/README.md` with the new registry path and a
minimal usage example. Keep the prompt source or version reference in the
metadata and ensure the prompt snapshot is written by the workflow. Report
which files changed, how the parser maps responses, and which tests were run.
