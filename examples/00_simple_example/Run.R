
example_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
# example_dir <- getwd()

run <- scaleLLMflow::run_dataset(
  file.path(example_dir, "articles"),
  scale = "mqs",
  provider = "gemini",
  model = "gemini-3.6-flash",
  output_dir = file.path(example_dir, "results"),
  filetype = "pdf",
  temperature = 0
)

print(run$results)
