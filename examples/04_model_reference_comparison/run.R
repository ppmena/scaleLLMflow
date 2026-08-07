# Compare Gemini Flash-Lite and OpenAI GPT-4.1 mini against MQS references.
file_args <- commandArgs(trailingOnly = FALSE)
file_arg <- file_args[startsWith(file_args, "--file=")]
script_file <- if (length(file_arg) == 1) sub("^--file=", "", file_arg) else ""
example_dir <- normalizePath(if (nzchar(script_file)) dirname(script_file) else getwd(), mustWork = TRUE)
package_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)
pkgload::load_all(package_dir, quiet = TRUE)
for (x in list(
  list(name = "gemini_flash_lite", provider = "gemini", model = "gemini-3.5-flash-lite"),
  list(name = "openai_gpt41_mini", provider = "openai", model = "gpt-4.1-mini")
)) {
  run <- scaleLLMflow::run_dataset(
    file.path(example_dir, "articles"), scale = "mqs",
    provider = x$provider, model = x$model,
    output_dir = file.path(example_dir, "results", x$name),
    filetype = "pdf", reference_csv = file.path(example_dir, "ideal_results.csv"),
    validation_mode = "reference", temperature = 0
  )
  print(run$results)
}
