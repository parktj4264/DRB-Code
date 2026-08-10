#' @title DRB R Bootstrap
#' @description Use one shared package library per Windows user and R minor version.

# Keep this file dependency-free. It runs before any DRB package is available.
DRB_SUPPORTED_R_MINORS <- c("4.1", "4.5")

DRB_CORE_PACKAGES <- c(
  "data.table", "here", "stringr", "lubridate", "purrr", "dplyr",
  "officer", "flextable", "ggplot2"
)

DRB_GUI_PACKAGES <- "shiny"
DRB_REQUIRED_PACKAGES <- unique(c(DRB_CORE_PACKAGES, DRB_GUI_PACKAGES))

drb_normalize_path <- function(path, must_work = FALSE) {
  normalizePath(path, winslash = "/", mustWork = must_work)
}

drb_r_minor <- function(r_version = getRversion()) {
  components <- strsplit(as.character(r_version)[[1L]], ".", fixed = TRUE)[[1L]]
  if (length(components) < 2L) return(NA_character_)
  paste(components[[1L]], components[[2L]], sep = ".")
}

drb_local_appdata <- function(
    local_appdata = Sys.getenv("LOCALAPPDATA"),
    user_profile = Sys.getenv("USERPROFILE")) {
  root <- trimws(local_appdata)

  if (!nzchar(root)) {
    user_profile <- trimws(user_profile)
    if (!nzchar(user_profile)) {
      stop(
        "Cannot locate LocalAppData because LOCALAPPDATA and USERPROFILE are empty.",
        call. = FALSE
      )
    }
    root <- file.path(user_profile, "AppData", "Local")
  }

  drb_normalize_path(root, must_work = FALSE)
}

drb_environment_spec <- function(
    r_version = getRversion(),
    local_appdata = Sys.getenv("LOCALAPPDATA"),
    user_profile = Sys.getenv("USERPROFILE"),
    create = TRUE) {
  version_text <- as.character(r_version)[[1L]]
  r_minor <- drb_r_minor(version_text)
  if (!(r_minor %in% DRB_SUPPORTED_R_MINORS)) {
    stop(
      "Unsupported R version: ", version_text,
      ". Use 64-bit Windows R 4.1.x or R 4.5.x.",
      call. = FALSE
    )
  }

  environment_root <- file.path(
    drb_local_appdata(local_appdata, user_profile),
    "DRB",
    paste0("R-", r_minor)
  )
  library <- file.path(environment_root, "library")

  if (isTRUE(create)) {
    dir.create(library, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(library)) {
      stop("Failed to create the DRB shared library: ", library, call. = FALSE)
    }
  }

  list(
    r_version = version_text,
    r_minor = r_minor,
    environment = paste0("DRB-R", r_minor),
    library = drb_normalize_path(library, must_work = FALSE)
  )
}

drb_environment_activate <- function() {
  if (.Platform$OS.type != "windows" || .Machine$sizeof.pointer != 8L) {
    stop("DRB-Code supports 64-bit Windows R only.", call. = FALSE)
  }

  spec <- drb_environment_spec(create = TRUE)
  .libPaths(c(spec$library, R.home("library")), include.site = FALSE)

  active_library <- drb_normalize_path(.libPaths()[[1L]], must_work = TRUE)
  if (!identical(tolower(active_library), tolower(spec$library))) {
    stop("Failed to activate the DRB shared library: ", spec$library, call. = FALSE)
  }
  spec
}

drb_package_exists <- function(package, library) {
  description_file <- file.path(library, package, "DESCRIPTION")
  if (!file.exists(description_file)) return(FALSE)

  package_name <- suppressWarnings(tryCatch(
    read.dcf(description_file, fields = "Package")[[1L, "Package"]],
    error = function(error) NA_character_
  ))
  identical(as.character(package_name), package)
}

drb_missing_packages <- function(
    spec,
    packages = DRB_REQUIRED_PACKAGES) {
  packages <- unique(as.character(packages))
  packages[!vapply(
    packages,
    drb_package_exists,
    logical(1),
    library = spec$library
  )]
}

drb_environment_status <- function(spec) {
  missing <- drb_missing_packages(spec)
  list(
    status = if (length(missing)) "PACKAGES REQUIRED" else "READY",
    ready = !length(missing),
    missing_packages = missing
  )
}

drb_print_environment <- function(spec, status, include_details = FALSE) {
  cat(
    "============================================================\n",
    " DRB ENVIRONMENT\n",
    "============================================================\n",
    " R       : ", spec$r_version, "\n",
    " ENV     : ", spec$environment, "\n",
    " LIBRARY : ", spec$library, "\n",
    " STATUS  : ", status$status, "\n",
    sep = ""
  )

  if (length(status$missing_packages)) {
    cat(" MISSING : ", paste(status$missing_packages, collapse = ", "), "\n", sep = "")
  }
  if (isTRUE(include_details)) {
    cat(" .libPaths():\n")
    for (index in seq_along(.libPaths())) {
      cat("   ", index, ". ", .libPaths()[[index]], "\n", sep = "")
    }
  }

  cat("============================================================\n")
  invisible(NULL)
}

drb_env <- function() {
  spec <- drb_environment_activate()
  status <- drb_environment_status(spec)
  drb_print_environment(spec, status, include_details = TRUE)
  invisible(c(spec, status, list(lib_paths = .libPaths())))
}

drb_environment_initialize <- function(show_banner = TRUE) {
  spec <- drb_environment_activate()
  status <- drb_environment_status(spec)

  if (isTRUE(show_banner) &&
      !isTRUE(getOption("drb.environment.banner.shown", FALSE))) {
    drb_print_environment(spec, status)
    options(drb.environment.banner.shown = TRUE)
  }

  invisible(c(spec, status, list(lib_paths = .libPaths())))
}

drb_cran_repositories <- function() {
  repositories <- getOption("repos")
  if (is.null(repositories) || !length(repositories)) {
    return(c(CRAN = "https://cloud.r-project.org"))
  }

  invalid <- is.na(repositories) |
    !nzchar(trimws(repositories)) |
    repositories == "@CRAN@"
  repositories[invalid] <- "https://cloud.r-project.org"
  repositories
}

drb_install_missing_packages <- function(spec) {
  missing <- drb_missing_packages(spec)
  if (!length(missing)) return(character())

  cat(
    "Installing missing DRB packages into:\n  ", spec$library, "\n",
    "Packages: ", paste(missing, collapse = ", "), "\n",
    sep = ""
  )

  utils::install.packages(
    missing,
    lib = spec$library,
    dependencies = TRUE,
    repos = drb_cran_repositories()
  )

  remaining <- drb_missing_packages(spec, missing)
  if (length(remaining)) {
    stop(
      "Package installation did not complete. Still missing from the DRB library: ",
      paste(remaining, collapse = ", "),
      call. = FALSE
    )
  }

  missing
}

drb_load_packages <- function(packages, library_path) {
  packages <- unique(as.character(packages))

  invisible(lapply(packages, function(package) {
    if (!drb_package_exists(package, library_path)) {
      stop("Package is missing from the DRB shared library: ", package, call. = FALSE)
    }

    tryCatch(
      suppressWarnings(suppressPackageStartupMessages(
        library(package, character.only = TRUE, lib.loc = library_path)
      )),
      error = function(error) {
        stop(
          "Failed to load DRB package '", package, "': ",
          conditionMessage(error),
          call. = FALSE
        )
      }
    )
  }))
}

drb_bootstrap <- function(packages_to_load = DRB_CORE_PACKAGES) {
  unknown <- setdiff(packages_to_load, DRB_REQUIRED_PACKAGES)
  if (length(unknown)) {
    stop("Unknown DRB package(s): ", paste(unknown, collapse = ", "), call. = FALSE)
  }

  spec <- drb_environment_activate()
  installed <- drb_install_missing_packages(spec)
  status <- drb_environment_status(spec)
  if (!isTRUE(status$ready)) {
    stop("The DRB package environment is not ready.", call. = FALSE)
  }

  drb_load_packages(packages_to_load, spec$library)
  assign(".DRB_LIBRARIES_LOADED", TRUE, envir = .GlobalEnv)

  if (length(installed) ||
      !isTRUE(getOption("drb.environment.banner.shown", FALSE))) {
    drb_print_environment(spec, status)
    options(drb.environment.banner.shown = TRUE)
  }

  invisible(c(spec, status, list(installed_packages = installed)))
}
