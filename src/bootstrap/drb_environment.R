#' @title DRB Shared R Environment
#' @description Select and report the per-user DRB package library.

# This file intentionally depends on base/recommended R only. It is sourced by
# .Rprofile before any DRB package is available.

DRB_SUPPORTED_R_MINORS <- c("4.1", "4.5")

drb_find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    if (file.exists(file.path(current, "DRB-Code.Rproj"))) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) break
    current <- parent
  }

  stop(
    "Open DRB-Code.Rproj before starting the DRB environment.",
    call. = FALSE
  )
}

drb_normalize_path <- function(path, must_work = FALSE) {
  normalizePath(path, winslash = "/", mustWork = must_work)
}

drb_r_minor <- function(r_version = getRversion()) {
  version_text <- as.character(r_version)[[1L]]
  components <- strsplit(version_text, ".", fixed = TRUE)[[1L]]

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
        paste0(
          "Cannot locate the Windows LocalAppData directory: both ",
          "LOCALAPPDATA and USERPROFILE are empty."
        ),
        call. = FALSE
      )
    }
    root <- file.path(user_profile, "AppData", "Local")
  }

  drb_normalize_path(root, must_work = FALSE)
}

drb_environment_spec <- function(
    project_dir = NULL,
    r_version = getRversion(),
    local_appdata = Sys.getenv("LOCALAPPDATA"),
    user_profile = Sys.getenv("USERPROFILE"),
    create = FALSE) {
  if (is.null(project_dir)) {
    project_dir <- getOption("drb.environment.project", NULL)
  }
  if (is.null(project_dir)) {
    project_dir <- drb_find_project_root()
  }
  project_dir <- drb_normalize_path(project_dir, must_work = TRUE)

  version_text <- as.character(r_version)[[1L]]
  r_minor <- drb_r_minor(version_text)
  supported <- r_minor %in% DRB_SUPPORTED_R_MINORS

  if (!supported) {
    return(list(
      project_dir = project_dir,
      r_version = version_text,
      r_minor = r_minor,
      supported = FALSE,
      profile = NA_character_,
      environment = NA_character_,
      root = NA_character_,
      library = NA_character_,
      lockfile = NA_character_,
      hash_file = NA_character_
    ))
  }

  profile <- paste0("r-", r_minor)
  environment <- paste0("DRB-R", r_minor)
  local_root <- drb_local_appdata(local_appdata, user_profile)
  environment_root <- drb_normalize_path(
    file.path(local_root, "DRB", paste0("R-", r_minor)),
    must_work = FALSE
  )
  library <- drb_normalize_path(
    file.path(environment_root, "library"),
    must_work = FALSE
  )

  if (isTRUE(create)) {
    created <- dir.create(library, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(library)) {
      stop(
        "Failed to create the DRB shared library: ", library,
        call. = FALSE
      )
    }
    invisible(created)
  }

  list(
    project_dir = project_dir,
    r_version = version_text,
    r_minor = r_minor,
    supported = TRUE,
    profile = profile,
    environment = environment,
    root = environment_root,
    library = library,
    lockfile = drb_normalize_path(
      file.path(project_dir, "renv", "profiles", profile, "renv.lock"),
      must_work = FALSE
    ),
    hash_file = drb_normalize_path(
      file.path(environment_root, "lock_hash.txt"),
      must_work = FALSE
    )
  )
}

drb_assert_shared_library_path <- function(spec) {
  local_root <- drb_normalize_path(
    file.path(drb_local_appdata(), "DRB"),
    must_work = FALSE
  )
  r_home <- drb_normalize_path(R.home(), must_work = TRUE)
  library <- drb_normalize_path(spec$library, must_work = FALSE)

  under_local_drb <- startsWith(
    tolower(paste0(library, "/")),
    tolower(paste0(local_root, "/"))
  )
  under_r_home <- startsWith(
    tolower(paste0(library, "/")),
    tolower(paste0(r_home, "/"))
  )

  if (!under_local_drb || under_r_home) {
    stop(
      "Unsafe DRB library target rejected: ", library,
      call. = FALSE
    )
  }

  invisible(TRUE)
}

drb_environment_activate <- function(
    project_dir = NULL,
    create = TRUE,
    stop_on_unsupported = TRUE) {
  spec <- drb_environment_spec(project_dir = project_dir, create = create)

  if (.Platform$OS.type != "windows" || .Machine$sizeof.pointer != 8L) {
    if (isTRUE(stop_on_unsupported)) {
      stop(
        "DRB supports 64-bit Windows RStudio only.",
        call. = FALSE
      )
    }
    return(spec)
  }

  if (!isTRUE(spec$supported)) {
    if (isTRUE(stop_on_unsupported)) {
      stop(
        paste0(
          "Unsupported R version: ", spec$r_version,
          ". Use R 4.1.x or R 4.5.x."
        ),
        call. = FALSE
      )
    }
    return(spec)
  }

  drb_assert_shared_library_path(spec)
  if (!dir.exists(spec$library)) {
    stop("DRB shared library does not exist: ", spec$library, call. = FALSE)
  }

  # Do not inherit an external renv profile and do not include the ordinary
  # per-user or site libraries. DRB packages plus this R installation's
  # base/recommended library are the complete search path for this session.
  Sys.unsetenv("RENV_PROFILE")
  Sys.setenv(RENV_CONFIG_INSTALL_STAGED = "FALSE")
  .libPaths(c(spec$library, R.home("library")), include.site = FALSE)

  options(drb.environment.project = spec$project_dir)
  spec
}

drb_lock_hash <- function(lockfile) {
  if (!file.exists(lockfile)) return(NA_character_)
  unname(as.character(tools::md5sum(lockfile))[[1L]])
}

drb_read_installed_lock_hash <- function(hash_file) {
  if (!file.exists(hash_file)) return(NA_character_)

  value <- tryCatch(
    readLines(hash_file, warn = FALSE, n = 1L),
    error = function(error) character()
  )
  if (!length(value) || !nzchar(trimws(value[[1L]]))) return(NA_character_)
  trimws(value[[1L]])
}

drb_write_installed_lock_hash <- function(spec, hash) {
  if (!nzchar(hash) || is.na(hash)) {
    stop("Cannot record an empty lockfile hash.", call. = FALSE)
  }

  dir.create(spec$root, recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile("lock_hash_", tmpdir = spec$root, fileext = ".tmp")
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  writeLines(hash, temporary, useBytes = TRUE)

  if (!file.copy(temporary, spec$hash_file, overwrite = TRUE)) {
    stop("Failed to write the DRB lock hash: ", spec$hash_file, call. = FALSE)
  }

  invisible(spec$hash_file)
}

drb_required_packages <- function(project_dir) {
  manifest <- file.path(project_dir, "src", "bootstrap", "package_manifest.R")
  if (!file.exists(manifest)) return(character())

  manifest_environment <- new.env(parent = baseenv())
  sys.source(manifest, envir = manifest_environment)
  if (!exists("DRB_REQUIRED_PACKAGES", envir = manifest_environment, inherits = FALSE)) {
    return(character())
  }

  unique(as.character(get(
    "DRB_REQUIRED_PACKAGES",
    envir = manifest_environment,
    inherits = FALSE
  )))
}

drb_missing_required_packages <- function(spec) {
  required <- drb_required_packages(spec$project_dir)
  required[!vapply(required, function(package) {
    file.exists(file.path(spec$library, package, "DESCRIPTION"))
  }, logical(1))]
}

drb_environment_status <- function(spec = drb_environment_spec(create = FALSE)) {
  result <- list(
    lock = "UNKNOWN",
    status = "UNKNOWN",
    ready = FALSE,
    current_hash = NA_character_,
    installed_hash = NA_character_,
    missing_packages = character(),
    library_paths_ok = FALSE
  )

  if (.Platform$OS.type != "windows" || .Machine$sizeof.pointer != 8L) {
    result$lock <- "UNAVAILABLE"
    result$status <- "UNSUPPORTED PLATFORM"
    return(result)
  }
  if (!isTRUE(spec$supported)) {
    result$lock <- "UNAVAILABLE"
    result$status <- "UNSUPPORTED R VERSION"
    return(result)
  }
  if (!file.exists(spec$lockfile)) {
    result$lock <- "LOCKFILE MISSING"
    result$status <- "PROJECT INCOMPLETE"
    return(result)
  }

  expected_paths <- vapply(
    c(spec$library, R.home("library")),
    drb_normalize_path,
    character(1),
    must_work = FALSE
  )
  active_paths <- vapply(
    .libPaths(),
    drb_normalize_path,
    character(1),
    must_work = FALSE
  )
  result$library_paths_ok <- identical(
    tolower(unique(active_paths)),
    tolower(unique(expected_paths))
  )

  result$current_hash <- drb_lock_hash(spec$lockfile)
  result$installed_hash <- drb_read_installed_lock_hash(spec$hash_file)

  if (!dir.exists(spec$library) || is.na(result$installed_hash)) {
    result$lock <- "NOT INSTALLED"
    result$status <- "SETUP REQUIRED"
    return(result)
  }
  if (!identical(result$current_hash, result$installed_hash)) {
    result$lock <- "CHANGED"
    result$status <- "UPDATE REQUIRED"
    return(result)
  }

  result$missing_packages <- drb_missing_required_packages(spec)
  if (length(result$missing_packages)) {
    result$lock <- "MATCHED"
    result$status <- "REPAIR REQUIRED"
    return(result)
  }
  if (!isTRUE(result$library_paths_ok)) {
    result$lock <- "MATCHED"
    result$status <- "LIBRARY PATH ERROR"
    return(result)
  }

  result$lock <- "MATCHED"
  result$status <- "READY"
  result$ready <- TRUE
  result
}

drb_print_environment <- function(spec, status, include_details = FALSE) {
  value_or_na <- function(value) {
    if (!length(value) || is.na(value) || !nzchar(value)) "N/A" else value
  }

  cat(
    "============================================================\n",
    " DRB ENVIRONMENT\n",
    "============================================================\n",
    " R       : ", value_or_na(spec$r_version), "\n",
    " ENV     : ", value_or_na(spec$environment), "\n",
    " LIBRARY : ", value_or_na(spec$library), "\n",
    " LOCK    : ", status$lock, "\n",
    " STATUS  : ", status$status, "\n",
    sep = ""
  )

  if (isTRUE(include_details)) {
    cat(" LOCKFILE: ", value_or_na(spec$lockfile), "\n", sep = "")
    cat(" .libPaths():\n")
    for (index in seq_along(.libPaths())) {
      cat("   ", index, ". ", .libPaths()[[index]], "\n", sep = "")
    }
  }

  if (identical(status$status, "SETUP REQUIRED") ||
      identical(status$status, "UPDATE REQUIRED") ||
      identical(status$status, "REPAIR REQUIRED")) {
    cat(" NEXT    : source(\"00_setup_environment.R\")\n")
  } else if (identical(status$status, "UNSUPPORTED R VERSION")) {
    cat(" NEXT    : Reopen this project with R 4.1.x or R 4.5.x.\n")
  }

  cat("============================================================\n")
  invisible(NULL)
}

drb_env <- function() {
  spec <- drb_environment_activate(
    create = TRUE,
    stop_on_unsupported = FALSE
  )
  status <- drb_environment_status(spec)
  drb_print_environment(spec, status, include_details = TRUE)

  invisible(c(spec, status, list(lib_paths = .libPaths())))
}

drb_environment_initialize <- function(show_banner = TRUE) {
  spec <- drb_environment_activate(
    create = TRUE,
    stop_on_unsupported = FALSE
  )
  status <- drb_environment_status(spec)

  if (isTRUE(show_banner) &&
      !isTRUE(getOption("drb.environment.banner.shown", FALSE))) {
    drb_print_environment(spec, status, include_details = FALSE)
    options(drb.environment.banner.shown = TRUE)
  }

  invisible(c(spec, status, list(lib_paths = .libPaths())))
}

drb_assert_environment_ready <- function(project_dir = NULL) {
  spec <- drb_environment_activate(
    project_dir = project_dir,
    create = TRUE,
    stop_on_unsupported = TRUE
  )
  status <- drb_environment_status(spec)

  if (!isTRUE(status$ready)) {
    detail <- if (length(status$missing_packages)) {
      paste0(" Missing: ", paste(status$missing_packages, collapse = ", "), ".")
    } else {
      ""
    }
    stop(
      paste0(
        "DRB shared environment is not ready (", status$status, ").",
        detail, "\nRun source(\"00_setup_environment.R\") once, then retry."
      ),
      call. = FALSE
    )
  }

  invisible(spec)
}
