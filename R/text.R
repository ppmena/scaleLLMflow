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
  # PDF extraction may leave literal tabulators in otherwise plain text.
  # Normalize them without changing the original line/column ordering.
  raw_lines <- strsplit(gsub("\\r\\n?", "\\n", article_text), "\n", fixed = TRUE)[[1]]
  lines <- gsub("^[[:space:]]+|[[:space:]]+$", "",
    gsub("\\t+", " ", raw_lines))
  lines <- lines[nzchar(lines)]
  out <- character(0); i <- 1L
  heading <- "^(?:[0-9]+(?:\\.[0-9]+)*[.)]?|[IVXLC]+[.)])\\s+(.+)$"
  bullet <- "^(?:[-*•]|[0-9]+[.)])\\s+(.+)$"
  section_heading <- paste0(
    "^(abstract|resumen|introduction|background|objectives?|aims?|",
    "methods?|methodology|design|participants?|sample|procedure|",
    "intervention|measures?|instruments?|outcomes?|results?|",
    "discussion|conclusions?|limitations?|references|bibliography|",
    "statistical analysis|data analysis|appendix|supplementary materials)",
    "[[:space:]:.]*$"
  )
  is_heading <- function(x, position) {
    normalized <- tolower(gsub("[:.]$", "", trimws(x)))
    grepl("^#{1,6}\\s+", x) || grepl(heading, x, perl = TRUE) ||
      normalized %in% c("abstract", "resumen", "introduction", "background", "objectives", "aims", "methods", "methodology", "design", "participants", "sample", "procedure", "intervention", "measures", "instruments", "outcomes", "results", "discussion", "conclusions", "limitations", "references", "bibliography", "statistical analysis", "data analysis", "appendix", "supplementary materials") ||
      grepl(section_heading, trimws(x), perl = TRUE, ignore.case = TRUE) ||
      (position <= 3L && nchar(x) >= 8L && nchar(x) <= 180L && !grepl("[.!?]$", x) && grepl("[A-Za-z]", x))
  }
  while (i <= length(lines)) {
    x <- lines[[i]]
    if (is_heading(x, i)) {
      if (grepl("^#{1,6}\\s+", x)) out <- c(out, x)
      else {
        label <- if (grepl(heading, x, perl = TRUE)) sub(heading, "\\1", x, perl = TRUE) else x
        level <- if (i <= 3L || grepl("^(?:abstract|introduction|methods?|results?|discussion|conclusions?)", label, ignore.case = TRUE)) 2 else 3
        out <- c(out, paste0(strrep("#", level), " ", trimws(label)))
      }
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

#' Convert extracted article text to faithful Markdown with an LLM.
#' @param article_text Extracted article text.
#' @param provider LLM provider.
#' @param model Provider model.
#' @param temperature Sampling temperature.
#' @param prompt Optional local conversion prompt.
#' @param ... Additional provider call settings.
#' @export
convert_article_markdown_llm <- function(article_text, provider = "gemini",
                                          model = "gemini-3.6-flash", temperature = 0,
                                          prompt = NULL, ...) {
  if (is.null(prompt)) {
    prompt <- paste(
      "Convert the following PDF-extracted academic article into faithful Markdown.",
      "Reconstruct reading order for multi-column pages, preserve every word, number,", 
      "table and heading, and do not summarize, correct, or invent content.",
      "Use Markdown headings only when the source contains a real section heading.",
      "Represent tables as Markdown tables only when a table is clearly present.",
      "Return only the Markdown document, without commentary.",
      "--- SOURCE TEXT ---", article_text, "--- END SOURCE TEXT ---", sep = "\n\n"
    )
  }
  result <- run_llm(prompt, provider = provider, model = model,
    temperature = temperature, ...)
  result <- sub("^```(?:markdown|md)?\\s*", "", result, ignore.case = TRUE)
  result <- sub("\\s*```$", "", result)
  result
}

#' Extract text from a PDF article.
#'
#' @param pdf_path Path to a PDF article.
#' @param strip_references Whether to remove the reference section before sending text to an LLM.
#' @param tables_advanced Whether to apply local table heuristics.
#' @param cache_markdown Whether to cache PDF conversion beside the source PDF.
#' @param conversion PDF conversion mode: `"basic"` or `"llm"`. LLM conversion
#' usually produces better reading order and Markdown structure for multi-column articles.
#' @param provider,model,conversion_prompt,temperature LLM conversion settings.
#' @export
extract_pdf_text <- function(pdf_path, strip_references = TRUE, tables_advanced = TRUE,
                             cache_markdown = TRUE, conversion = "basic",
                             provider = "gemini", model = "gemini-3.6-flash",
                             conversion_prompt = NULL, temperature = 0, ...) {
  if (!file.exists(pdf_path)) {
    stop("PDF not found: ", pdf_path, call. = FALSE)
  }

  article_text <- paste(pdftools::pdf_text(pdf_path), collapse = "\n")
  if (isTRUE(strip_references)) {
    article_text <- strip_references_section(article_text)
  }

  conversion <- match.arg(conversion, c("basic", "llm"))
  markdown_text <- if (conversion == "llm") {
    convert_article_markdown_llm(article_text, provider = provider, model = model,
      temperature = temperature, prompt = conversion_prompt, ...)
  } else structure_article_markdown(article_text, tables_advanced = tables_advanced)
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
#' @param conversion PDF conversion mode passed to `extract_pdf_text()`.
#' @param provider,model,conversion_prompt,temperature LLM conversion settings.
#' @details Files are read from the local filesystem. PDF, TXT, and Markdown
#' inputs are supported.
#' @export
extract_article_text <- function(file_path, filetype = "auto", strip_references = TRUE,
                                 tables_advanced = TRUE, cache_markdown = TRUE,
                                 conversion = "basic", provider = "gemini",
                                 model = "gemini-3.6-flash", conversion_prompt = NULL,
                                 temperature = 0, ...) {
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
      tables_advanced = tables_advanced, cache_markdown = cache_markdown,
      conversion = conversion, provider = provider, model = model,
      conversion_prompt = conversion_prompt, temperature = temperature, ...))
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
