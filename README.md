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

## Tests

The package includes `testthat` tests for prompt resolution, multiline item
parsing, PEDro JSON parsing, and conservative reference removal. Run them from
the repository root with:

```powershell
Rscript -e "testthat::test_dir('library/scaleLLMflow/tests/testthat')"
```

Do not commit `.Renviron` or any file containing real API keys.

## API Key Policy

The library never includes API keys. Each user must configure credentials in `.Renviron`, system environment variables, RStudio, or pass `api_key` in memory for a specific call. The variables read by the library are:

- Gemini: `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY`
- OpenAI/ChatGPT: `OPENAI_API_KEY`
- Optional OpenAI project: `OPENAI_PROJECT_ID`
