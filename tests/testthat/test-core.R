library(scaleLLMflow)

test_that("transient failures are retried and errors include context", {
  attempts <- 0L
  result <- scaleLLMflow:::with_retries(function() {
    attempts <<- attempts + 1L
    if (attempts < 3) stop("temporary network failure")
    "ok"
  }, "gemini", "test-model", max_retries = 2, retry_wait_seconds = 0)
  expect_equal(result, "ok")
  expect_equal(attempts, 3)
  expect_error(scaleLLMflow:::with_retries(function() stop("bad request"),
    "openai", "test-model", max_retries = 0), "provider=openai")
})

test_that("provenance contains stable hashes and execution metadata", {
  expect_equal(nchar(scaleLLMflow:::sha256_text("hello")), 64)
  metadata <- scaleLLMflow:::resolve_prompt("mqs", "gemini-2.5-flash")
  provenance <- scaleLLMflow:::build_provenance(
    tempfile(fileext = ".txt"), "article text", "prompt", "prompt article",
    metadata, "gemini", "gemini-2.5-flash", 0, 0.1, 300, TRUE, 3, 1, 2, 0
  )
  expect_true(grepl("^[0-9a-f]{64}$", provenance$article_text_sha256))
  expect_equal(provenance$request_characters, nchar("prompt article"))
  expect_true(!is.null(provenance$r_version))
})

testthat::test_that("prompt registry resolves scales and model fallbacks", {
  testthat::expect_true("mqs" %in% available_scales())
  testthat::expect_true("pedro" %in% available_scales())
  exact <- resolve_prompt("pedro", "gemini-2.5-flash")
  testthat::expect_equal(exact$selected_model, "gemini-2.5-flash")
  testthat::expect_true(file.exists(exact$prompt_path))
})

testthat::test_that("line-oriented scores and multiline items are parsed", {
  response <- paste(
    "* Item 1: 1.0 | Justification: first line",
    "second line of justification",
    "* Item 2: 0.5 | Justification: another item",
    sep = "\n"
  )
  testthat::expect_equal(parse_scale_scores(response, 1:2), c(Item_1 = 1, Item_2 = 0.5))
})

testthat::test_that("PEDro JSON decisions are parsed into numeric scores", {
  response <- paste0(
    '{"items":{"eligibility_criteria":{"decision":"No"},',
    '"random_allocation":{"decision":"Yes"}}}'
  )
  testthat::expect_equal(parse_scale_scores(response, 1:2), c(Item_1 = 0, Item_2 = 1))
})

testthat::test_that("reference stripping requires a section heading", {
  body <- paste(
    "Discussion: previous references are discussed here.",
    "The conclusion remains in the article.",
    "References",
    "Smith 2020.",
    sep = "\n"
  )
  stripped <- strip_references_section(body)
  testthat::expect_match(stripped, "conclusion remains")
  testthat::expect_false(grepl("Smith 2020", stripped, fixed = TRUE))
})
