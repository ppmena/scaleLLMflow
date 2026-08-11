registry_root <- function(registry_dir = NULL) {
  if (!is.null(registry_dir) && nzchar(registry_dir)) {
    return(normalizePath(registry_dir, winslash = "/", mustWork = FALSE))
  }

  system.file("scales", package = "scaleLLMflow")
}

list_dirs <- function(path) {
  if (!dir.exists(path)) {
    return(character(0))
  }

  basename(list.dirs(path, full.names = TRUE, recursive = FALSE))
}

normalize_model_name <- function(model) {
  tolower(gsub("[^a-z0-9.]+", "-", trimws(model)))
}

model_tokens <- function(model) {
  tokens <- unlist(strsplit(normalize_model_name(model), "[-_./]+"))
  tokens[nzchar(tokens)]
}

model_versions <- function(model) {
  hits <- gregexpr("[0-9]+(?:\\.[0-9]+)+", model, perl = TRUE)[[1]]
  if (length(hits) == 0 || hits[1] == -1) {
    return(character(0))
  }

  regmatches(model, list(hits))[[1]]
}

read_prompt_metadata <- function(model_dir) {
  metadata_path <- file.path(model_dir, "metadata.json")
  if (!file.exists(metadata_path)) {
    return(list())
  }

  jsonlite::read_json(metadata_path, simplifyVector = TRUE)
}

#' List scales available in the local prompt registry.
#'
#' @param registry_dir Optional registry root. Defaults to bundled package prompts.
#' @export
available_scales <- function(registry_dir = NULL) {
  list_dirs(registry_root(registry_dir))
}

#' List trained or fallback model prompt folders for a scale.
#'
#' @param scale Scale name, for example `"mqs"`.
#' @param registry_dir Optional registry root. Defaults to bundled package prompts.
#' @export
available_models <- function(scale, registry_dir = NULL) {
  scale_dir <- file.path(registry_root(registry_dir), tolower(scale))
  list_dirs(scale_dir)
}

#' Resolve the best prompt registered for a scale and requested model.
#'
#' Resolution order is exact model, same model family token, same numeric version,
#' `generic`, and finally closest available folder name by edit distance.
#'
#' @param scale Scale name, for example `"mqs"`.
#' @param model Requested model name.
#' @param provider Optional provider. When supplied, `<provider>-generic` is
#'   preferred after model-specific matching.
#' @param registry_dir Optional registry root. Defaults to bundled package prompts.
#' @return A list containing prompt path, model folder, match strategy, and metadata.
#' @export
resolve_prompt <- function(scale, model, provider = NULL, registry_dir = NULL) {
  root <- registry_root(registry_dir)
  scale_name <- tolower(scale)
  scale_dir <- file.path(root, scale_name)
  requested <- normalize_model_name(model)
  available <- available_models(scale_name, root)

  if (length(available) == 0) {
    stop("No prompt registry found for scale: ", scale_name, call. = FALSE)
  }

  choose <- function(folder, strategy) {
    prompt_path <- file.path(scale_dir, folder, "prompt.md")
    if (!file.exists(prompt_path)) {
      stop("Prompt folder exists but prompt.md is missing: ", folder, call. = FALSE)
    }

    result <- list(
      scale = scale_name,
      requested_model = model,
      selected_model = folder,
      strategy = strategy,
      prompt_path = normalizePath(prompt_path, winslash = "/", mustWork = TRUE),
      metadata = read_prompt_metadata(file.path(scale_dir, folder))
    )
    validate_scale_definition(result$metadata)
    result
  }

  exact_idx <- which(normalize_model_name(available) == requested)
  if (length(exact_idx) > 0) {
    return(choose(available[[exact_idx[[1]]]], "exact"))
  }

  tokens <- setdiff(model_tokens(requested), c("gemini", "gpt", "openai", "model"))
  family_tokens <- c("flash", "pro", "turbo", "mini", "nano", "preview")
  requested_family <- intersect(tokens, family_tokens)
  if (length(requested_family) > 0) {
    family_hits <- available[vapply(
      available,
      function(x) any(requested_family %in% model_tokens(x)),
      logical(1)
    )]
    family_hits <- setdiff(family_hits, "generic")
    if (length(family_hits) > 0) {
      return(choose(family_hits[[1]], paste0("family:", requested_family[[1]])))
    }
  }

  versions <- model_versions(requested)
  if (length(versions) > 0) {
    version_hits <- available[vapply(
      available,
      function(x) any(model_versions(x) %in% versions),
      logical(1)
    )]
    version_hits <- setdiff(version_hits, "generic")
    if (length(version_hits) > 0) {
      return(choose(version_hits[[1]], paste0("version:", versions[[1]])))
    }
  }

  generic_idx <- which(normalize_model_name(available) == "generic")
  if (!is.null(provider)) {
    provider_generic <- paste0(normalize_model_name(provider_alias(provider)), "-generic")
    provider_idx <- which(normalize_model_name(available) == provider_generic)
    if (length(provider_idx) > 0) {
      return(choose(available[[provider_idx[[1]]]], paste0("provider:", provider_alias(provider))))
    }
  }
  if (length(generic_idx) > 0) {
    return(choose(available[[generic_idx[[1]]]], "generic"))
  }

  distances <- utils::adist(requested, normalize_model_name(available))
  nearest <- available[[which.min(distances)]]
  choose(nearest, "nearest-name")
}
