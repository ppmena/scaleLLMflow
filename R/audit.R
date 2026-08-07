# Audit the local scale/model registry and optionally consolidate exact prompt
# duplicates. This operates only on local registry files.

prompt_hash <- function(path) {
  as.character(tools::md5sum(path))
}

# Return one row per registry check so the report is easy to save and inspect.
registry_check <- function(scale, model, check, status, message) {
  data.frame(Scale = scale, Model = model, Check = check, Status = status,
    Message = message, stringsAsFactors = FALSE)
}

#' Audit every registered scale and model prompt.
#'
#' @param registry_dir Optional registry root. Defaults to bundled prompts.
#' @param output_dir Optional directory for audit and unification CSV reports.
#' @param apply_unifications Move exact duplicate prompt folders to a timestamped
#' backup directory. Defaults to `FALSE`.
#' @return A list with checks, duplicate_groups, unification_plan, and backup_dir.
#' @export
audit_model_registry <- function(registry_dir = NULL, output_dir = NULL,
                                 apply_unifications = FALSE) {
  root <- registry_root(registry_dir)
  if (!dir.exists(root)) stop("Registry directory not found: ", root, call. = FALSE)
  if (!is.logical(apply_unifications) || length(apply_unifications) != 1) {
    stop("apply_unifications must be TRUE or FALSE.", call. = FALSE)
  }

  checks <- list()
  records <- list()
  for (scale in available_scales(root)) {
    scale_dir <- file.path(root, scale)
    models <- available_models(scale, root)
    if (length(models) == 0) {
      records[[length(records) + 1]] <- registry_check(scale, "", "model_folders", "ERROR", "No model folders found.")
      next
    }
    for (model in models) {
      model_dir <- file.path(scale_dir, model)
      prompt_path <- file.path(model_dir, "prompt.md")
      metadata_path <- file.path(model_dir, "metadata.json")
      if (!file.exists(prompt_path)) {
        records[[length(records) + 1]] <- registry_check(scale, model, "prompt", "ERROR", "Missing prompt.md.")
        next
      }
      if (!file.exists(metadata_path)) {
        records[[length(records) + 1]] <- registry_check(scale, model, "metadata", "ERROR", "Missing metadata.json.")
        next
      }
      metadata <- tryCatch(read_prompt_metadata(model_dir), error = function(e) e)
      if (inherits(metadata, "condition")) {
        records[[length(records) + 1]] <- registry_check(scale, model, "metadata_json", "ERROR", conditionMessage(metadata))
        next
      }
      records[[length(records) + 1]] <- registry_check(scale, model, "files", "OK", "prompt.md and metadata.json are present.")
      if (!identical(tolower(as.character(metadata$scale)), tolower(scale))) {
        records[[length(records) + 1]] <- registry_check(scale, model, "metadata_scale", "ERROR", "metadata scale does not match its folder.")
      }
      if (!is.null(metadata$model) && !identical(tolower(as.character(metadata$model)), tolower(model))) {
        records[[length(records) + 1]] <- registry_check(scale, model, "metadata_model", "WARNING", "metadata model differs from its folder.")
      }
      definition_result <- tryCatch({ validate_scale_definition(metadata); NULL }, error = function(e) e)
      records[[length(records) + 1]] <- registry_check(scale, model, "scale_definition",
        if (is.null(definition_result)) "OK" else "ERROR",
        if (is.null(definition_result)) "Formal item and total definition is valid." else conditionMessage(definition_result))
      schema <- metadata$response_schema
      if (is.null(schema) || is.null(schema$required_item_keys)) {
        records[[length(records) + 1]] <- registry_check(scale, model, "response_schema", "ERROR", "Missing response_schema.required_item_keys.")
      } else {
        records[[length(records) + 1]] <- registry_check(scale, model, "response_schema", "OK", "Response schema declares required items.")
      }
      records[[length(records) + 1]] <- registry_check(scale, model, "prompt_hash", "INFO", prompt_hash(prompt_path))
    }
  }
  checks_df <- do.call(rbind, records)

  prompt_rows <- checks_df[checks_df$Check == "prompt_hash", , drop = FALSE]
  duplicate_groups <- data.frame(Hash = character(), Scale = character(), Models = character(), stringsAsFactors = FALSE)
  unification_plan <- data.frame(Hash = character(), Scale = character(), Canonical_Model = character(), Duplicate_Model = character(), Action = character(), stringsAsFactors = FALSE)
  if (nrow(prompt_rows) > 0) {
    keys <- unique(paste(prompt_rows$Scale, prompt_rows$Message, sep = "\r"))
    for (key in keys) {
      parts <- strsplit(key, "\r", fixed = TRUE)[[1]]
      rows <- prompt_rows[prompt_rows$Scale == parts[[1]] & prompt_rows$Message == parts[[2]], , drop = FALSE]
      if (nrow(rows) > 1) {
        canonical <- sort(rows$Model)[[1]]
        duplicates <- sort(setdiff(rows$Model, canonical))
        duplicate_groups <- rbind(duplicate_groups, data.frame(
          Hash = parts[[2]], Scale = parts[[1]], Models = paste(sort(rows$Model), collapse = ", "), stringsAsFactors = FALSE))
        for (duplicate in duplicates) unification_plan <- rbind(unification_plan, data.frame(
          Hash = parts[[2]], Scale = parts[[1]], Canonical_Model = canonical,
          Duplicate_Model = duplicate, Action = if (isTRUE(apply_unifications)) "moved_to_backup" else "proposed", stringsAsFactors = FALSE))
      }
    }
  }

  backup_dir <- NULL
  if (isTRUE(apply_unifications) && nrow(unification_plan) > 0) {
    backup_dir <- file.path(dirname(root), paste0(basename(root), "_unified_backup_", format(Sys.time(), "%Y%m%d_%H%M%S")))
    dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
    for (i in seq_len(nrow(unification_plan))) {
      source <- file.path(root, unification_plan$Scale[[i]], unification_plan$Duplicate_Model[[i]])
      destination <- file.path(backup_dir, unification_plan$Scale[[i]], unification_plan$Duplicate_Model[[i]])
      dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      if (dir.exists(source)) file.rename(source, destination)
    }
  }
  if (!is.null(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    utils::write.csv2(checks_df, file.path(output_dir, "registry_audit.csv"), row.names = FALSE)
    utils::write.csv2(duplicate_groups, file.path(output_dir, "duplicate_prompt_groups.csv"), row.names = FALSE)
    utils::write.csv2(unification_plan, file.path(output_dir, "prompt_unification_plan.csv"), row.names = FALSE)
  }
  list(checks = checks_df, duplicate_groups = duplicate_groups,
    unification_plan = unification_plan, backup_dir = backup_dir)
}
