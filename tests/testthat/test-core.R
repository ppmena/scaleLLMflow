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

test_that("429 retry hints are parsed and honored", {
  error <- structure(list(status = 429, response_body = "Please retry in 52.58s."),
    class = c("scaleLLMflow_provider_error", "error", "condition"))
  expect_equal(scaleLLMflow:::retry_after_seconds(error), 52.58)
  header_error <- structure(list(status = 429, response_body = "retry-after: 7"),
    class = c("scaleLLMflow_provider_error", "error", "condition"))
  expect_equal(scaleLLMflow:::retry_after_seconds(header_error), 7)
})

test_that("Gemini resolves its billing project from the environment", {
  old <- Sys.getenv("GOOGLE_CLOUD_PROJECT", unset = NA_character_)
  on.exit({
    if (is.na(old)) Sys.unsetenv("GOOGLE_CLOUD_PROJECT") else Sys.setenv(GOOGLE_CLOUD_PROJECT = old)
  }, add = TRUE)
  Sys.setenv(GOOGLE_CLOUD_PROJECT = "gen-lang-client-test")
  expect_equal(scaleLLMflow:::resolve_gemini_project(), "gen-lang-client-test")
  expect_equal(scaleLLMflow:::resolve_gemini_project("explicit-project"), "explicit-project")
})

test_that("Gemini Lite is the default model across workflows", {
  expect_identical(formals(scaleLLMflow::run_llm)$model, "gemini-3.5-flash-lite")
  expect_identical(formals(scaleLLMflow::run_article)$model, "gemini-3.5-flash-lite")
  expect_identical(formals(scaleLLMflow::run_dataset)$model, "gemini-3.5-flash-lite")
})

test_that("RoB 2 v005 applies the calibration safeguards", {
  resolved <- scaleLLMflow:::resolve_prompt("rob2", "gpt-5.6-luna", provider = "openai")
  prompt <- paste(readLines(resolved$prompt_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_equal(resolved$metadata$prompt_version, "v005")
  expect_match(prompt, "ordinary non-adherence or non-compliance")
  expect_match(prompt, "resentful demoralization")
  expect_match(prompt, "Answer `NA` if 2.1 and 2.2 are `N`/`PN`")
  expect_match(prompt, "Treat values produced by LOCF")
  expect_match(prompt, "Complete-case/list-wise deletion analysis")
  expect_match(prompt, "the participant is the outcome assessor")
  expect_match(prompt, "global selective non-reporting")
  expect_match(prompt, "three or more domains")
  expect_match(prompt, "`NI` means uncertainty, not evidence of bias")
  expect_match(prompt, "Never upgrade simply to be cautious")
  expect_match(prompt, "Do not infer bias from the numerical result itself")
})

test_that("RoB 2 excludes contextual metadata fields from the scoring contract", {
  removed <- c("Item_Study_ID", "Item_Experimental_Group", "Item_Comparator_Group",
    "Item_Variable_Outcome", "Item_Result_Numerical")
  ids <- scaleLLMflow:::rob2_item_ids()
  metadata <- scaleLLMflow:::resolve_prompt("rob2", "gpt-5.6-luna", provider = "openai")$metadata
  expect_false(any(sub("^Item_", "", removed) %in% ids))
  expect_false(any(removed %in% metadata$response_schema$required_item_keys))
  expect_false(any(sub("^Item_", "", removed) %in% names(metadata$scale_definition$items)))
  expect_equal(metadata$items, 29)
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
  expect_equal(metadata$selected_prompt, "scale")
  expect_equal(metadata$prompt_version, "v040")
  expect_equal(provenance$selected_prompt, "scale")
  expect_equal(provenance$prompt_version, "v040")
})

test_that("prompt snapshots record prompt version and hash", {
  resolved <- scaleLLMflow:::resolve_prompt("mqs", "gemini-3.6-flash")
  out <- tempfile(); dir.create(out)
  scaleLLMflow:::write_prompt_snapshot(out, "prompt text", resolved)
  snapshot <- paste(readLines(file.path(out, "prompt_used.md")), collapse = "\n")
  expect_match(snapshot, "PROMPT_VERSION:")
  expect_match(snapshot, paste0("PROMPT_SHA256: ", scaleLLMflow:::sha256_text("prompt text")))
})

test_that("Gemini structured output schema is generated from scale metadata", {
  metadata <- scaleLLMflow:::resolve_prompt("mqs", "gemini-3.6-flash")$metadata
  schema <- scaleLLMflow:::build_gemini_json_schema(metadata$response_schema)
  expect_equal(schema$type, "object")
  expect_equal(schema$properties$items$required, as.list(as.character(1:10)))
  expect_equal(schema$properties$items$properties[["1"]]$properties$decision$enum,
    c("0.0", "0.5", "1.0", "9.0"))
})

test_that("audit logs retain the complete raw LLM response", {
  log <- scaleLLMflow:::build_audit_log(
    "article", "openai", "gpt-4.1-mini", TRUE,
    "* Item 1: 1.0", "* Item 1: 1.0", items = 1,
    raw_response = '{"items":{"1":{"decision":"1.0","evidence":"quoted evidence","reason":"scoring reason"}}}'
  )
  expect_match(log, "RAW LLM RESPONSE")
  expect_match(log, "quoted evidence")
  expect_match(log, "scoring reason")
  expect_false(grepl("INDIVIDUAL ORDERED CALLS", log, fixed = TRUE))

  repeated_log <- scaleLLMflow:::build_audit_log(
    "article", "openai", "gpt-4.1-mini", TRUE,
    c("call one", "call two"), c("* Item 1: 1.0", "* Item 1: 1.0"),
    items = 1, calls_per_article = 2
  )
  expect_match(repeated_log, "INDIVIDUAL ORDERED CALLS")
})

test_that("registry audit validates definitions and proposes duplicate unifications", {
  audit <- audit_model_registry()
  expect_true(all(audit$checks$Status %in% c("OK", "INFO", "WARNING")))
  if (nrow(audit$unification_plan) > 0) {
    expect_true(all(audit$unification_plan$Action == "proposed"))
  }
})

testthat::test_that("prompt registry resolves scale-level prompts", {
  testthat::expect_true("mqs" %in% available_scales())
  testthat::expect_true("pedro" %in% available_scales())
  exact <- resolve_prompt("pedro", "gemini-2.5-flash")
  testthat::expect_equal(exact$selected_prompt, "scale")
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

test_that("auto file listing prefers a same-name Markdown cache", {
  dir <- tempfile(); dir.create(dir)
  file.create(file.path(dir, "study.pdf")); file.create(file.path(dir, "study.md"))
  file.create(file.path(dir, "other.pdf"))
  files <- scaleLLMflow:::list_article_files(dir, "auto")
  expect_equal(basename(files), c("other.pdf", "study.md"))
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

testthat::test_that("RoB 2 flat-line responses are validated and encoded", {
  metadata <- scaleLLMflow:::resolve_prompt("rob2", "test-model")$metadata
  ids <- scaleLLMflow:::rob2_item_ids()
  values <- c("assignment", rep("N", 28))
  values[c(5, 13, 18, 24, 28)] <- "Some"
  values[29] <- "High"
  response <- paste(sprintf("* Item %s: %s | Justification: quote", ids, values), collapse = "\n")
  scores <- scaleLLMflow:::parse_scale_scores(response, ids, metadata)
  testthat::expect_equal(scores[["Item_D1_1"]], 0)
  testthat::expect_equal(scores[["Item_D1_Judgement"]], 0.5)
  testthat::expect_equal(scores[["Item_Overall_Judgement"]], 1)
  testthat::expect_false("Item_Study_ID" %in% names(scores))
  testthat::expect_true(is.na(scaleLLMflow:::calculate_scale_total(scores, metadata)))
})

testthat::test_that("Markdown structuring accepts PDF list text on Windows", {
  structured <- scaleLLMflow::structure_article_markdown("Introduction\\n- participant\\n* outcome")
  testthat::expect_match(structured, "participant")
  testthat::expect_match(structured, "outcome")
})
