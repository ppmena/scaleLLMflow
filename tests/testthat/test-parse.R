test_that("get_mode works correctly", {
  expect_equal(get_mode(c(1, 2, 2, 3)), 2)
  expect_equal(get_mode(c(1, 1, NA, 3)), 1)
  expect_true(is.na(get_mode(c(NA, NA))))
})

test_that("get_item_score parses various score formats", {
  txt <- "* Item 1: 1.0 | Justification: Selection criteria are present.\n* Item 2: Score 0.5 | Justification: Partial data.\n* Item 3: 9.0 | Justification: Not applicable."

  expect_equal(get_item_score(1, txt), 1.0)
  expect_equal(get_item_score(2, txt), 0.5)
  expect_equal(get_item_score(3, txt), 9.0)
  expect_true(is.na(get_item_score(4, txt)))
})

test_that("extract_ordered_items handles multiline and formats correctly", {
  agent_output <- c(
    "* Item 1: 1.0\nJustification line 1\nJustification line 2\n",
    "* Item 2: 0.5\nSome other justification\n"
  )

  parsed <- extract_ordered_items(agent_output, items = 1:2)

  expect_equal(length(parsed), 2)
  expect_true(grepl("Item 1", parsed[[1]]))
  expect_true(grepl("Item 2", parsed[[2]]))
  expect_true(grepl("Justification line 1", parsed[[1]]))
})

test_that("strip_references_section handles safe stripping", {
  text_with_references <- "This is the introduction.\nThis is the discussion.\n\nReferences\n1. First citation\n2. Second citation"
  stripped <- strip_references_section(text_with_references)

  expect_true(grepl("discussion", stripped))
  expect_false(grepl("First citation", stripped))

  # Check that mentions of reference in mid-sentence are not stripped
  text_mid_sentence <- "In many past references we find that standardizing is good.\nThis is the end."
  not_stripped <- strip_references_section(text_mid_sentence)
  expect_true(grepl("past references", not_stripped))
  expect_true(grepl("This is the end", not_stripped))
})

test_that("resolve_prompt resolves exact and family fallbacks", {
  # Since registry_dir can be supplied, we can test with the package's built-in scales
  resolved <- resolve_prompt("mqs", "gemini-2.5-flash")
  expect_equal(resolved$scale, "mqs")
  expect_equal(resolved$selected_model, "gemini-2.5-flash")
  expect_equal(resolved$strategy, "exact")

  resolved_fallback <- resolve_prompt("mqs", "gemini-1.5-flash")
  expect_equal(resolved_fallback$scale, "mqs")
  expect_equal(resolved_fallback$strategy, "family:flash")
})
