library(scaleLLMflow)

test_that("figure page detection finds caption-bearing pages", {
  pages <- c(
    "Abstract and Methods",
    "Figure 1. Participant flow chart",
    "Results with no visual content",
    "Graph A shows the primary outcome"
  )
  expect_equal(scaleLLMflow:::detect_figure_pages(pages), c(2L, 4L))
})

test_that("figure prompts require faithful transcription", {
  prompt <- scaleLLMflow:::figure_conversion_prompt(c(2, 5))
  expect_match(prompt, "labels")
  expect_match(prompt, "Do not guess unreadable values")
  expect_match(prompt, "2, 5", fixed = TRUE)
})

test_that("figure-aware conversion is explicit about provider support", {
  expect_error(
    scaleLLMflow:::run_llm_multimodal("prompt", list(list(mime_type = "image/png", data = "x")), provider = "openai"),
    "requires provider = 'gemini'"
  )
})
