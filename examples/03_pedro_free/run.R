# Run PEDro freely on the three local articles.
pkgload::load_all(".", quiet = TRUE)
run <- scaleLLMflow::run_dataset(
  "examples/03_pedro_free/articles", scale = "pedro", provider = "gemini",
  model = "gemini-3.5-flash-lite", output_dir = "examples/03_pedro_free/results",
  filetype = "pdf", temperature = 0
)
print(run$results)
