# Run MQS or PEDro with Claude through Anthropic's Messages API.
# Set ANTHROPIC_API_KEY (or CLAUDE_API_KEY) before running this example.
file_args <- commandArgs(trailingOnly = FALSE)
file_arg <- file_args[startsWith(file_args, "--file=")]
script_file <- if (length(file_arg) == 1) sub("^--file=", "", file_arg) else ""
if (!nzchar(script_file) && requireNamespace("rstudioapi", quietly = TRUE)) {
  script_file <- rstudioapi::getActiveDocumentContext()$path
}
example_dir <- normalizePath(if (nzchar(script_file)) dirname(script_file) else getwd(), mustWork = TRUE)
package_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)
pkgload::load_all(package_dir, quiet = TRUE)

if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY", unset = "")) &&
    !nzchar(Sys.getenv("CLAUDE_API_KEY", unset = ""))) {
  stop("Configure ANTHROPIC_API_KEY or CLAUDE_API_KEY before running this example.", call. = FALSE)
}

# Select the scale and Claude model explicitly in this example.
scale <- "mqs"
model <- "claude-sonnet-4-20250514"
articles_dir <- Sys.getenv(
  "ARTICLES_DIR",
  unset = file.path(example_dir, "articles")
)

cat("Available Claude models:\n")
print(scaleLLMflow::available_provider_models("claude"))

run <- scaleLLMflow::run_dataset(
  articles_dir = articles_dir,
  scale = scale,
  provider = "claude",
  model = model,
  output_dir = file.path(example_dir, "results"),
  filetype = "pdf",
  temperature = 0
)
print(run$results)
