# Run PEDro freely on the three local articles.
file_args <- commandArgs(trailingOnly = FALSE)
file_arg <- file_args[startsWith(file_args, "--file=")]
script_file <- if (length(file_arg) == 1) sub("^--file=", "", file_arg) else ""
example_dir <- normalizePath(if (nzchar(script_file)) dirname(script_file) else getwd(), mustWork = TRUE)
package_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)
pkgload::load_all(package_dir, quiet = TRUE)
run <- scaleLLMflow::run_dataset(
  file.path(example_dir, "articles"), scale = "pedro", provider = "gemini",
  model = "gemini-3.5-flash-lite", output_dir = file.path(example_dir, "results"),
  filetype = "pdf", temperature = 0
)
print(run$results)
