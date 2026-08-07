# Integration test: compare Gemini Flash-Lite and OpenAI GPT-4.1 mini against
# the MQS reference scores for the three bundled research articles.
# All outputs are deliberately written below this test directory.

script_file <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))[1]])
test_dir <- if (nzchar(script_file)) normalizePath(dirname(script_file), mustWork = TRUE) else getwd()
example_dir <- normalizePath(file.path(test_dir, ".."), mustWork = TRUE)
package_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)

# Load the source package when running from the repository, so the test always
# exercises the current local implementation.
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(package_dir, quiet = TRUE)
} else if (!requireNamespace("scaleLLMflow", quietly = TRUE)) {
  stop("Install scaleLLMflow or install the pkgload package before running this test.", call. = FALSE)
}
library(scaleLLMflow)

articles_dir <- file.path(example_dir, "articles")
reference_csv <- file.path(example_dir, "ideal_results.csv")
if (!file.exists(reference_csv)) stop("Reference CSV not found: ", reference_csv, call. = FALSE)

models <- list(
  gemini_flash_lite = list(provider = "gemini", model = "gemini-3.5-flash-lite"),
  openai_gpt41_mini = list(provider = "openai", model = "gpt-4.1-mini")
)

# Fail before processing if credentials for either requested provider are not
# available. Values are never printed or written to the result files.
if (!nzchar(Sys.getenv("GEMINI_API_KEY", unset = "")) &&
    !nzchar(Sys.getenv("GOOGLE_GEMINI_KEY", unset = ""))) {
  stop("Missing Gemini API key.", call. = FALSE)
}
if (!nzchar(Sys.getenv("OPENAI_API_KEY", unset = ""))) {
  stop("Missing OpenAI API key.", call. = FALSE)
}

run_one_model <- function(name, configuration) {
  output_dir <- file.path(test_dir, name)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  message("Running ", name, " (", configuration$provider, "/", configuration$model, ")")
  result <- run_dataset(
    articles_dir = articles_dir,
    scale = "mqs",
    provider = configuration$provider,
    model = configuration$model,
    output_dir = output_dir,
    filetype = "pdf",
    strip_references = TRUE,
    reference_csv = reference_csv,
    validation_mode = "reference",
    temperature = 0,
    top_p = 0.1,
    timeout = 300,
    max_retries = 2,
    retry_wait_seconds = 1,
    retry_backoff = 2,
    rate_limit_seconds = 0
  )

  # Keep a provider-labelled copy of the machine-readable report inside the
  # model directory, alongside the article audit logs and raw responses.
  utils::write.csv2(result$results,
    file.path(output_dir, "scores_and_totals.csv"), row.names = FALSE)
  utils::write.csv2(result$errors,
    file.path(output_dir, "errors.csv"), row.names = FALSE)
  result
}

results <- lapply(names(models), function(name) run_one_model(name, models[[name]]))
names(results) <- names(models)

# Summarize the two provider runs in the test directory without discarding the
# detailed per-article validation sections written by run_dataset().
summary <- do.call(rbind, lapply(names(results), function(name) {
  result <- results[[name]]
  data.frame(
    Run = name,
    Provider = models[[name]]$provider,
    Requested_Model = result$resolved_prompt$requested_model,
    Articles_Scored = nrow(result$results),
    Articles_With_Errors = nrow(result$errors),
    Mean_Total_Score = if (nrow(result$results) > 0) mean(result$results$Total_Score, na.rm = TRUE) else NA_real_,
    stringsAsFactors = FALSE
  )
}))
utils::write.csv2(summary, file.path(test_dir, "comparison_summary.csv"), row.names = FALSE)
print(summary)
message("Test complete. Outputs: ", test_dir)
