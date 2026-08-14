# Skill: add a document-assessment scale to scaleLLMflow

**Linked package version:** `scaleLLMflow 0.3.6`  
**Compatibility:** This guide describes the registry, Markdown extraction, and
local prompt-training interfaces available in version `0.3.6`. Review the
package changelog and this version marker when using a later release.

## Purpose

Use this guide as context when adding a new scientific document-assessment scale
to `scaleLLMflow`. The goal is a reproducible workflow that sends article text
to an LLM, records the exact prompt used, extracts item-level scores, and
produces an auditable result.

## Inputs to establish first

Article inputs are local PDF, TXT, or Markdown files available before the
workflow starts.

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

Create provider-generic directories for every scale, plus optional
model-specific directories when a prompt has been tuned or validated for a
particular model:

```text
library/scaleLLMflow/inst/scales/<scale_name>/<provider>-generic/
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
  "model": "gemini-3.6-flash",
  "provider": "gemini",
  "prompt_version": "v001",
  "status": "registered",
  "items": 10,
  "source_prompt": "path/to/source/prompt.md"
}
```

It must also declare the scientific scale contract separately from the prompt:

```json
{
  "scale_definition": {
    "items": {
      "1": {
        "label": "Eligibility criteria",
        "allowed_values": [0.0, 1.0],
        "included_in_total": false
      }
    },
    "total": {
      "method": "sum",
      "items": ["2", "3"],
      "na_policy": "fail"
    }
  }
}
```

The definition is the authoritative scientific contract: every item must be
listed, permitted values must be explicit, and the total must name exactly the
items included in the official score. Prompt wording must describe the same
rules but must not be the only place where they exist. Use `na_policy: "fail"`
when a missing item invalidates the total, or `"ignore"` only when the scale's
official scoring rules permit it. Use `included_in_total: false` for reported
items such as PEDro item 1, which is coded but excluded from the official score.

Never change the default model `gemini-3.6-flash` unless the task explicitly
requires a different test. Never store API keys in the library.

## Private local registries without a package update

A researcher does not need to modify the installed package or contribute the
scale through GitHub. Create the same `inst/scales/<scale>/<prompt_variant>/`
layout in a separate project directory and pass its parent directory as
`registry_dir` to `available_scales()`, `resolve_prompt()`, `run_article()`,
and `run_dataset()`.

Validate the private registry before use:

```r
audit <- audit_model_registry(
  registry_dir = "my-study/scales",
  output_dir = "my-study/registry-audit"
)
subset(audit$checks, Status == "ERROR")
```

An empty result means that no structural errors were reported. Review any
warnings and run pilot documents with reference scores before treating the
scale as scientifically validated. This local registry feature controls where
prompts and scale metadata are read from; it does not provide local model
inference. The standard providers still use their configured APIs.

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
available_provider_models("gemini")
resolve_prompt("example", "gemini-3.6-flash", provider = "gemini")
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

## Local prompt training and refinement

Once a scale is registered, its prompt can be refined in a private training
project without modifying the installed package or the official registry. Use a
separate directory such as:

```text
training/my_scale_training/
  articles/
  ideal.csv
  scales/my_scale/gemini-generic/prompt.md
  scales/my_scale/gemini-generic/metadata.json
  iterations/
```

The `articles/` directory contains a reviewed training set. `ideal.csv` must
contain an `ID` column and expected item columns such as `IT01`, `IT02`, etc.
Run the local registry into a separate iteration directory:

```r
library(scaleLLMflow)

run <- run_dataset(
  articles_dir = "training/my_scale_training/articles",
  scale = "my_scale",
  provider = "gemini",
  model = "gemini-3.6-flash",
  registry_dir = "training/my_scale_training/scales",
  output_dir = "training/my_scale_training/iterations/iteration_1",
  filetype = "auto",
  temperature = 0,
  tables_advanced = TRUE
)

comparison <- compare_training_iterations(
  "training/my_scale_training/ideal.csv",
  "training/my_scale_training/iterations"
)
comparison$summary
comparison$comparison
```

The summary reports accuracy by iteration. The detailed comparison reports the
obtained and ideal score for every article and item. Audit logs and evidence
reports contain the evidence and reasons behind the decisions.

### Proposing a revised prompt

`propose_prompt_revision()` can request a complete revised prompt using the
current prompt, the item-level comparison, and the reasons from the latest
iteration:

```r
reason_files <- list.files(
  "training/my_scale_training/iterations/iteration_1",
  pattern = "_AuditLog\\.txt$", full.names = TRUE, recursive = TRUE
)

proposal <- propose_prompt_revision(
  prompt_path = "training/my_scale_training/scales/my_scale/gemini-generic/prompt.md",
  comparison = comparison$comparison,
  reason_files = reason_files,
  provider = "gemini",
  model = "gemini-3.6-flash",
  output_path = "training/my_scale_training/scales/my_scale/gemini-generic/prompt_proposal.md"
)
```

The function does not run articles or overwrite the current prompt. Review the
generated Markdown manually, verify that the scientific definition and JSON
contract are preserved, and then decide whether to copy it to a new prompt
version before running the next iteration. Keep every iteration and prompt
snapshot in a separate directory. Four initial iterations are generally enough;
agreement with the training key is calibration, not general scientific
validation, so test the selected prompt on new articles and an independent
reference set.
