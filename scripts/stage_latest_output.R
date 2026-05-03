#!/usr/bin/env Rscript

# Stage only the latest output/results_<timestamp>/ folder for git push.
# - Local results_* folders are preserved.
# - Old tracked output/results_* folders are removed from git index only.
# - Latest results_* folder is force-added to git.

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1) args[[1]] else "."
repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
output_dir <- file.path(repo_root, "output")

if (!dir.exists(output_dir)) {
  stop("Output directory not found: ", output_dir)
}

result_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
result_dirs <- result_dirs[grepl("^results_[0-9]{6}_[0-9]{6}$", basename(result_dirs))]
if (length(result_dirs) == 0) {
  stop("No output/results_<timestamp> folders found.")
}

latest_dir <- sort(result_dirs, decreasing = TRUE)[[1]]
latest_rel <- file.path("output", basename(latest_dir))

tracked_output <- system2("git", c("-C", repo_root, "ls-files", "output"), stdout = TRUE)
tracked_results <- tracked_output[grepl("^output/results_[0-9]{6}_[0-9]{6}/", tracked_output)]
tracked_result_dirs <- unique(sub("^(output/results_[0-9]{6}_[0-9]{6}).*$", "\\1", tracked_results))
to_remove <- setdiff(tracked_result_dirs, latest_rel)

if (length(to_remove) > 0) {
  system2("git", c("-C", repo_root, "rm", "-r", "--cached", "-f", "--ignore-unmatch", to_remove))
}

system2("git", c("-C", repo_root, "add", "-f", latest_rel))

cat("Latest output folder staged:\n")
cat("  ", latest_rel, "\n", sep = "")
if (length(to_remove) > 0) {
  cat("Removed old tracked output folders from git index:\n")
  for (dir_rel in to_remove) {
    cat("  ", dir_rel, "\n", sep = "")
  }
}
