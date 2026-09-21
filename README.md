# scaleLLMflow

`scaleLLMflow` is a general-purpose R framework for applying structured, prompt-defined scientific assessment scales to local documents with large language models.

The package is model- and scale-agnostic: it provides the workflow infrastructure, while a scale registry provides the scientific definition and operational prompt. The same workflow supports bundled, private, and user-developed scales.

## What the package provides

- Local PDF, TXT, and Markdown workflows.
- Scale registries with formal metadata and response schemas.
- Provider adapters for Gemini, OpenAI, Claude, Mistral, and Ollama.
- Provider model discovery where available.
- Strict structured-response validation.
- Free evaluation and reference-comparison modes.
- Retries, exponential backoff, rate limiting, and detailed errors.
- Audit logs with raw responses, evidence, reasons, hashes, versions, input sizes, and execution parameters.
- Consolidated dataset reports for scores, evidence, and errors.
- Registry auditing and duplicate-prompt checks.
- Utilities for local prompt training and comparison.

## Installation

From a local checkout:

```powershell
R CMD build .
R CMD INSTALL scaleLLMflow_0.4.2.tar.gz
```

For development in RStudio:

```r
devtools::load_all("path/to/scaleLLMflow")
```

The package imports the libraries listed in `DESCRIPTION`; tests use `testthat`. The local script in `developer/` can regenerate Roxygen documentation and reinstall the package.

## Credentials

Credentials belong to the user and are never stored by the package. They may be defined in `.Renviron`, the operating-system environment, RStudio, or passed in memory for one call.

| Provider | Environment variables |
| --- | --- |
| Gemini | `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY` |
| OpenAI | `OPENAI_API_KEY`; optionally `OPENAI_PROJECT_ID` |
| Claude | `ANTHROPIC_API_KEY` or `CLAUDE_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |
| Ollama | No key; optionally `OLLAMA_BASE_URL` |

Do not commit `.Renviron` or files containing credentials.

## General workflow

A run makes four independent choices:

1. The registered scale.
2. The provider and model.
3. The document or document directory.
4. The execution mode: `free` or `reference`.

The following examples deliberately use placeholders rather than a particular scale or model:

```r
library(scaleLLMflow)

available_scales()
available_models(scale = "my_scale")

one_result <- run_article(
  article_path = "path/to/article.pdf",
  scale = "my_scale",
  provider = "my_provider",
  model = "my_model",
  filetype = "pdf",
  validation_mode = "free"
)

one_result$scores
one_result$total_score
```

For a directory:

```r
dataset_result <- run_dataset(
  articles_dir = "path/to/articles",
  scale = "my_scale",
  provider = "my_provider",
  model = "my_model",
  output_dir = "path/to/results",
  filetype = "auto",
  validation_mode = "free"
)
```

`filetype` accepts `pdf`, `txt`, `md`, or `auto`. Dataset runs create a new timestamped subdirectory below `output_dir`.

## Providers and models

Provider and model are explicit arguments. The provider selects the API adapter, and the model identifier is sent to that provider. Model catalogues change over time and are not hard-coded into the general workflow.

```r
available_provider_models("my_provider")
```

This queries the provider when a models endpoint is available. Hosted providers require credentials; local Ollama discovery requires a running Ollama server.

Generation and reliability parameters are available in both `run_article()` and `run_dataset()`:

```r
result <- run_article(
  article_path = "path/to/article.pdf",
  scale = "my_scale",
  provider = "my_provider",
  model = "my_model",
  temperature = 0,
  top_p = 0.1,
  timeout = 300,
  max_retries = 3,
  retry_wait_seconds = 1,
  retry_backoff = 2,
  rate_limit_seconds = 0
)
```

Parameter support depends on the provider. Supplied parameters are recorded in audit metadata.

## Scales and registries

The package separates the scientific scale definition, the operational prompt, and the numeric representation used in reports.

A registry can be bundled under `inst/scales` or stored in a private directory supplied through `registry_dir`:

```text
scales/
  my_scale/
    prompt.md
    metadata.json
```

`prompt.md` contains operational instructions for the model. `metadata.json` must define:

- the scale and prompt version;
- every item and its label;
- permitted values or categorical decisions;
- whether each item contributes to the total;
- the total-score rule and missing-value policy;
- the strict response schema;
- the fields required for evidence and reasoning.

Metadata is authoritative for validation and total-score calculation. The prompt must agree with it but is not the source of the scientific rules.

Inspect or validate a registry:

```r
available_scales(registry_dir = "scales")

resolve_prompt(
  scale = "my_scale",
  model = "my_model",
  provider = "my_provider",
  registry_dir = "scales"
)

audit_model_registry(
  registry_dir = "scales",
  output_dir = "registry-audit"
)
```

For the complete registry contract, see [ADD_NEW_SCALE_SKILL.md](ADD_NEW_SCALE_SKILL.md).

## Response validation and evidence

Registered scales use strict structured responses. Every required item must be present, its decision must be allowed by metadata, and its evidence and reason fields must be valid. Invalid or incomplete responses fail closed instead of silently becoming scores.

The raw model response is preserved in the audit log. Human-readable evidence and reasons are exported to the consolidated evidence report for review and prompt development.

## Execution modes

### Free mode

Free mode evaluates a document without assuming that a previous score is correct:

```r
result <- run_article(
  "path/to/article.pdf",
  scale = "my_scale",
  provider = "my_provider",
  model = "my_model",
  validation_mode = "free"
)
```

### Reference mode

Reference mode compares item decisions with reviewed scores while preserving the raw response:

```r
reference <- c(Item_1 = 1, Item_2 = 0, Item_3 = 1)

result <- run_article(
  "path/to/article.pdf",
  scale = "my_scale",
  provider = "my_provider",
  model = "my_model",
  validation_mode = "reference",
  reference_scores = reference
)

result$validation
```

For datasets, use a semicolon-separated `reference_csv` with an `ID` column and the required item columns.

## Outputs

Each dataset execution creates a directory such as:

```text
results/
  my_scale_YYYYMMDD_HHMMSS/
    prompt_used.md
    my_scale_Consensus_Report.csv
    my_scale_Evidence_Report.csv
    article_A_AuditLog.txt
    article_B_AuditLog.txt
    my_scale_Errors.csv       # only when errors occurred
```

The consensus report contains obtained item scores and calculated totals. The evidence report contains one row per document and item with `ID`, `Item`, `Score`, `Decision`, `Evidence`, and `Reason`. Errors are written only when at least one document fails. Direct `run_article()` calls can also write an individual evidence CSV.

Audit metadata records the provider, model, prompt version, package and R versions, generation settings, retry settings, input sizes, and SHA-256 hashes for source text, prompt, request, and raw response.

## Local scale development and prompt training

Private scales can be developed without modifying the installed package:

```text
my-project/
  scales/
    my_scale/
      prompt.md
      metadata.json
  articles/
  results/
```

Pass `my-project/scales` through `registry_dir`. Keep prompt versions, metadata, article inputs, and result directories under version control where appropriate. Use reviewed scores and `validation_mode = "reference"` to compare iterations. Agreement with a supplied reference does not establish external scientific validity.

Optional training helpers compare iterations and can propose a revised prompt for human review. They do not overwrite the current prompt or replace scientific review.

## Bundled scales and examples

The repository may include bundled scales and example directories to exercise the general framework. These are demonstrations, not API requirements or limitations. Consult the specific files under `examples/` for their selected provider, model, scale, articles, and reference data.

## Tests and development

Run the tests:

```powershell
Rscript -e "testthat::test_dir('tests/testthat')"
```

Regenerate R help pages from roxygen comments in `R/*.R`:

```r
roxygen2::roxygenise(load_code = "source", clean = FALSE)
```

Build the source package:

```powershell
R CMD build .
```

The full reference manual source is available in [help/scaleLLMflow.tex](help/scaleLLMflow.tex).

