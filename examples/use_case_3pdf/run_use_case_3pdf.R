# Fixed use case: MQS scale on 3 PDFs with Gemini 2.5 Flash.
# Run from the project root:
# Rscript "library/scaleLLMflow/examples/use_case_3pdf/run_use_case_3pdf.R"

# --- USE CASE CONFIGURATION ---
scale_name <- "mqs"
provider <- "gemini"
model <- "gemini-2.5-flash"
articles_dir <- file.path("library", "scaleLLMflow", "examples", "use_case_3pdf", "articles")
output_dir <- file.path("resultados", "use_case_3pdf_mqs")
filetype <- "pdf"
strip_references <- TRUE
max_articles <- 0

ensure_scale_llmflow <- function() {
  if (requireNamespace("scaleLLMflow", quietly = TRUE)) {
    return(invisible(TRUE))
  }

  package_dir <- file.path("library", "scaleLLMflow")
  if (!dir.exists(package_dir)) {
    stop("scaleLLMflow is not installed and package directory was not found: ", package_dir, call. = FALSE)
  }

  install.packages(package_dir, repos = NULL, type = "source")
}

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

resolved <- resolve_prompt(scale_name, model)
message("Selected prompt model: ", resolved$selected_model)
message("Prompt match strategy: ", resolved$strategy)

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
