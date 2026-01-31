#' @title Utility Functions
#' @description Helper functions for logging and resource management.

#' @title Get Safe Core Count
#' @description Determines the number of cores to use based on file size to prevent memory issues.
#' @param file_path Path to the raw data file.
#' @return Integer number of cores to use.
get_safe_cores <- function(file_path) {
  if (!file.exists(file_path)) {
    warning("File not found: ", file_path, ". Using default core count (1).")
    return(1)
  }

  file_size_gb <- file.size(file_path) / (1024^3)
  total_cores <- parallel::detectCores(logical = FALSE) # Physical cores preferred

  if (is.na(total_cores)) total_cores <- 1

  # Heuristic for safe core allocation
  if (file_size_gb < 0.5) {
    n_cores <- min(2, total_cores) # Small data: use fewer cores
  } else if (file_size_gb < 2) {
    n_cores <- min(4, total_cores) # Medium data
  } else {
    # Large data: limit to preventing memory explosion
    n_cores <- min(6, total_cores)
  }

  log_msg(paste0("File Size: ", round(file_size_gb, 2), " GB. Cores allocated: ", n_cores))
  return(n_cores)
}

#' @title Log Message
#' @description Prints a timestamped message to the console.
#' @param msg STRING. The message to log.
log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s\n", timestamp, msg))
}

# Color Functions for Console Output
green  <- function(x) paste0("\033[32m", x, "\033[0m")
yellow <- function(x) paste0("\033[33m", x, "\033[0m")
blue   <- function(x) paste0("\033[34m", x, "\033[0m")
red    <- function(x) paste0("\033[31m", x, "\033[0m")
gray   <- function(x) paste0("\033[90m", x, "\033[0m")
bold   <- function(x) paste0("\033[1m", x, "\033[22m")
