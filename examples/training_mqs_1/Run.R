# Local MQS prompt-training example.
#
# Set OPENAI_API_KEY or GOOGLE_GEMINI_KEY/GEMINI_API_KEY before running.
# Each run writes a new iteration directory and compares it with ideal.csv.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[startsWith(args, "--file=")]
script_file <- if (length(file_arg) == 1) sub("^--file=", "", file_arg) else ""
if (!nzchar(script_file) && requireNamespace("rstudioapi", quietly = TRUE)) {
  script_file <- rstudioapi::getActiveDocumentContext()$path
}
example_dir <- normalizePath(if (nzchar(script_file)) dirname(script_file) else getwd(), mustWork = TRUE)

library(scaleLLMflow)

provider <- Sys.getenv("TRAINING_PROVIDER", "openai")
model <- Sys.getenv("TRAINING_MODEL", if (provider == "gemini") "gemini-3.6-flash" else "gpt-4.1-mini")
iteration <- Sys.getenv("TRAINING_ITERATION", "iteration_1")
iteration_dir <- file.path(example_dir, "iterations", iteration)

run <- run_dataset(
  articles_dir = file.path(example_dir, "articles"),
  scale = "mqs",
  provider = provider,
  model = model,
  registry_dir = file.path(example_dir, "scales"),
  output_dir = iteration_dir,
  filetype = "auto",
  temperature = 0,
  tables_advanced = TRUE
)

comparison <- compare_training_iterations(
  ideal_csv = file.path(example_dir, "ideal.csv"),
  iterations_dir = file.path(example_dir, "iterations")
)

print(run$results)
print(comparison$summary)

