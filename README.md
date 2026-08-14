# scaleLLMflow

`scaleLLMflow` is an R package for applying prompt-defined assessment scales to collections of PDF, TXT, or Markdown documents with an LLM.

The package provides the execution framework: document extraction, prompt resolution, provider calls, retries, structured-response validation, scoring, audit logs, and dataset reports. Each registered scale defines its own items, scoring rules, metadata, and response format.

## Installation

From a local checkout:

```powershell
R CMD build .
R CMD INSTALL scaleLLMflow_0.2.0.tar.gz
```

For development:

```r
devtools::load_all("path/to/scaleLLMflow")
```

The package requires R and the dependencies listed in `DESCRIPTION`. Tests use
`testthat`.

## Credentials

Credentials are supplied by the user and are never stored by the package.
Configure them in `.Renviron`, the system environment, RStudio, or pass an
API key in memory for a single call:

- Gemini: `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY`
- OpenAI: `OPENAI_API_KEY`
- Optional OpenAI project: `OPENAI_PROJECT_ID`
- Claude/Anthropic: `ANTHROPIC_API_KEY` or `CLAUDE_API_KEY`

## Quick start

```r
library(scaleLLMflow)

available_scales()

result <- run_article(
  article_path = "path/to/article.pdf",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-3.6-flash",
  filetype = "pdf"
)

result$scores
result$total_score
```

To process a directory:

```r
results <- run_dataset(
  articles_dir = "path/to/articles",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-3.6-flash",
  output_dir = "results",
  filetype = "auto"
)
```

`filetype` accepts `pdf`, `txt`, `md`, or `auto`. Dataset runs create a
timestamped subdirectory with scores, evidence, audit logs, and an errors file
when any document fails.

## Providers and models

Provider integrations are selected explicitly with `provider` and `model`.
The provider API determines which model identifiers are available; the prompt
registry does not attempt to maintain a static list of every available model.

Supported provider values are `gemini`, `openai`, and `claude` (with `chatgpt`
as an OpenAI alias and `anthropic` as a Claude alias). Claude uses Anthropic's
Messages API. The bundled MQS and PEDro prompts are scale-level and independent
of the selected Claude model.

Prompt selection is independent of model availability. The official resolver
uses exactly one accepted prompt per scale; the requested provider and model
only control the API call. MQS therefore uses one provider-neutral prompt for
all supported models.

Generation and resilience options can be passed to `run_article()` and
`run_dataset()`:

```r
result <- run_article(
  article_path = "path/to/article.pdf",
  temperature = 0,
  top_p = 0.1,
  timeout = 300,
  max_retries = 3,
  retry_wait_seconds = 1,
  retry_backoff = 2,
  rate_limit_seconds = 0
)
```

For reproducible scoring, use a low temperature and record the prompt,
provider, model, and runtime settings in the audit output.

To inspect the models currently exposed by a provider, independently of any
scale, use:

```r
available_provider_models("gemini")
available_provider_models("openai")
available_provider_models("claude")
```

This function queries each provider's models endpoint and therefore requires
the corresponding API key. It is intentionally not hard-coded, because the
available model catalogue changes over time.

## Scales and prompt registry

Registered scales live under `inst/scales`:

Article text is converted to Markdown before it is appended to the scale
prompt. Headings, bullet points, and conservative whitespace-separated table
blocks are preserved as Markdown structures. This behaviour is controlled by
`tables_advanced`, which defaults to `TRUE` in `extract_article_text()`,
`run_article()`, and `run_dataset()`. Set it to `FALSE` to send extracted text
without this structuring pass.

```text
inst/scales/<scale>/
  prompt.md
  metadata.json
```

The prompt contains the operational instructions for the LLM. `metadata.json`
declares the formal item definition, allowed decisions, total-score rules, and
the response schema. These two files must agree. Every official prompt must
begin with a single `RUN_VERSION: <version>` line, and that value must exactly
match `metadata.json$prompt_version`. A prompt without a matching version is
rejected by the registry audit and resolver.

The response schema is fail-closed: malformed JSON, missing items, unexpected
decisions, or missing required fields are rejected rather than silently scored.
Each item result contains a decision, evidence, and reason.

To inspect the registry:

```r
available_scales()
resolved <- resolve_prompt("mqs", "gemini-3.6-flash")
resolved$prompt_path
resolved$prompt_version

audit <- audit_model_registry(output_dir = "results/registry_audit")
audit$checks
```

To add a scale, see [ADD_NEW_SCALE_SKILL.md](ADD_NEW_SCALE_SKILL.md).

### Local prompt training

Prompts can be refined in a private training project without changing the
package registry. Copy a scale prompt and its `metadata.json` to a local
`scales/<scale>/` folder, run the articles into separate
`iterations/iteration_N` directories, and compare them with a reviewed
`ideal.csv`:

```r
run <- run_dataset(
  "training/my_mqs/articles", scale = "mqs", provider = "gemini",
  model = "gemini-3.6-flash", registry_dir = "training/my_mqs/scales",
  output_dir = "training/my_mqs/iterations/iteration_1",
  temperature = 0, tables_advanced = TRUE
)

comparison <- compare_training_iterations(
  "training/my_mqs/ideal.csv", "training/my_mqs/iterations"
)
comparison$summary
```

To request a proposed revision without overwriting the prompt, use
`propose_prompt_revision()`. It consumes the current `prompt.md`, the item-level
comparison and the audit/evidence files from the latest iteration. The proposal
is returned for human review; no file is changed and no article is rerun:

```r
proposal <- propose_prompt_revision(
  prompt_path = "training/my_mqs/scales/mqs/prompt.md",
  comparison = comparison$comparison,
  reason_files = list.files(
    "training/my_mqs/iterations/iteration_1",
    pattern = "_AuditLog\\.txt$", full.names = TRUE, recursive = TRUE
  ),
  provider = "gemini",
  model = "gemini-3.6-flash",
  output_path = "training/my_mqs/scales/mqs/prompt_proposal.md"
)
cat(proposal$prompt)
```

With `output_path`, the proposal is written directly to `prompt_proposal.md`.
The original prompt is never overwritten. Review the proposal manually before
using it as the next local prompt version.

Review item-level evidence and reasons before changing the local prompt. Keep
each prompt snapshot and result directory; choose the version with the best
item-level accuracy and the fewest systematic errors. Agreement with the
training key is not external scientific validation.

### Private scales in a local research project

You can use a private scale without editing the installed package, opening a
pull request, or publishing the prompt. Store the scale registry in a separate
project directory and pass it through `registry_dir`:

```text
my-study/
  scales/
    my_scale/
      prompt.md
      metadata.json
```

The folder name is the scale name. The prompt and metadata must contain a
matching `RUN_VERSION`/`prompt_version` pair, following the contract in
`ADD_NEW_SCALE_SKILL.md`. The same external registry can be used with
`available_scales()`, `resolve_prompt()`, `run_article()`, and `run_dataset()`:

```r
library(scaleLLMflow)

my_registry <- "my-study/scales"

available_scales(my_registry)
resolve_prompt(
  scale = "my_scale",
  model = "gemini-3.6-flash",
  provider = "gemini",
  registry_dir = my_registry
)

result <- run_article(
  article_path = "my-study/articles/article.pdf",
  scale = "my_scale",
  provider = "gemini",
  model = "gemini-3.6-flash",
  registry_dir = my_registry
)
```

Before running articles, validate the local registry:

```r
audit <- audit_model_registry(
  registry_dir = my_registry,
  output_dir = "my-study/registry-audit"
)

audit$checks
subset(audit$checks, Status == "ERROR")
```

The audit checks the local file layout, metadata JSON, scale definition, total
score contract, response schema, and duplicate prompts. It does not determine
whether the scientific interpretation of a prompt is valid or whether a model
produces accurate ratings. Those require pilot articles and, preferably,
reference scores using `validation_mode = "reference"`.

This workflow keeps the prompt, scale definition, articles, and results under
the researcher's control. It does not make model execution local: the bundled
providers still send article text to Gemini, OpenAI, or Claude. Fully local
execution with Ollama, LM Studio, or another local model requires an additional
provider integration.

## Validation modes

Free mode evaluates a document without reference scores:

```r
result <- run_article("path/to/article.pdf", validation_mode = "free")
```

Reference mode compares the model's item decisions with previously reviewed
scores while preserving the raw response:

```r
reference <- c(Item_1 = 1, Item_2 = 0.5, Item_3 = 1, Item_4 = 1,
               Item_5 = 1, Item_6 = 0, Item_7 = 1, Item_8 = 0.5,
               Item_9 = 1, Item_10 = 1)

result <- run_article(
  "path/to/article.pdf",
  validation_mode = "reference",
  reference_scores = reference
)

result$validation
```

For datasets, use `reference_csv` with an `ID` column and `Item_1` through
`Item_n` columns.

## Outputs and reproducibility

Audit outputs record the requested and selected prompt, provider, model,
generation settings, input sizes, and SHA-256 hashes for the extracted text,
prompt, request, and raw response. This makes it possible to identify changes
in source documents, prompts, or runtime configuration.

## Tests and package development

Run the test suite from the package directory:

```powershell
Rscript -e "testthat::test_dir('tests/testthat')"
```

Build the source package with:

```powershell
R CMD build .
```

Do not commit `.Renviron` or files containing real API keys.
