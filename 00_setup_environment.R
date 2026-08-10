#' @title DRB Environment Setup
#' @description Install or update the per-user DRB shared package library.

# Run this after opening DRB-Code.Rproj when the startup banner says
# SETUP REQUIRED, UPDATE REQUIRED, or REPAIR REQUIRED.

bootstrap_file <- file.path("src", "bootstrap", "drb_environment.R")
if (!file.exists(bootstrap_file)) {
  stop(
    "The DRB environment bootstrap is missing. Download the complete project again.",
    call. = FALSE
  )
}
sys.source(bootstrap_file, envir = globalenv())

DRB_RENV_VERSION <- "1.2.2"
DRB_RENV_SOURCE <- paste0(
  "https://cloud.r-project.org/src/contrib/Archive/renv/renv_",
  DRB_RENV_VERSION,
  ".tar.gz"
)
DRB_RENV_MD5 <- "f7edf106ad8596e1a695e75a963e0f42"

drb_setup_elapsed <- function(started_at) {
  elapsed <- max(
    0,
    round(as.numeric(difftime(Sys.time(), started_at, units = "secs")))
  )
  if (elapsed < 60) return(paste0(elapsed, " sec"))
  paste0(elapsed %/% 60, " min ", sprintf("%02d", elapsed %% 60), " sec")
}

drb_package_path <- function(package, library) {
  path <- tryCatch(
    find.package(package, lib.loc = library, quiet = TRUE),
    error = function(error) character()
  )
  if (!length(path)) return(NA_character_)
  path[[1L]]
}

drb_package_version_at <- function(package, library) {
  description_file <- file.path(library, package, "DESCRIPTION")
  if (!file.exists(description_file)) {
    return(NA_character_)
  }

  description <- suppressWarnings(tryCatch(
    read.dcf(description_file, fields = c("Package", "Version")),
    error = function(error) NULL
  ))
  if (is.null(description) ||
      nrow(description) != 1L ||
      !identical(as.character(description[[1L, "Package"]]), package)) {
    return(NA_character_)
  }

  version <- as.character(description[[1L, "Version"]])
  if (!length(version) || is.na(version) || !nzchar(version)) {
    return(NA_character_)
  }
  version
}

drb_bootstrap_renv <- function(spec) {
  shared_path <- drb_package_path("renv", spec$library)
  shared_version <- drb_package_version_at("renv", spec$library)

  if ("renv" %in% loadedNamespaces()) {
    loaded_path <- getNamespaceInfo(asNamespace("renv"), "path")
    same_package <- !is.na(shared_path) && identical(
      tolower(drb_normalize_path(loaded_path, must_work = TRUE)),
      tolower(drb_normalize_path(shared_path, must_work = TRUE))
    )
    loaded_version <- as.character(getNamespaceVersion("renv"))
    if (!same_package || !identical(loaded_version, DRB_RENV_VERSION)) {
      stop(
        paste0(
          "A different renv is already loaded. ",
          "Restart RStudio, open DRB-Code.Rproj, and run setup before analysis."
        ),
        call. = FALSE
      )
    }
    return(invisible(shared_path))
  }

  if (is.na(shared_path) || !identical(shared_version, DRB_RENV_VERSION)) {
    cat(
      "[1/4] Installing environment manager ", DRB_RENV_VERSION,
      " into the DRB shared library...\n",
      sep = ""
    )

    old_path <- file.path(spec$library, "renv")
    backup_path <- tempfile("renv-bootstrap-backup-", tmpdir = spec$root)
    backed_up <- FALSE
    if (dir.exists(old_path)) {
      backed_up <- file.rename(old_path, backup_path)
      if (!backed_up) {
        stop(
          "Could not prepare the environment manager for update. Restart RStudio and retry.",
          call. = FALSE
        )
      }
    }

    # R CMD INSTALL starts a child R process. Point that child at an empty
    # profile so it does not print the project startup banner mid-setup.
    old_user_profile <- Sys.getenv("R_PROFILE_USER", unset = NA_character_)
    install_profile <- tempfile("drb-empty-profile-", fileext = ".Rprofile")
    writeLines(character(), install_profile)
    Sys.setenv(R_PROFILE_USER = install_profile)
    on.exit({
      if (is.na(old_user_profile)) {
        Sys.unsetenv("R_PROFILE_USER")
      } else {
        Sys.setenv(R_PROFILE_USER = old_user_profile)
      }
      unlink(install_profile, force = TRUE)
    }, add = TRUE)

    archive <- tempfile(paste0("renv_", DRB_RENV_VERSION, "_"), fileext = ".tar.gz")
    on.exit(unlink(archive, force = TRUE), add = TRUE)
    install_error <- tryCatch({
      utils::download.file(DRB_RENV_SOURCE, archive, mode = "wb", quiet = FALSE)
      archive_md5 <- unname(as.character(tools::md5sum(archive))[[1L]])
      if (!identical(tolower(archive_md5), DRB_RENV_MD5)) {
        stop(
          "Environment-manager download checksum mismatch. Expected ",
          DRB_RENV_MD5,
          ", received ",
          archive_md5,
          ".",
          call. = FALSE
        )
      }
      utils::install.packages(
        archive,
        lib = spec$library,
        repos = NULL,
        type = "source",
        dependencies = FALSE,
        INSTALL_opts = "--no-staged-install"
      )
      NULL
    }, error = identity)

    shared_path <- drb_package_path("renv", spec$library)
    shared_version <- drb_package_version_at("renv", spec$library)
    installed_ok <- !is.na(shared_path) && identical(shared_version, DRB_RENV_VERSION)
    if (!installed_ok) {
      if (dir.exists(old_path)) unlink(old_path, recursive = TRUE, force = TRUE)
      backup_restored <- !backed_up || file.rename(backup_path, old_path)
      stop(
        paste(
          c(
            paste0("Failed to install environment manager ", DRB_RENV_VERSION, "."),
            if (inherits(install_error, "error")) {
              paste0("Details: ", conditionMessage(install_error))
            },
            if (!backup_restored) {
              paste0("Previous environment-manager backup: ", backup_path)
            },
            "Check the company proxy/firewall and run setup again."
          ),
          collapse = "\n"
        ),
        call. = FALSE
      )
    }

    if (backed_up) {
      unlink(backup_path, recursive = TRUE, force = TRUE)
      if (dir.exists(backup_path)) {
        warning("Old environment-manager backup could not be removed: ", backup_path)
      }
    }
  } else {
    cat(
      "[1/4] Environment manager ", DRB_RENV_VERSION,
      " is already available in the DRB shared library.\n",
      sep = ""
    )
  }

  loadNamespace("renv", lib.loc = spec$library)
  invisible(shared_path)
}

drb_lockfile_records <- function(lockfile) {
  lock <- renv::lockfile_read(lockfile)
  records <- lock$Packages
  if (is.null(records) || !length(records)) {
    stop("The selected lockfile contains no package records.", call. = FALSE)
  }
  records
}

drb_reusable_r_packages <- function(records) {
  priorities <- vapply(records, function(record) {
    priority <- record[["Priority"]]
    if (is.null(priority)) "" else as.character(priority)
  }, character(1))
  candidates <- names(records)[priorities %in% c("base", "recommended")]

  candidates[vapply(candidates, function(package) {
    !is.na(drb_package_version_at(package, R.home("library")))
  }, logical(1))]
}

drb_installed_shared_packages <- function(library) {
  paths <- list.files(library, full.names = TRUE)
  paths <- paths[dir.exists(paths)]
  paths <- paths[file.exists(file.path(paths, "DESCRIPTION"))]
  unique(basename(paths))
}

drb_restore_plan <- function(records, library, reusable_r_packages) {
  expected <- setdiff(names(records), c(reusable_r_packages, "renv"))
  expected_versions <- vapply(expected, function(package) {
    as.character(records[[package]][["Version"]])
  }, character(1))
  installed_versions <- vapply(
    expected,
    drb_package_version_at,
    character(1),
    library = library
  )
  install_or_update <- expected[
    is.na(installed_versions) | installed_versions != expected_versions
  ]

  installed <- drb_installed_shared_packages(library)
  obsolete <- setdiff(installed, c(names(records), "renv"))
  standard_in_shared <- intersect(installed, reusable_r_packages)
  remove <- unique(c(obsolete, standard_in_shared))

  list(
    install_or_update = unique(install_or_update),
    remove = remove,
    backup_targets = unique(c(install_or_update, remove))
  )
}

drb_backup_packages <- function(spec, packages) {
  existing <- packages[dir.exists(file.path(spec$library, packages))]
  if (!length(existing)) {
    return(list(active = FALSE, directory = NA_character_, moved = character()))
  }

  rollback_root <- file.path(spec$root, "rollback")
  dir.create(rollback_root, recursive = TRUE, showWarnings = FALSE)
  backup_dir <- tempfile(
    paste0("packages-", format(Sys.time(), "%Y%m%d-%H%M%S"), "-"),
    tmpdir = rollback_root
  )
  if (!dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)) {
    stop("Failed to create the package rollback directory.", call. = FALSE)
  }

  moved <- character()
  for (package in existing) {
    source_path <- file.path(spec$library, package)
    backup_path <- file.path(backup_dir, package)
    if (!file.rename(source_path, backup_path)) {
      for (moved_package in rev(moved)) {
        file.rename(
          file.path(backup_dir, moved_package),
          file.path(spec$library, moved_package)
        )
      }
      unlink(backup_dir, recursive = TRUE, force = TRUE)
      stop(
        paste0(
          "Could not prepare package '", package, "' for a safe update. ",
          "Restart RStudio and run setup before loading DRB packages."
        ),
        call. = FALSE
      )
    }
    moved <- c(moved, package)
  }

  list(active = TRUE, directory = backup_dir, moved = moved)
}

drb_rollback_packages <- function(spec, plan, backup) {
  failures <- character()

  for (package in plan$backup_targets) {
    current_path <- file.path(spec$library, package)
    if (dir.exists(current_path)) {
      unlink(current_path, recursive = TRUE, force = TRUE)
      if (dir.exists(current_path)) {
        failures <- c(failures, paste0("remove ", package))
      }
    }
  }

  if (isTRUE(backup$active)) {
    for (package in backup$moved) {
      restored <- file.rename(
        file.path(backup$directory, package),
        file.path(spec$library, package)
      )
      if (!restored) failures <- c(failures, paste0("restore ", package))
    }
    unlink(backup$directory, recursive = TRUE, force = TRUE)
  }

  if (length(failures)) {
    paste0("Rollback needs manual attention: ", paste(failures, collapse = ", "), ".")
  } else if (isTRUE(backup$active)) {
    "The previously installed package versions were restored."
  } else {
    "No previously installed package was changed."
  }
}

drb_remove_backup <- function(backup) {
  if (!isTRUE(backup$active)) return(invisible(TRUE))
  unlink(backup$directory, recursive = TRUE, force = TRUE)
  invisible(!dir.exists(backup$directory))
}

drb_r_literal <- function(value) {
  paste(capture.output(dput(value)), collapse = "\n")
}

drb_restore_in_clean_process <- function(
    spec,
    packages,
    reusable_r_packages) {
  packages <- unique(as.character(packages))
  if (!length(packages)) {
    cat("      No package installation or update is required.\n")
    return(invisible(TRUE))
  }

  rscript <- file.path(R.home("bin"), "Rscript.exe")
  if (!file.exists(rscript)) {
    stop("Cannot locate Rscript for the current R installation: ", rscript,
         call. = FALSE)
  }

  restore_script <- tempfile(
    "drb-restore-",
    tmpdir = spec$root,
    fileext = ".R"
  )
  on.exit(unlink(restore_script, force = TRUE), add = TRUE)

  exclude <- unique(c(reusable_r_packages, "renv"))
  script <- c(
    paste0("project <- ", drb_r_literal(spec$project_dir)),
    paste0("lockfile <- ", drb_r_literal(spec$lockfile)),
    paste0("shared_library <- ", drb_r_literal(spec$library)),
    paste0("packages <- ", drb_r_literal(packages)),
    paste0("exclude <- ", drb_r_literal(exclude)),
    "Sys.unsetenv(c(\"RENV_PROFILE\", \"R_LIBS\", \"R_LIBS_USER\", \"R_LIBS_SITE\"))",
    paste0(
      "Sys.setenv(",
      "RENV_CONFIG_INSTALL_STAGED = \"FALSE\", ",
      "RENV_CONFIG_INSTALL_TRANSACTIONAL = \"FALSE\", ",
      "RENV_CONFIG_CACHE_SYMLINKS = \"FALSE\", ",
      "RENV_CONFIG_PAK_ENABLED = \"FALSE\")"
    ),
    "options(pkgType = \"win.binary\")",
    "options(install.packages.check.source = \"no\")",
    "options(install.packages.compile.from.source = \"never\")",
    "options(renv.verbose = TRUE)",
    ".libPaths(c(shared_library, R.home(\"library\")), include.site = FALSE)",
    paste0(
      "active <- normalizePath(.libPaths()[[1L]], winslash = \"/\", ",
      "mustWork = TRUE)"
    ),
    paste0(
      "target <- normalizePath(shared_library, winslash = \"/\", ",
      "mustWork = TRUE)"
    ),
    "if (!identical(tolower(active), tolower(target))) {",
    "  stop(\"The clean restore process selected the wrong package library.\", call. = FALSE)",
    "}",
    "loadNamespace(\"renv\", lib.loc = shared_library)",
    "renv::restore(",
    "  project = project,",
    "  lockfile = lockfile,",
    "  library = shared_library,",
    "  packages = packages,",
    "  exclude = exclude,",
    "  clean = FALSE,",
    "  transactional = FALSE,",
    "  prompt = FALSE",
    ")"
  )
  writeLines(script, restore_script, useBytes = TRUE)

  cat(
    "      Starting an isolated R restore process for ",
    length(packages), " package(s)...\n",
    sep = ""
  )
  exit_status <- system2(
    rscript,
    args = c("--vanilla", shQuote(restore_script)),
    stdout = "",
    stderr = ""
  )
  if (!identical(as.integer(exit_status), 0L)) {
    stop(
      "The isolated package restore process exited with status ",
      as.integer(exit_status),
      ". Review the restore output immediately above.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

drb_verify_restored_library <- function(spec, records, reusable_r_packages) {
  locked_packages <- names(records)
  problems <- character()

  for (package in locked_packages) {
    if (identical(package, "renv")) next

    if (package %in% reusable_r_packages) {
      installed <- drb_package_version_at(package, R.home("library"))
      if (is.na(installed)) {
        problems <- c(problems, paste0(package, " (missing from R library)"))
      }
      next
    }

    expected <- as.character(records[[package]][["Version"]])
    installed <- drb_package_version_at(package, spec$library)
    if (is.na(installed)) {
      problems <- c(problems, paste0(package, " (missing)"))
    } else if (!identical(installed, expected)) {
      problems <- c(
        problems,
        paste0(package, " (expected ", expected, ", installed ", installed, ")")
      )
    }
  }

  if (length(problems)) {
    stop(
      paste0(
        "The shared library does not match the selected lockfile:\n- ",
        paste(problems, collapse = "\n- ")
      ),
      call. = FALSE
    )
  }

  required <- drb_required_packages(spec$project_dir)
  missing_required <- required[!vapply(required, function(package) {
    !is.na(drb_package_version_at(package, spec$library))
  }, logical(1))]
  if (length(missing_required)) {
    stop(
      "Required runtime packages are missing: ",
      paste(missing_required, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

drb_acquire_setup_lock <- function(spec) {
  lock_dir <- file.path(spec$root, "setup.lock")
  if (dir.exists(lock_dir)) {
    age_hours <- as.numeric(difftime(
      Sys.time(),
      file.info(lock_dir)$mtime,
      units = "hours"
    ))
    if (is.finite(age_hours) && age_hours > 12) {
      unlink(lock_dir, recursive = TRUE, force = TRUE)
    }
  }

  if (!dir.create(lock_dir, recursive = FALSE, showWarnings = FALSE)) {
    stop(
      paste0(
        "Another DRB environment setup appears to be running. ",
        "Keep that RStudio session open until setup finishes, then retry."
      ),
      call. = FALSE
    )
  }

  owner_error <- tryCatch({
    writeLines(
      c(
        paste0("pid=", Sys.getpid()),
        paste0("started=", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")),
        paste0("project=", spec$project_dir)
      ),
      file.path(lock_dir, "owner.txt"),
      useBytes = TRUE
    )
    NULL
  }, error = identity)
  if (inherits(owner_error, "error")) {
    unlink(lock_dir, recursive = TRUE, force = TRUE)
    stop("Failed to record the DRB setup lock owner.", call. = FALSE)
  }
  lock_dir
}

drb_setup_environment <- function() {
  started_at <- Sys.time()
  spec <- drb_environment_activate(create = TRUE, stop_on_unsupported = TRUE)

  if (!file.exists(spec$lockfile)) {
    stop(
      "The lockfile for ", spec$environment, " is missing: ", spec$lockfile,
      call. = FALSE
    )
  }

  initial_status <- drb_environment_status(spec)
  if (isTRUE(initial_status$ready)) {
    cat(
      "DRB shared environment already matches this lockfile.\n",
      "Package restore skipped; no package was copied or linked.\n\n",
      sep = ""
    )
    drb_env()
    return(invisible(spec))
  }

  setup_lock <- drb_acquire_setup_lock(spec)
  on.exit(unlink(setup_lock, recursive = TRUE, force = TRUE), add = TRUE)

  options(pkgType = "win.binary")
  options(install.packages.check.source = "no")
  options(install.packages.compile.from.source = "never")
  Sys.setenv(
    RENV_CONFIG_INSTALL_STAGED = "FALSE",
    RENV_CONFIG_INSTALL_TRANSACTIONAL = "FALSE",
    RENV_CONFIG_CACHE_SYMLINKS = "FALSE",
    RENV_CONFIG_PAK_ENABLED = "FALSE"
  )

  stage <- "environment manager bootstrap"
  plan <- list(backup_targets = character())
  backup <- list(active = FALSE, directory = NA_character_, moved = character())
  packages_prepared <- FALSE

  result <- tryCatch({
    drb_bootstrap_renv(spec)

    stage <- "lockfile planning"
    cat("[2/4] Reading the selected lockfile and preparing a safe update...\n")
    records <- drb_lockfile_records(spec$lockfile)
    reusable_r_packages <- drb_reusable_r_packages(records)
    plan <- drb_restore_plan(records, spec$library, reusable_r_packages)
    backup <- drb_backup_packages(spec, plan$backup_targets)
    packages_prepared <- TRUE

    stage <- "shared library restore"
    cat(
      "[3/4] Restoring packages into: ", spec$library, "\n",
      "      Install/update: ", length(plan$install_or_update),
      "; remove obsolete: ", length(plan$remove), "\n",
      sep = ""
    )
    if (length(reusable_r_packages)) {
      cat(
        "      Reusing this R installation's recommended packages: ",
        paste(reusable_r_packages, collapse = ", "), "\n",
        sep = ""
      )
    }

    drb_restore_in_clean_process(
      spec,
      plan$install_or_update,
      reusable_r_packages
    )

    stage <- "post-restore verification"
    cat("[4/4] Verifying locked versions and recording the lock hash...\n")
    drb_verify_restored_library(spec, records, reusable_r_packages)
    drb_write_installed_lock_hash(spec, drb_lock_hash(spec$lockfile))
    if (!drb_remove_backup(backup)) {
      warning("The successful update backup could not be removed: ", backup$directory)
    }

    TRUE
  }, error = function(error) {
    rollback_message <- if (isTRUE(packages_prepared)) {
      drb_rollback_packages(spec, plan, backup)
    } else {
      "No previously installed package was changed."
    }
    stop(
      paste0(
        "DRB setup failed during ", stage, ".\n",
        conditionMessage(error), "\n",
        rollback_message, "\n",
        "The installed lock hash was not changed. Fix the reported cause and run setup again."
      ),
      call. = FALSE
    )
  })

  if (isTRUE(result)) {
    cat(
      "\nDRB shared environment is ready in ",
      drb_setup_elapsed(started_at), ".\n\n",
      sep = ""
    )
    drb_env()
  }

  invisible(spec)
}

invisible(drb_setup_environment())
