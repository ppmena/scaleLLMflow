format_scale_score <- function(score) {
  if (is.na(score)) {
    return("NA")
  }

  sprintf("%.1f", as.numeric(score))
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
      if (decision %in% c("yes", "no")) return(ifelse(decision == "yes", 1, 0))
    }
  }
  item_pattern <- paste0(
    "(?ims)(?:^|\\n)\\s*(?:[\\*-]\\s*)?Item\\s*",
    item_number,
    "\\s*:\\s*(?:Score\\s*)?([0-9](?:[\\.,][0-9])?)\\b"
  )

  score_match <- stringr::str_match(txt, item_pattern)
  if (is.na(score_match[1, 2])) {
    return(NA_real_)
  }

  as.numeric(stringr::str_replace(score_match[1, 2], ",", "."))
}

#' Parse scale item scores from an LLM response.
#'
#' @param text LLM response text.
#' @param items Numeric item ids to parse. Defaults to 1:10.
#' @export
parse_scale_scores <- function(text, items = 1:10) {
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

build_consensus_record <- function(clean_id, current_name, calls_list, items = 1:10) {
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

  cbind(
    data.frame(ID = clean_id, stringsAsFactors = FALSE),
    consensus_df,
    data.frame(Original_File = current_name, stringsAsFactors = FALSE)
  )
}
