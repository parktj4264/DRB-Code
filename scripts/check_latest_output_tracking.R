#!/usr/bin/env Rscript

# Validate output tracking policy for git push:
# - At most one tracked output/results_<timestamp> directory.
# - If local results_* directories exist and one is tracked, tracked one must be latest.

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1) args[[1]] else "."
repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)

output_dir <- file.path(repo_root, "output")
if (!dir.exists(output_dir)) {
  quit(save = "no", status = 0)
}

local_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = FALSE)
local_result_dirs <- local_dirs[grepl("^results_[0-9]{6}_[0-9]{6}$", local_dirs)]
local_latest <- if (length(local_result_dirs) > 0) sort(local_result_dirs, decreasing = TRUE)[[1]] else NA_character_

tracked_output <- system2("git", c("-C", repo_root, "ls-files", "output"), stdout = TRUE, stderr = FALSE)
tracked_results <- tracked_output[grepl("^output/results_[0-9]{6}_[0-9]{6}/", tracked_output)]
tracked_dirs <- unique(sub("^(output/results_[0-9]{6}_[0-9]{6}).*$", "\\1", tracked_results))

if (length(tracked_dirs) > 1) {
  stop(
    paste0(
      "Output tracking policy violated: more than one tracked results directory.\n",
      "Tracked: ", paste(tracked_dirs, collapse = ", "), "\n",
      "Run: Rscript scripts/stage_latest_output.R"
    )
  )
}

if (length(tracked_dirs) == 1 && !is.na(local_latest)) {
  tracked_basename <- sub("^output/", "", tracked_dirs[[1]])
  if (!identical(tracked_basename, local_latest)) {
    stop(
      paste0(
        "Output tracking policy violated: tracked results directory is not latest local one.\n",
        "Tracked: ", tracked_basename, "\n",
        "Latest local: ", local_latest, "\n",
        "Run: Rscript scripts/stage_latest_output.R"
      )
    )
  }
}

cat("Output tracking check passed.\n")
cat("Tracked results dirs: ", length(tracked_dirs), "\n", sep = "")
if (length(tracked_dirs) == 1) {
  cat("Tracked latest: ", tracked_dirs[[1]], "\n", sep = "")
}
