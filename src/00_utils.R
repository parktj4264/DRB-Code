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
  
  # Heuristic for safe core allocation on Windows (assuming 32-64GB RAM)
  if (file_size_gb > 3) {
    n_cores <- min(4, total_cores)
  } else if (file_size_gb > 1) {
    n_cores <- min(6, total_cores)
  } else {
    n_cores <- max(1, total_cores - 1)
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
