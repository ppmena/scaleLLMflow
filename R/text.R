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

#' Convert extracted text to Markdown headings, lists, and tables.
#' @param article_text Extracted article text.
#' @param tables_advanced Whether to convert table-like blocks.
#' @export
structure_article_markdown <- function(article_text, tables_advanced = TRUE) {
  if (!is.logical(tables_advanced) || length(tables_advanced) != 1) stop("tables_advanced must be TRUE or FALSE.", call. = FALSE)
  lines <- trimws(gsub("\\r\\n?", "\\n", article_text))
  lines <- lines[nzchar(lines)]
  out <- character(0); i <- 1L
  heading <- "^(?:[0-9]+(?:\\.[0-9]+)*[.)]?|[IVXLC]+[.)])\\s+(.+)$"
  bullet <- "^(?:[-*•]|[0-9]+[.)])\\s+(.+)$"
  while (i <= length(lines)) {
    x <- lines[[i]]
    if (grepl("^#{1,6}\\s", x)) out <- c(out, x)
    else if (grepl("^[A-Z][A-Z0-9 ,:;()&/-]{3,}$", x) || grepl(heading, x, perl=TRUE)) {
      label <- if (grepl(heading, x, perl=TRUE)) sub(heading, "\\1", x, perl=TRUE) else x
      out <- c(out, paste0("## ", label))
    } else if (grepl(bullet, x, perl=TRUE)) out <- c(out, paste0("- ", sub(bullet, "\\1", x, perl=TRUE)))
    else if (isTRUE(tables_advanced) && i < length(lines) && (grepl("  ", x, fixed=TRUE) || grepl("\\t", x, fixed=TRUE)) && (grepl("  ", lines[[i+1L]], fixed=TRUE) || grepl("\\t", lines[[i+1L]], fixed=TRUE))) {
      block <- character(0)
      while (i <= length(lines) && (grepl("  ", lines[[i]], fixed=TRUE) || grepl("\\t", lines[[i]], fixed=TRUE))) { block <- c(block, lines[[i]]); i <- i + 1L }
      rows <- lapply(block, function(z) trimws(strsplit(z, "(?:\\t|\\s{2,})", perl=TRUE)[[1]]))
      width <- max(lengths(rows)); rows <- lapply(rows, function(z) c(z, rep("", width-length(z))))
      out <- c(out, paste0("| ", paste(rows[[1]], collapse=" | "), " |"), paste0("| ", paste(rep("---", width), collapse=" | "), " |"), vapply(rows[-1], function(z) paste0("| ", paste(z, collapse=" | "), " |"), character(1)))
      next
    } else out <- c(out, x)
    i <- i + 1L
  }
  paste(out, collapse="\n\n")
}

#' Extract text from a PDF article.
#'
#' @param pdf_path Path to a PDF article.
#' @param strip_references Whether to remove the reference section before sending text to an LLM.
#' @export
extract_pdf_text <- function(pdf_path, strip_references = TRUE, tables_advanced = TRUE,
                             cache_markdown = TRUE) {
  if (!file.exists(pdf_path)) {
    stop("PDF not found: ", pdf_path, call. = FALSE)
  }

  article_text <- paste(pdftools::pdf_text(pdf_path), collapse = "\n")
  if (isTRUE(strip_references)) {
    article_text <- strip_references_section(article_text)
  }

  markdown_text <- structure_article_markdown(article_text, tables_advanced = tables_advanced)
  if (isTRUE(cache_markdown)) {
    md_path <- file.path(dirname(pdf_path), paste0(tools::file_path_sans_ext(basename(pdf_path)), ".md"))
    writeLines(markdown_text, md_path, useBytes = TRUE)
  }
  markdown_text
}

#' Extract text from a supported article file.
#'
#' @param file_path Path to a `.pdf`, `.txt`, or `.md` article file.
#' @param filetype One of `"auto"`, `"pdf"`, `"txt"`, or `"md"`.
#' @param strip_references Whether to remove the reference section before sending text to an LLM.
#' @details Files are read from the local filesystem. PDF, TXT, and Markdown
#' inputs are supported.
#' @export
extract_article_text <- function(file_path, filetype = "auto", strip_references = TRUE,
                                 tables_advanced = TRUE, cache_markdown = TRUE) {
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
    return(extract_pdf_text(file_path, strip_references = strip_references,
      tables_advanced = tables_advanced, cache_markdown = cache_markdown))
  }

  article_text <- paste(readLines(file_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (isTRUE(strip_references)) {
    article_text <- strip_references_section(article_text)
  }

  structure_article_markdown(article_text, tables_advanced = tables_advanced)
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

  files <- sort(list.files(articles_dir, pattern = pattern, full.names = TRUE, ignore.case = TRUE))
  if (filetype == "auto" && length(files) > 0) {
    extensions <- tolower(tools::file_ext(files))
    basenames <- tolower(basename(files))
    md_names <- paste0(tools::file_path_sans_ext(basenames[extensions == "md"]), ".pdf")
    pdf_names <- paste0(tools::file_path_sans_ext(basenames), ".pdf")
    keep_pdf <- !(extensions == "pdf" & pdf_names %in% md_names)
    files <- files[keep_pdf]
  }
  files
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
