# Run MQS freely on the three local articles.
pkgload::load_all(".", quiet = TRUE)
run <- scaleLLMflow::run_dataset(
  "examples/01_mqs_free/articles", scale = "mqs", provider = "gemini",
  model = "gemini-3.6-flash", output_dir = "examples/01_mqs_free/results",
  filetype = "pdf", temperature = 0
)
print(run$results)
