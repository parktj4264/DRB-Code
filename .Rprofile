local({
  bootstrap_file <- file.path("src", "bootstrap", "drb_bootstrap.R")

  if (!file.exists(bootstrap_file)) {
    message(
      "[DRB-Code] Environment bootstrap is missing. ",
      "Download the complete project again."
    )
  } else {
    tryCatch({
      sys.source(bootstrap_file, envir = globalenv())
      drb_environment_initialize(show_banner = TRUE)
    }, error = function(error) {
      message(
        "[DRB-Code] Environment startup failed: ",
        conditionMessage(error)
      )
    })
  }
})
