#' @title DRB Package Manifest
#' @description Single source of truth for the project's direct R package needs.

# Keep this file dependency-free: startup and setup read it before the shared
# DRB library has been installed or verified.
DRB_CORE_PACKAGES <- c(
  "data.table", "here", "stringr", "lubridate", "purrr", "dplyr",
  "officer", "flextable", "ggplot2"
)

DRB_GUI_PACKAGES <- "shiny"

DRB_REQUIRED_PACKAGES <- unique(c(DRB_CORE_PACKAGES, DRB_GUI_PACKAGES))
