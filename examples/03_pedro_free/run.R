# Run PEDro freely on the three local articles.
script_file <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))[1]])
example_dir <- normalizePath(if (nzchar(script_file)) dirname(script_file) else getwd(), mustWork = TRUE)
package_dir <- normalizePath(file.path(example_dir, "..", ".."), mustWork = TRUE)
pkgload::load_all(package_dir, quiet = TRUE)
run <- scaleLLMflow::run_dataset(
  file.path(example_dir, "articles"), scale = "pedro", provider = "gemini",
  model = "gemini-3.5-flash-lite", output_dir = file.path(example_dir, "results"),
  filetype = "pdf", temperature = 0
)
print(run$results)
