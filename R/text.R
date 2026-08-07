#' Remove reference sections from extracted article text.
#'
#' @param article_text Full extracted text.
#' @export
strip_references_section <- function(article_text) {
  article_text <- gsub("\r\n?", "\n", article_text)
  patterns <- c(
    "(?ims)\n\\s*references\\s*\n.*$",
    "(?ims)\n\\s*bibliography\\s*\n.*$",
    "(?ims)\n\\s*reference list\\s*\n.*$",
    "(?ims)\n\\s*literature cited\\s*\n.*$"
  )

  stripped_text <- article_text
  for (pattern in patterns) {
    candidate <- sub(pattern, "\n", stripped_text, perl = TRUE)
    if (nchar(candidate) < nchar(stripped_text)) {
      stripped_text <- candidate
      break
    }
  }

  if (identical(stripped_text, article_text)) {
    heading_matches <- gregexpr(
      "(?im)^[ \\t]*(?:[0-9]+[.)]?[ \\t]*)?(references|bibliography|reference list|literature cited)[ \\t]*$",
      article_text,
      perl = TRUE
    )[[1]]

    if (length(heading_matches) > 0 && heading_matches[[1]] != -1) {
      late_matches <- heading_matches[heading_matches > floor(nchar(article_text) * 0.55)]
      if (length(late_matches) > 0) {
        stripped_text <- substr(article_text, 1, late_matches[[length(late_matches)]] - 1)
      }
    }
  }

  stripped_text
}

#' Extract text from a PDF article.
#'
#' @param pdf_path Path to a PDF article.
#' @param strip_references Whether to remove the reference section before sending text to an LLM.
#' @export
extract_pdf_text <- function(pdf_path, strip_references = TRUE) {
  if (!file.exists(pdf_path)) {
    stop("PDF not found: ", pdf_path, call. = FALSE)
  }

  article_text <- paste(pdftools::pdf_text(pdf_path), collapse = "\n")
  if (isTRUE(strip_references)) {
    article_text <- strip_references_section(article_text)
  }

  article_text
}

#' Extract text from a supported article file.
#'
#' @param file_path Path to a `.pdf`, `.txt`, or `.md` article file.
#' @param filetype One of `"auto"`, `"pdf"`, `"txt"`, or `"md"`.
#' @param strip_references Whether to remove the reference section before sending text to an LLM.
#' @details Files are read from the local filesystem. PDF, TXT, and Markdown
#' inputs are supported.
#' @export
extract_article_text <- function(file_path, filetype = "auto", strip_references = TRUE) {
  if (!file.exists(file_path)) {
    stop("Article file not found: ", file_path, call. = FALSE)
  }

  filetype <- validate_filetype(filetype)
  if (filetype == "auto") {
    filetype <- tolower(tools::file_ext(file_path))
  }
  if (!filetype %in% c("pdf", "txt", "md")) {
    stop("Unsupported filetype: ", filetype, ". Use 'pdf', 'txt', 'md', or 'auto'.", call. = FALSE)
  }

  if (filetype == "pdf") {
    return(extract_pdf_text(file_path, strip_references = strip_references))
  }

  article_text <- paste(readLines(file_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (isTRUE(strip_references)) {
    article_text <- strip_references_section(article_text)
  }

  article_text
}

validate_filetype <- function(filetype) {
  filetype <- tolower(trimws(filetype))
  if (!filetype %in% c("auto", "pdf", "txt", "md")) {
    stop("filetype must be one of: auto, pdf, txt, md.", call. = FALSE)
  }

  filetype
}

list_article_files <- function(articles_dir, filetype = "auto") {
  filetype <- validate_filetype(filetype)
  pattern <- switch(
    filetype,
    auto = "\\.(pdf|txt|md)$",
    pdf = "\\.pdf$",
    txt = "\\.txt$",
    md = "\\.md$"
  )

  sort(list.files(articles_dir, pattern = pattern, full.names = TRUE, ignore.case = TRUE))
}

#' Append article text to a scale prompt.
#'
#' @param prompt_text Scale prompt text.
#' @param article_text Extracted article text.
#' @export
build_scale_prompt <- function(prompt_text, article_text) {
  paste(
    prompt_text,
    "--- ARTICLE TEXT START ---",
    article_text,
    "--- ARTICLE TEXT END ---",
    sep = "\n\n"
  )
}
