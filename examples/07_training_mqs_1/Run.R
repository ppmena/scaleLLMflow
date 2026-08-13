# Local MQS prompt-training example with two prompt-improvement iterations.
#
# Configure the API key in RStudio/.Renviron before running. Provider, model,
# and iteration names are deliberately defined in this script.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[startsWith(args, "--file=")]
script_file <- if (length(file_arg) == 1) sub("^--file=", "", file_arg) else ""
if (!nzchar(script_file) && requireNamespace("rstudioapi", quietly = TRUE)) {
  script_file <- rstudioapi::getActiveDocumentContext()$path
}
candidate_dirs <- if (nzchar(script_file)) {
  dirname(script_file)
} else {
  c(getwd(), file.path(getwd(), "examples", "training_mqs_1"))
}
candidate_dirs <- unique(normalizePath(candidate_dirs, mustWork = FALSE))
valid_dirs <- candidate_dirs[
  dir.exists(file.path(candidate_dirs, "articles")) &&
    dir.exists(file.path(candidate_dirs, "scales"))
]
if (length(valid_dirs) == 0) {
  stop(
    "Could not locate the training example directory. Open this file from " ,
    "examples/training_mqs_1 or set the working directory to that folder.",
    call. = FALSE
  )
}
example_dir <- normalizePath(valid_dirs[[1]], mustWork = TRUE)

library(scaleLLMflow)

# Set the training configuration directly in this script for each run.
provider <- "openai"
model <- "gpt-4.1-mini"
scale <- "mqs"
registry_dir <- file.path(example_dir, "scales")
prompt_path <- file.path(registry_dir, "mqs", "openai-generic", "prompt.md")
iterations_dir <- file.path(example_dir, "iterations")

run_iteration <- function(iteration, prompt_proposal_path = NULL) {
  if (!is.null(prompt_proposal_path)) {
    file.copy(prompt_proposal_path, prompt_path, overwrite = TRUE)
  }
  run_dataset(
    articles_dir = file.path(example_dir, "articles"),
    scale = scale,
    provider = provider,
    model = model,
    registry_dir = registry_dir,
    output_dir = file.path(iterations_dir, iteration),
    filetype = "auto",
    temperature = 0,
    tables_advanced = TRUE
  )
}

latest_reasons <- function(iteration) {
  list.files(file.path(iterations_dir, iteration),
    pattern = "_AuditLog\\.txt$", full.names = TRUE, recursive = TRUE)
}

save_comparison <- function(comparison, label) {
  utils::write.csv2(comparison$comparison,
    file.path(example_dir, paste0("comparison_", label, ".csv")), row.names = FALSE)
  utils::write.csv2(comparison$summary,
    file.path(example_dir, paste0("comparison_summary_", label, ".csv")), row.names = FALSE)
}

# Baseline: run the original local prompt.
run_1 <- run_iteration("iteration_1")
comparison_1 <- compare_training_iterations(
  file.path(example_dir, "ideal.csv"), iterations_dir
)
save_comparison(comparison_1, "iteration_1")

# Improvement 1: propose and save a new prompt, preserving the original.
proposal_2 <- propose_prompt_revision(
  prompt_path = prompt_path,
  comparison = comparison_1$comparison,
  reason_files = latest_reasons("iteration_1"),
  provider = provider,
  model = model,
  output_path = file.path(registry_dir, "mqs", "openai-generic", "prompt_proposal_2.md")
)
file.copy(prompt_path,
  file.path(registry_dir, "mqs", "openai-generic", "prompt_iteration_1.md"),
  overwrite = TRUE)

# Iteration 2: evaluate proposal 2.
run_2 <- run_iteration("iteration_2", proposal_2$output_path)
comparison_2 <- compare_training_iterations(
  file.path(example_dir, "ideal.csv"), iterations_dir
)
save_comparison(comparison_2, "iteration_2")

# Improvement 2: propose a third prompt from iteration 2, without evaluating it.
proposal_3 <- propose_prompt_revision(
  prompt_path = prompt_path,
  comparison = comparison_2$comparison,
  reason_files = latest_reasons("iteration_2"),
  provider = provider,
  model = model,
  output_path = file.path(registry_dir, "mqs", "openai-generic", "prompt_proposal_3.md")
)

print(comparison_2$summary)
cat("Prompt proposals written to:\n")
cat(proposal_2$output_path, "\n")
cat(proposal_3$output_path, "\n")
