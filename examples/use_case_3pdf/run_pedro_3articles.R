# Minimal PEDro run over the three bundled articles.

pkgload::load_all(".", quiet = TRUE)

run <- scaleLLMflow::run_dataset(
  articles_dir = file.path("examples", "use_case_3pdf", "articles"),
  scale = "pedro",
  provider = "gemini",
  model = "gemini-3.5-flash-lite",
  output_dir = file.path("examples", "use_case_3pdf", "pedro_results"),
  filetype = "pdf",
  temperature = 0,
  max_retries = 2
)

print(run$results)
print(run$errors)
