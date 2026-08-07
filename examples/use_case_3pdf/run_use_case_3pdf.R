# Reproducible example: run the MQS scale on three PDFs with Gemini 2.5 Flash.
# The paths below are resolved from this script's location, so it can be run
# from the repository root, this folder, or an RStudio source session.
# Rscript "library/scaleLLMflow/examples/use_case_3pdf/run_use_case_3pdf.R"

script_file <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))][1])
example_dir <- if (nzchar(script_file)) normalizePath(dirname(script_file), mustWork = TRUE) else getwd()
library_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)
project_root <- normalizePath(file.path(library_dir, "..", ".."), mustWork = TRUE)

# --- USE CASE CONFIGURATION ---
# Change these values to reuse the example with another registered scale,
# provider, model, article folder, or output folder. Keep each experiment in a
# distinct output directory so previous audit logs are never overwritten.
scale_name <- "mqs"
provider <- "gemini"
model <- "gemini-3.6-flash"
articles_dir <- file.path(example_dir, "articles")
output_dir <- file.path(project_root, "resultados", "use_case_3pdf_mqs")
filetype <- "pdf"
strip_references <- TRUE
max_articles <- 0

# Install the local package only when it is not already available to R.
ensure_scale_llmflow <- function() {
  if (requireNamespace("scaleLLMflow", quietly = TRUE)) {
    return(invisible(TRUE))
  }

  package_dir <- library_dir
  if (!dir.exists(package_dir)) {
    stop("scaleLLMflow is not installed and package directory was not found: ", package_dir, call. = FALSE)
  }

  install.packages(package_dir, repos = NULL, type = "source")
}

# Fail early with a clear message instead of starting a partial API run.
ensure_api_key <- function(provider) {
  provider <- tolower(provider)
  if (provider == "chatgpt") {
    provider <- "openai"
  }

  if (provider == "gemini") {
    has_key <- nzchar(Sys.getenv("GEMINI_API_KEY", unset = "")) ||
      nzchar(Sys.getenv("GOOGLE_GEMINI_KEY", unset = ""))
    if (!has_key) {
      stop("Missing Gemini API key. Set GEMINI_API_KEY or GOOGLE_GEMINI_KEY.", call. = FALSE)
    }
  }

  if (provider == "openai" && !nzchar(Sys.getenv("OPENAI_API_KEY", unset = ""))) {
    stop("Missing OpenAI API key. Set OPENAI_API_KEY.", call. = FALSE)
  }
}

ensure_scale_llmflow()
ensure_api_key(provider)

library(scaleLLMflow)

# Check the input set before calling the provider. The library accepts PDF,
# TXT, and Markdown files; this fixed example intentionally uses PDFs only.
article_files <- list.files(articles_dir, pattern = "\\.pdf$", full.names = FALSE, ignore.case = TRUE)
if (length(article_files) == 0) {
  stop("No PDF articles found in: ", articles_dir, call. = FALSE)
}

message("Running scaleLLMflow use case")
message("Scale: ", scale_name)
message("Articles directory: ", articles_dir)
message("Output directory: ", output_dir)
message("Provider: ", provider)
message("Model: ", model)
message("Filetype: ", filetype)
message("Articles found: ", length(article_files))
print(article_files)

# Show which registered prompt will be selected for the requested model.
resolved <- resolve_prompt(scale_name, model)
message("Selected prompt model: ", resolved$selected_model)
message("Prompt match strategy: ", resolved$strategy)

# Run the complete directory. Existing sufficiently large audit logs are
# reused by scaleLLMflow, which makes the example safe to resume.
result <- run_dataset(
  articles_dir = articles_dir,
  scale = scale_name,
  provider = provider,
  model = model,
  output_dir = output_dir,
  filetype = filetype,
  strip_references = strip_references,
  max_articles = max_articles
)

message("Finished.")
message("CSV report: ", result$csv_path)
print(result$results)
