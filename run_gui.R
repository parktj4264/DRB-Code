#' @title User Interface (GUI)
#' @description Launch the local DRB option selector and Quick Preview.
rm(list = ls())
gc()

if (!requireNamespace("here", quietly = TRUE)) install.packages("here", type = "binary")
source("src/bootstrap/libs.R")
library_load("shiny")

source(here::here("src", "bootstrap", "utils.R"), local = environment())
source(here::here("src", "bootstrap", "io_utils.R"), local = environment())
source(here::here("src", "01_load_data.R"), local = environment())
source(here::here("src", "03_create_ppt.R"), local = environment())
source(here::here("src", "gui", "gui_preview.R"), local = environment())
source(here::here("src", "gui", "gui_app.R"), local = environment())

launch_drb_gui()
