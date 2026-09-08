format_scale_score <- function(score) {
  if (is.na(score)) {
    return("NA")
  }

  digits <- if (abs(as.numeric(score) * 10 - round(as.numeric(score) * 10)) > 1e-8) 2 else 1
  formatC(as.numeric(score), format = "f", digits = digits)
}

rob2_item_ids <- function() {
  c("Study_ID", "Experimental_Group", "Comparator_Group", "Variable_Outcome",
    "Result_Numerical", "Effect_Interest", "D1_1", "D1_2", "D1_3",
    "D1_Judgement", "D2_1", "D2_2", "D2_3", "D2_4", "D2_5", "D2_6",
    "D2_7", "D2_Judgement", "D3_1", "D3_2", "D3_3", "D3_4",
    "D3_Judgement", "D4_1", "D4_2", "D4_3", "D4_4", "D4_5",
    "D4_Judgement", "D5_1", "D5_2", "D5_3", "D5_Judgement",
    "Overall_Judgement")
}

rob2_decision_score <- function(decision) {
  decision <- trimws(as.character(decision))
  if (decision %in% c("NA", "N/A")) return(NA_real_)
  scores <- c("N" = 0, "PN" = 0.25, "NI" = 0.5, "PY" = 0.75, "Y" = 1,
    "Low" = 0, "Some" = 0.5, "High" = 1, "assignment" = 1, "adherence" = 1)
  if (!decision %in% names(scores)) return(NA_real_)
  unname(scores[[decision]])
}

parse_rob2_lines <- function(text, schema) {
  lines <- strsplit(gsub("\\r\\n?", "\\n", text), "\\n")[[1]]
  keys <- as.character(unlist(schema$required_item_keys, use.names = FALSE))
  out <- setNames(vector("list", length(keys)), keys)
  for (line in lines) {
    hit <- stringr::str_match(line, "^\\s*\\*\\s*Item\\s+([A-Za-z][A-Za-z0-9_]*)\\s*:\\s*(.*?)\\s*\\|\\s*Justification:\\s*(.*)$")
    if (is.na(hit[1, 2])) next
    key <- hit[1, 2]
    decision <- trimws(hit[1, 3])
    decision_map <- c("Probably Yes" = "PY", "Probably No" = "PN",
      "No Information" = "NI", "Not Applicable" = "NA",
      "Low risk of bias" = "Low", "Some concerns" = "Some",
      "High risk of bias" = "High")
    if (decision %in% names(decision_map)) decision <- unname(decision_map[[decision]])
    if (key %in% keys) out[[key]] <- list(decision = decision, evidence = trimws(hit[1, 4]), reason = trimws(hit[1, 4]))
  }
  if (any(vapply(out, is.null, logical(1)))) stop("RoB 2 response is missing required item(s).", call. = FALSE)
  list(items = out)
}

# Validate the scientific scale contract before any article is scored.
validate_scale_definition <- function(metadata) {
  definition <- metadata$scale_definition
  if (is.null(definition) || is.null(definition$items) || !is.list(definition$items)) {
    stop("Prompt metadata is missing scale_definition.items.", call. = FALSE)
  }
  for (key in names(definition$items)) {
    item <- definition$items[[key]]
    if (is.null(item$label) || is.null(item$allowed_values) ||
        is.null(item$included_in_total)) {
      stop("Scale definition for item ", key,
        " must include label, allowed_values, and included_in_total.", call. = FALSE)
    }
  }
  total <- definition$total
  if (is.null(total$method) || !total$method %in% c("sum", "none")) {
    stop("Scale total method must be 'sum' or 'none'.", call. = FALSE)
  }
  total_items <- as.character(unlist(total$items, use.names = FALSE))
  defined_items <- names(definition$items)
  if (!all(total_items %in% defined_items)) {
    stop("Scale total references undefined item(s).", call. = FALSE)
  }
  invisible(TRUE)
}

# Calculate the official score from the formal scale definition. NA values are
# ignored only when the metadata explicitly declares that policy.
calculate_scale_total <- function(scores, metadata) {
  validate_scale_definition(metadata)
  total <- metadata$scale_definition$total
  if (identical(total$method, "none")) return(NA_real_)
  total_items <- as.character(unlist(total$items, use.names = FALSE))
  selected <- as.numeric(scores[paste0("Item_", total_items)])
  excluded_values <- as.numeric(unlist(total$excluded_values, use.names = FALSE))
  if (length(excluded_values) > 0) selected <- selected[!selected %in% excluded_values]
  if (anyNA(selected) && !identical(total$na_policy, "ignore")) return(NA_real_)
  sum(selected, na.rm = TRUE)
}

# Ensure parsed values conform to the scientific definition, independently of
# the LLM response parser and prompt wording.
validate_scale_scores <- function(scores, items, metadata) {
  validate_scale_definition(metadata)
  definition <- metadata$scale_definition$items
  free_text <- as.character(unlist(metadata$response_schema$free_text_items, use.names = FALSE))
  for (item in as.character(items)) {
    if (item %in% free_text) next
    value <- scores[[paste0("Item_", item)]]
    allowed <- as.numeric(unlist(definition[[item]]$allowed_values, use.names = FALSE))
    if (!is.na(value) && !value %in% allowed) {
      stop("Invalid score ", value, " for item ", item,
        ". Allowed values: ", paste(allowed, collapse = ", "), call. = FALSE)
    }
  }
  invisible(TRUE)
}

# Return evidence and reasons as a flat, review-friendly table. This keeps the
# human-readable rationale separate from the raw provider response.
extract_scale_evidence <- function(text, items, metadata) {
  response <- validate_scale_response(text, metadata, items)
  key_map <- metadata$response_schema$item_key_map
  rows <- lapply(items, function(item_number) {
    key <- as.character(item_number)
    if (!is.null(key_map)) key <- as.character(key_map[[key]])
    item <- response$items[[key]]
    data.frame(
      Item = paste0("Item_", item_number),
      Decision = as.character(item$decision),
      Evidence = as.character(item$evidence),
      Reason = as.character(item$reason),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

# Parse a response as one JSON document.  Strict scale prompts must return
# JSON only; accepting Markdown fences here would hide prompt violations.
parse_strict_json <- function(text) {
  if (is.null(text) || length(text) != 1 || !nzchar(trimws(text))) {
    stop("The LLM returned an empty response; expected one JSON document.", call. = FALSE)
  }
  # Some providers still wrap structured output in a complete Markdown JSON
  # fence despite response_format. Remove only a matching outer fence; any
  # other extra text remains invalid and is rejected below.
  normalized <- trimws(text)
  if (grepl("^```(?:json)?\\s*", normalized, perl = TRUE, ignore.case = TRUE) &&
      grepl("```\\s*$", normalized, perl = TRUE)) {
    normalized <- sub("^```(?:json)?\\s*", "", normalized, perl = TRUE, ignore.case = TRUE)
    normalized <- sub("```\\s*$", "", normalized, perl = TRUE)
    normalized <- trimws(normalized)
  }
  # Gemini can occasionally omit the opening fence while retaining the
  # closing fence.  Remove that single terminal marker only; all other
  # trailing content remains invalid and is reported by the JSON parser.
  normalized <- sub("```\\s*$", "", normalized, perl = TRUE)
  normalized <- trimws(normalized)
  parsed <- tryCatch(jsonlite::fromJSON(normalized, simplifyVector = FALSE),
    error = function(e) stop("The LLM response is not valid JSON: ", conditionMessage(e), call. = FALSE))
  if (!is.list(parsed)) {
    stop("The LLM response must be a JSON object.", call. = FALSE)
  }
  parsed
}

# Validate the scale-specific response contract declared in metadata.json.
# The validator deliberately fails closed: malformed or incomplete ratings
# must be retried/reviewed instead of silently becoming missing scores.
validate_scale_response <- function(text, metadata, items) {
  schema <- metadata$response_schema
  if (!is.null(schema) && identical(schema$type, "rob2_lines")) {
    response <- parse_rob2_lines(text, schema)
    allowed <- as.character(unlist(schema$allowed_decisions, use.names = FALSE))
    for (key in schema$required_item_keys) {
      if (key %in% as.character(unlist(schema$free_text_items, use.names = FALSE))) next
      if (!response$items[[key]]$decision %in% allowed) stop("Invalid RoB 2 decision for ", key, ".", call. = FALSE)
    }
    return(response)
  }
  response <- parse_strict_json(text)
  schema <- metadata$response_schema
  if (is.null(schema) || identical(schema$type, "legacy_lines")) return(response)

  # OpenAI Responses models may return the schema's item properties directly
  # when structured output is not enabled by the account/model. Wrap that
  # exact, complete item object without accepting missing or extra content.
  required <- as.character(unlist(schema$required_item_keys, use.names = FALSE))
  if (is.null(response$items) && setequal(names(response), required)) {
    response <- list(items = response)
  }

  if (!identical(schema$type, "object") || is.null(response$items) || !is.list(response$items)) {
    stop("Response does not match the registered JSON schema: expected an 'items' object.", call. = FALSE)
  }
  required <- unlist(schema$required_item_keys, use.names = FALSE)
  missing <- setdiff(required, names(response$items))
  if (length(missing) > 0) {
    stop("Response is missing required item(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  allowed <- unlist(schema$allowed_decisions, use.names = FALSE)
  for (key in required) {
    item <- response$items[[key]]
    if (!is.list(item) || is.null(item$decision) || length(item$decision) != 1 ||
        !as.character(item$decision) %in% allowed) {
      stop("Invalid decision for ", key, ". Allowed values: ", paste(allowed, collapse = ", "), call. = FALSE)
    }
    for (field in schema$required_item_fields) {
      if (is.null(item[[field]]) || length(item[[field]]) != 1 || !is.character(item[[field]])) {
        stop("Missing or invalid field '", field, "' for ", key, ".", call. = FALSE)
      }
    }
  }
  response
}

get_mode <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }

  unique_values <- unique(x)
  unique_values[which.max(tabulate(match(x, unique_values)))]
}

extract_ordered_items <- function(agent_outputs, items = 1:10) {
  safe_outputs <- vapply(agent_outputs, function(x) {
    if (is.null(x) || length(x) == 0 || all(is.na(x))) {
      return("")
    }
    paste(x, collapse = "\n")
  }, character(1))

  combined_text <- gsub("\r\n?", "\n", paste(safe_outputs, collapse = "\n\n"))
  item_pattern <- "(?ims)^\\s*(?:[\\*-]\\s*)?Item\\s*(\\d{1,2})\\s*:\\s*.*?(?=^\\s*(?:[\\*-]\\s*)?Item\\s*\\d{1,2}\\s*:|\\z)"
  item_blocks <- regmatches(combined_text, gregexpr(item_pattern, combined_text, perl = TRUE))[[1]]

  ordered_items <- rep(NA_character_, length(items))
  names(ordered_items) <- as.character(items)

  if (length(item_blocks) > 0) {
    for (block in item_blocks) {
      item_match <- stringr::str_match(block, "(?i)Item\\s*(\\d{1,2})")[, 2]
      item_number <- if (is.na(item_match)) "" else item_match
      if (item_number %in% names(ordered_items) && is.na(ordered_items[[item_number]])) {
        clean_block <- stringr::str_squish(block)
        clean_block <- sub(
          "^\\s*(?:[\\*-]\\s*)?Item\\s*\\d{1,2}\\s*:",
          paste0("* Item ", item_number, ":"),
          clean_block,
          perl = TRUE,
          ignore.case = TRUE
        )
        ordered_items[[item_number]] <- clean_block
      }
    }
  }

  vapply(items, function(item_number) {
    item_text <- ordered_items[[as.character(item_number)]]
    if (!is.na(item_text) && nzchar(item_text)) {
      return(item_text)
    }
    paste0("* Item ", item_number, ": ERROR | Justification: No valid agent output detected for this item.")
  }, character(1))
}

get_item_score <- function(item_number, txt) {
  if (is.null(txt) || length(txt) == 0 || all(is.na(txt))) {
    return(NA_real_)
  }

  txt <- gsub("\r\n?", "\n", paste(txt, collapse = "\n"))
  if (grepl('"items"\\s*:', txt, perl = TRUE)) {
    pedro_keys <- c("eligibility_criteria", "random_allocation", "concealed_allocation",
      "baseline_comparability", "blind_subjects", "blind_therapists", "blind_assessors",
      "adequate_follow_up", "intention_to_treat_analysis", "between_group_comparisons",
      "point_estimates_and_variability")
    json <- tryCatch(jsonlite::fromJSON(txt), error = function(e) NULL)
    key <- pedro_keys[[as.integer(item_number)]]
    if (!is.null(json) && !is.null(key) && !is.null(json$items[[key]])) {
      decision <- tolower(trimws(as.character(json$items[[key]]$decision)))
      if (length(decision) != 1L) {
        stop("Invalid decision for item ", item_number, ": expected one value, received ",
          length(decision), ".", call. = FALSE)
      }
      if (decision %in% c("yes", "no")) return(ifelse(decision == "yes", 1, 0))
    }
  }
  item_pattern <- paste0(
    "(?ims)(?:^|\\n)\\s*(?:[\\*-]\\s*)?Item\\s*",
    item_number,
    "\\s*:\\s*(?:Score\\s*)?([0-9](?:[\\.,][0-9]{1,2})?)\\b"
  )

  score_match <- stringr::str_match(txt, item_pattern)
  if (is.na(score_match[1, 2])) {
    return(NA_real_)
  }

  as.numeric(stringr::str_replace(score_match[1, 2], ",", "."))
}

# Convert a validated JSON response into the numeric encoding used by the
# existing CSV and audit-log outputs.
json_item_score <- function(item_number, response, metadata) {
  key <- as.character(item_number)
  key_map <- metadata$response_schema$item_key_map
  if (!is.null(key_map)) key <- as.character(key_map[[key]])
  decision <- response$items[[key]]$decision
  if (length(decision) != 1L) {
    stop("Invalid decision for ", key, ": expected one value, received ",
      length(decision), ".", call. = FALSE)
  }
  if (tolower(decision) %in% c("yes", "no")) return(ifelse(tolower(decision) == "yes", 1, 0))
  if (identical(metadata$response_schema$type, "rob2_lines")) return(rob2_decision_score(decision))
  as.numeric(decision)
}

#' Parse scale item scores from an LLM response.
#'
#' @param text LLM response text.
#' @param items Numeric item ids to parse. Defaults to 1:10.
#' @param metadata Optional resolved scale metadata.
#' @export
parse_scale_scores <- function(text, items = 1:10, metadata = NULL) {
  if (!is.null(metadata) && !is.null(metadata$response_schema) &&
      !identical(metadata$response_schema$type, "legacy_lines")) {
    response <- validate_scale_response(text, metadata, items)
    scores <- vapply(items, json_item_score, numeric(1), response = response, metadata = metadata)
    names(scores) <- paste0("Item_", items)
    return(scores)
  }
  scores <- vapply(items, function(item_number) get_item_score(item_number, text), numeric(1))
  names(scores) <- paste0("Item_", items)
  scores
}

build_consensus_ordered_log <- function(calls_list, items = 1:10) {
  ordered_items <- vapply(items, function(item_number) {
    scores <- sapply(calls_list, function(txt) get_item_score(item_number, txt))
    consensus_score <- get_mode(scores)
    paste0("* Item ", item_number, ": ", format_scale_score(consensus_score))
  }, character(1))

  paste(ordered_items, collapse = "\n\n")
}

build_consensus_record <- function(clean_id, current_name, calls_list, items = 1:10,
                                   metadata = NULL) {
  temp_scores <- data.frame()

  if (length(calls_list) > 0) {
    for (txt in calls_list) {
      scores <- sapply(items, function(x) get_item_score(x, txt))
      if (!all(is.na(scores))) {
        temp_scores <- rbind(temp_scores, as.data.frame(t(scores)))
      }
    }
  }

  if (nrow(temp_scores) == 0) {
    return(NULL)
  }

  colnames(temp_scores) <- paste0("Item_", items)
  consensus <- sapply(temp_scores, get_mode)
  consensus_df <- as.data.frame(as.list(consensus), stringsAsFactors = FALSE)
  colnames(consensus_df) <- paste0("Item_", items)

  if (!is.null(metadata)) {
    consensus_scores <- unlist(consensus_df[1, paste0("Item_", items)], use.names = TRUE)
    validate_scale_scores(consensus_scores, items, metadata)
    consensus_df$Total_Score <- calculate_scale_total(consensus_scores, metadata)
  }

  cbind(
    data.frame(ID = clean_id, stringsAsFactors = FALSE),
    consensus_df,
    data.frame(Original_File = current_name, stringsAsFactors = FALSE)
  )
}
