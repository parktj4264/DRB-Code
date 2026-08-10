arguments <- commandArgs(trailingOnly = TRUE)
mode <- if (length(arguments)) arguments[[1L]] else "first"
stopifnot(mode %in% c("first", "reuse"))

source(".Rprofile")

evaluate_entrypoint_bootstrap <- function(file) {
  expressions <- parse(file)
  bootstrap_calls <- which(vapply(expressions, function(expression) {
    is.call(expression) && identical(expression[[1L]], as.name("drb_bootstrap"))
  }, logical(1)))
  stopifnot(length(bootstrap_calls) == 1L)

  evaluation_environment <- new.env(parent = .GlobalEnv)
  result <- NULL
  for (index in seq_len(bootstrap_calls[[1L]])) {
    result <- eval(expressions[[index]], envir = evaluation_environment)
  }

  list(
    result = result,
    expressions = expressions,
    bootstrap_index = bootstrap_calls[[1L]],
    environment = evaluation_environment
  )
}

verify_gui_construction <- function(entrypoint) {
  final_index <- length(entrypoint$expressions)
  if (entrypoint$bootstrap_index + 1L < final_index) {
    for (index in seq.int(entrypoint$bootstrap_index + 1L, final_index - 1L)) {
      eval(entrypoint$expressions[[index]], envir = entrypoint$environment)
    }
  }

  create_app <- get(
    "create_drb_gui_app",
    envir = entrypoint$environment,
    inherits = TRUE
  )
  app <- create_app(project_dir = getwd())
  stopifnot(inherits(app, "shiny.appobj"))
}

expected_library_dir <- Sys.getenv(
  "DRB_TEST_EXPECTED_LIBRARY_DIR",
  unset = paste0("R-", drb_r_minor())
)
expected_environment <- Sys.getenv(
  "DRB_TEST_EXPECTED_ENVIRONMENT",
  unset = paste0("DRB-R", drb_r_minor())
)
expected_library <- normalizePath(
  file.path(
    Sys.getenv("LOCALAPPDATA"),
    "DRB",
    expected_library_dir,
    "library"
  ),
  winslash = "/",
  mustWork = TRUE
)

gui_entrypoint <- evaluate_entrypoint_bootstrap("run_gui.R")
if (identical(mode, "first")) {
  stopifnot(setequal(
    gui_entrypoint$result$installed_packages,
    DRB_REQUIRED_PACKAGES
  ))
} else {
  stopifnot(!length(gui_entrypoint$result$installed_packages))
}
verify_gui_construction(gui_entrypoint)

run_entrypoint <- evaluate_entrypoint_bootstrap("run.R")
stopifnot(!length(run_entrypoint$result$installed_packages))

info <- drb_env()
stopifnot(identical(info$environment, expected_environment))
stopifnot(identical(tolower(info$library), tolower(expected_library)))
stopifnot(identical(.libPaths()[[1L]], expected_library))
stopifnot(length(.libPaths()) == 2L)
stopifnot(isTRUE(info$ready))
stopifnot(all(vapply(
  DRB_REQUIRED_PACKAGES,
  drb_package_exists,
  logical(1),
  library = info$library
)))

cat(
  if (identical(mode, "first")) {
    "FIRST_PROJECT_ENTRYPOINTS_OK\n"
  } else {
    "SECOND_PROJECT_REUSE_OK\n"
  }
)
