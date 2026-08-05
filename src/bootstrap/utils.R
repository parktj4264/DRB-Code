#' @title Utility Functions
#' @description Helper functions for logging and resource management.



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
normalize_msrinfo_spec_type <- function(x, context = "SPEC_TYPE") {
  values <- toupper(trimws(as.character(x)))
  values[is.na(values)] <- ""
  invalid <- unique(values[!values %in% c("", "U", "D", "N")])
  if (length(invalid) > 0L) {
    stop(
      context,
      " must use only U (망소), D (망대), N (망목), or blank. Invalid value(s): ",
      paste(utils::head(invalid, 20L), collapse = ", "),
      if (length(invalid) > 20L) " ..." else ""
    )
  }
  values
}

msrinfo_spec_type_label_ko <- function(x) {
  values <- normalize_msrinfo_spec_type(x)
  labels <- c(U = "망소", D = "망대", N = "망목")
  out <- unname(labels[values])
  out[is.na(out)] <- ""
  out
}
