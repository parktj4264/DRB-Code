#' @title DRB Package Manifest
#' @description Single source of truth for the project's direct R package needs.

# Keep this file dependency-free: 00_setup_environment.R reads it before the
# project library has been restored.
DRB_CORE_PACKAGES <- c(
  "data.table", "here", "stringr", "lubridate", "purrr", "dplyr",
  "officer", "flextable", "ggplot2"
)

DRB_GUI_PACKAGES <- "shiny"

DRB_REQUIRED_PACKAGES <- unique(c(DRB_CORE_PACKAGES, DRB_GUI_PACKAGES))
