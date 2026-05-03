#' @title Utility Functions
#' @description Helper functions for logging and resource management.



#' @title Log Message
#' @description Prints a timestamped message to the console.
#' @param msg STRING. The message to log.
log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s\n", timestamp, msg))
}

# Keep only the newest timestamped results_* folders under output/.
prune_result_archives <- function(output_dir = here::here("output"), keep = 1L) {
  keep <- as.integer(keep[[1]])
  if (is.na(keep) || keep < 0L) {
    keep <- 1L
  }

  if (!dir.exists(output_dir)) {
    return(character())
  }

  result_dirs <- list.dirs(output_dir, recursive = FALSE, full.names = TRUE)
  result_dirs <- result_dirs[grepl("^results_[0-9]{6}_[0-9]{6}$", basename(result_dirs))]
  if (length(result_dirs) <= keep) {
    return(character())
  }

  sorted_dirs <- sort(result_dirs, decreasing = TRUE)
  keep_dirs <- sorted_dirs[seq_len(min(keep, length(sorted_dirs)))]
  remove_dirs <- setdiff(result_dirs, keep_dirs)

  if (length(remove_dirs) > 0) {
    unlink(remove_dirs, recursive = TRUE, force = TRUE)
  }

  basename(remove_dirs)
}

# Color Functions for Console Output
green  <- function(x) paste0("\033[32m", x, "\033[0m")
yellow <- function(x) paste0("\033[33m", x, "\033[0m")
blue   <- function(x) paste0("\033[34m", x, "\033[0m")
red    <- function(x) paste0("\033[31m", x, "\033[0m")
gray   <- function(x) paste0("\033[90m", x, "\033[0m")
bold   <- function(x) paste0("\033[1m", x, "\033[22m")
