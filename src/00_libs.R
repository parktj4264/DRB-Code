# Automatic Package Installation & Loading Function (Robust Version) --------------------------------
library_load <- function(packages) {
  # [Core] Enforce Options: No prompts, Binary only, Fixed Repo
  options(repos = c(CRAN = "https://cran.rstudio.com/")) # Fix download repo
  options(pkgType = "win.binary") # Windows binary only (No compilation)
  options(install.packages.check.source = "no") # Skip source check
  options(install.packages.compile.from.source = "never") # Never compile from source (Prevent errors)

  # Color Definitions (Improve console log readability)
  green  <- function(x) paste0("\033[32m", x, "\033[0m")
  yellow <- function(x) paste0("\033[33m", x, "\033[0m")
  blue   <- function(x) paste0("\033[34m", x, "\033[0m")
  red    <- function(x) paste0("\033[31m", x, "\033[0m")
  gray   <- function(x) paste0("\033[90m", x, "\033[0m")

  total <- length(packages)

  for (i in seq_along(packages)) {
    package <- packages[i]
    message(gray(strrep("-", 50)))
    message(gray(paste0("Package [", i, "/", total, "]")))

    if (!requireNamespace(package, quietly = TRUE)) {
      message(yellow(paste("Installing:", package, "(Binary Only)")))

      tryCatch(
        {
          # Re-specify type="binary" here
          install.packages(package, type = "binary", quiet = TRUE)
        },
        error = function(e) {
          message(red(paste("Install failed:", package)))
          message(red(paste("Error:", e$message)))
        }
      )
    } else {
      message(green(paste("Already installed:", package)))
    }

    message(blue(paste("Loading:", package)))
    suppressPackageStartupMessages(
      library(package, character.only = TRUE)
    )
  }

  message(gray(strrep("-", 50)))
  message(green("All requested packages processed."))
}

# Package List --------------------------------------------------------------
cat("Loading libraries...\n")

library_load(
  c("data.table", "here", "stringr", "lubridate", "purrr", "stats", "dplyr")
)
