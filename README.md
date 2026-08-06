# scaleLLMflow

R library subproject for generalizing scale-based article assessment workflows with LLMs.

The library organizes trained prompts by scale and model:

```text
inst/scales/
  mqs/
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

## Add a New Scale

Create:

```text
inst/scales/<scale_name>/<model>/prompt.md
inst/scales/<scale_name>/<model>/metadata.json
```

The prompt must include the scale definition, scoring rules, and expected output format. The library automatically appends the article text to the end of the request.

## API Key Policy

The library never includes API keys. Each user must configure credentials in `.Renviron`, system environment variables, RStudio, or pass `api_key` in memory for a specific call. The variables read by the library are:

- Gemini: `GEMINI_API_KEY` or `GOOGLE_GEMINI_KEY`
- OpenAI/ChatGPT: `OPENAI_API_KEY`
- Optional OpenAI project: `OPENAI_PROJECT_ID`
