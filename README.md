# scaleLLMflow

`scaleLLMflow` is an R library for running prompt-defined scoring workflows over document collections with LLMs.

For each document, the library extracts or reads the document text, resolves the best available prompt for the requested scale and model, sends that prompt plus the document content to the selected LLM provider, and parses the returned item scores. The questions, items, scoring rules, and output format are defined by the prompt itself. In other words, the library provides the reusable execution framework; each registered prompt defines what should be assessed and how the result should be formatted.

The package includes a small set of already trained or validated scales as examples. The intended direction is community extension: users can contribute new scales, prompts, model-specific prompt variants, training metadata, and parsers where needed.

Typical use cases include methodological quality scales, reporting checklists, risk-of-bias tools, coding schemes, and other structured document assessment tasks where each document must be scored across a defined set of items.

The library organizes trained prompts by scale and model:

```text
inst/scales/
  mqs/
    gemini-2.5-flash/
      prompt.md
      metadata.json
  pedro/
    gemini-2.5-flash/
      prompt.md
      metadata.json
    gemini-flash/
      prompt.md
      metadata.json
    generic/
      prompt.md
      metadata.json
```

Each model folder represents a prompt trained or validated with a specific dataset. If a requested model has no exact prompt, `resolve_prompt()` searches for the closest available prompt:

1. exact model;
2. same textual family, for example `flash`;
3. same numeric version;
4. `generic` prompt;
5. closest available folder name.

API keys always belong to the user and are read from the environment. No API keys are stored in the library.

Expected variables:

- `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY`
- `OPENAI_API_KEY`
- `OPENAI_PROJECT_ID`, optional

Gemini requests use the [Gemini Interactions API](https://ai.google.dev/gemini-api/docs/interactions-overview?hl=en)
through `POST /v1beta/interactions`. The request uses `input`, the requested
`model`, JSON response formatting, and `store: false` by default so article
content is not retained as a stored Interaction. The response extractor reads
text from `steps` of type `model_output`.

## Local Installation

From the repository root:

```powershell
R CMD INSTALL "library/scaleLLMflow"
```

During development:

```r
devtools::load_all("library/scaleLLMflow")
```

## Basic Use

```r
library(scaleLLMflow)

available_scales()
available_models("mqs")

result <- run_article(
  article_path = "data/pdf/training_set1/2004 Miller.pdf",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-2.5-flash",
  filetype = "pdf"
)

result$scores
```

### Generation and execution parameters

The generation parameters are selected when launching `run_article()`,
`run_dataset()`, or `run_llm()`:

```r
result <- run_article(
  article_path = "path/to/trial.pdf",
  temperature = 0,
  top_p = 0.1,
  timeout = 300
)
```

`temperature` controls response variability. Its default is `0`, which is
recommended for reproducible scientific scoring. `top_p` controls nucleus
sampling in Gemini and defaults to `0.1`; it is currently ignored by the
OpenAI integration. `timeout` is the maximum duration of each individual API
attempt in seconds, not the total duration when retries are enabled.

The resilience parameters are configured in the same call: `max_retries`
(default `3`), `retry_wait_seconds` (default `1`), `retry_backoff` (default
`2`), and `rate_limit_seconds` (default `0`). Retry delays are added on top of
the per-attempt timeout and rate limiting applies between requests made by the
same R process.

PEDro v008 can be run with the same workflow. It defaults to all 11 items and
parses the prompt's JSON `Yes`/`No` decisions into numeric item scores:

```r
result <- run_article(
  article_path = "path/to/trial.pdf",
  scale = "pedro",
  provider = "gemini",
  model = "gemini-2.5-flash",
  filetype = "pdf"
)
```

Run a full directory:

```r
results <- run_dataset(
  articles_dir = "data/pdf/training_set2",
  scale = "mqs",
  provider = "gemini",
  model = "gemini-2.5-flash",
  output_dir = "resultados/set2_library_run",
  filetype = "pdf"
)
```

`filetype` can be `pdf`, `txt`, `md`, or `auto`. With `auto`, the library analyzes all `.pdf`, `.txt`, and `.md` files in the folder.

If an article fails during a dataset run, the error is recorded in
`<scale>_Errors.csv` and processing continues with the remaining articles.
The consensus report is still written for successful articles.

Provider calls use bounded resilience defaults: up to three retries for network
errors, timeouts, HTTP 408/409/425/429, and HTTP 5xx responses; exponential
backoff starting at one second; and no rate-limit delay by default. Configure
these options when needed:

```r
result <- run_article(
  article_path = "path/to/trial.pdf",
  max_retries = 5,
  retry_wait_seconds = 2,
  retry_backoff = 2,
  rate_limit_seconds = 1
)
```

Client errors such as invalid authentication or malformed requests are not
retried. Final errors include the provider, model, attempt number, HTTP status
when available, and a truncated response body. Credentials are never included
in error messages.

### Reproducibility metadata

Each article result and audit log records the UTC timestamp, package and R
versions, requested and selected prompt models, provider, generation settings,
retry/rate-limit settings, input sizes, and SHA-256 hashes for the extracted
article text, prompt, complete request, and raw response. The original article
path and file size are also recorded. These fields make it possible to detect
whether a later result used different source text, prompt content, or runtime
parameters.

## Add a New Scale

For a complete, reusable implementation guide that can also be supplied as
context to an LLM or coding agent, read
[ADD_NEW_SCALE_SKILL.md](ADD_NEW_SCALE_SKILL.md).

Create:

```text
inst/scales/<scale_name>/<model>/prompt.md
inst/scales/<scale_name>/<model>/metadata.json
```

The prompt must include the scale definition, scoring rules, and expected output format. The library automatically appends the article text to the end of the request.

### Response contract

Registered scales use a strict JSON response contract declared in their
`metadata.json`. Every required item must be present and must contain the
scale-specific decision plus `evidence` and `reason` strings. Invalid JSON,
missing items, unexpected decisions, Markdown fences, and extra text are
rejected before scoring. This fail-closed behavior prevents malformed output
from silently becoming missing or incorrect scores.

When adding a scale, define `response_schema` in the metadata and describe the
same schema in the prompt. Keep the raw response in audit outputs and make the
numeric encoding explicit in the parser when decisions are not numeric.

The scientific definition is a separate `scale_definition` object in the same
metadata file. It is authoritative for item existence, permitted values, total
membership, missing-value policy, and total calculation. The prompt is the
operational instruction for the LLM; it must agree with this definition but is
not used as the source of scoring rules. Results expose `total_score`, and
dataset reports include `Total_Score` calculated from the formal definition.

## Tests

The package includes `testthat` tests for prompt resolution, strict JSON schema
validation, multiline item parsing, PEDro JSON parsing, and conservative
reference removal. Run them from the package directory with:

```powershell
Rscript -e "testthat::test_dir('tests/testthat')"
```

Do not commit `.Renviron` or any file containing real API keys.

## API Key Policy

The library never includes API keys. Each user must configure credentials in `.Renviron`, system environment variables, RStudio, or pass `api_key` in memory for a specific call. The variables read by the library are:

- Gemini: `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY`
- OpenAI/ChatGPT: `OPENAI_API_KEY`
- Optional OpenAI project: `OPENAI_PROJECT_ID`
