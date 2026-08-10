#' @title DRB Environment Setup
#' @description Restore the reviewed project package environment once per PC.

# Run this once after opening DRB-Code.Rproj in RStudio. Do not run it as part
# of normal analysis; afterwards, run_gui.R is the everyday entry point.

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    if (file.exists(file.path(current, "DRB-Code.Rproj"))) return(current)
    parent <- dirname(current)
    if (identical(parent, current)) break
    current <- parent
  }

  stop("Open DRB-Code.Rproj, then run 00_setup_environment.R.", call. = FALSE)
}

project_dir <- find_project_root()
setwd(project_dir)

if (.Platform$OS.type != "windows") {
  stop("DRB's reviewed environment currently supports Windows RStudio only.", call. = FALSE)
}

current_r <- as.character(getRversion())
r_minor <- paste0(
  R.version$major,
  ".",
  sub("^([0-9]+).*", "\\1", R.version$minor)
)
profile <- switch(
  r_minor,
  "4.1" = "r-4.1",
  "4.5" = "r-4.5",
  NULL
)
if (is.null(profile)) {
  stop(
    paste0(
      "This project currently supports R 4.1.x and R 4.5.x (current: R ", current_r, ").\n",
      "Select R 4.1.3 or R 4.5.x in RStudio, reopen DRB-Code.Rproj, then run this setup file again."
    ),
    call. = FALSE
  )
}

activate_file <- file.path(project_dir, "renv", "activate.R")
if (!file.exists(activate_file)) {
  stop("The project's renv bootstrap is missing. Download the complete project again.", call. = FALSE)
}

# Opening the RStudio project normally performs this via .Rprofile. Set the
# same profile here before activation for users who source setup elsewhere.
Sys.setenv(RENV_PROFILE = profile)
Sys.setenv(RENV_CONFIG_SYNCHRONIZED_CHECK = "FALSE")
# Match .Rprofile when this file is sourced directly: packages already present
# in this Windows user's renv cache can be linked into this project instead of
# copied. renv automatically falls back to copying when linking is unavailable.
Sys.setenv(RENV_CONFIG_CACHE_SYMLINKS = "TRUE")
source(activate_file, local = globalenv())

options(pkgType = "win.binary")
options(install.packages.check.source = "no")
options(install.packages.compile.from.source = "never")

source("src/bootstrap/package_manifest.R", local = environment())

# These packages are included with a standard Windows R installation. The R
# 4.1 lockfile records them because it was captured from the full R library.
DRB_R_RECOMMENDED_PACKAGES <- c("MASS", "Matrix", "lattice", "mgcv", "nlme")

get_installed_r_recommended_packages <- function() {
  default_r_library <- R.home("library")

  DRB_R_RECOMMENDED_PACKAGES[
    vapply(DRB_R_RECOMMENDED_PACKAGES, function(package) {
      description <- tryCatch(
        utils::packageDescription(package, lib.loc = default_r_library),
        error = function(error) NULL
      )
      !is.null(description) && nzchar(description[["Version"]])
    }, logical(1))
  ]
}

format_setup_elapsed <- function(started_at) {
  elapsed_seconds <- max(0, round(as.numeric(difftime(Sys.time(), started_at, units = "secs"))))

  if (elapsed_seconds < 60) {
    return(paste0(elapsed_seconds, " sec"))
  }

  paste0(elapsed_seconds %/% 60, " min ", sprintf("%02d", elapsed_seconds %% 60), " sec")
}

get_restore_package_count <- function(project, exclude = character()) {
  # renv does not expose this restore plan as a public API. This optional
  # preflight is only for a user-facing progress denominator; restore itself
  # remains the source of truth and still runs if the preflight cannot decide.
  tryCatch({
    actions <- renv:::renv_actions_restore(
      project = project,
      library = renv:::renv_libpaths_active(),
      lockfile = renv:::renv_lockfile_load(project = project),
      clean = FALSE
    )
    sum(actions != "remove" & !(names(actions) %in% exclude))
  }, error = function(error) {
    NA_integer_
  })
}

restore_with_progress <- function(project) {
  reusable_r_packages <- get_installed_r_recommended_packages()
  package_count <- get_restore_package_count(project, exclude = reusable_r_packages)
  restore_started_at <- Sys.time()

  cat("\n[1/3] Restoring the DRB project package environment...\n")
  if (length(reusable_r_packages)) {
    cat(
      "      Reusing R's already-installed standard packages: ",
      paste(reusable_r_packages, collapse = ", "), ".\n",
      sep = ""
    )
  }
  if (!is.na(package_count) && package_count > 0L) {
    cat(
      "      ", package_count, " package(s) need installation or update.\n",
      "      Download details are printed by renv below; installation progress uses\n",
      "      [DRB restore current/total | percent]. Keep RStudio open until [2/3] appears.\n",
      sep = ""
    )
  } else if (!is.na(package_count)) {
    cat("      The package library already matches the lockfile; checking it once more.\n")
  } else {
    cat("      Download and installation details are printed by renv below.\n")
  }

  old_renv_verbose <- getOption("renv.verbose")
  options(renv.verbose = TRUE)

  progress_option <- "drb.setup.restore.progress"
  old_progress_state <- getOption(progress_option)
  trace_installed_package <- FALSE
  renv_namespace <- asNamespace("renv")

  if (!is.na(package_count) && package_count > 0L &&
      exists("renv_install_step_ok", envir = renv_namespace, inherits = FALSE)) {
    progress_state <- new.env(parent = emptyenv())
    progress_state$completed <- 0L
    progress_state$total <- package_count
    options(drb.setup.restore.progress = progress_state)

    trace_result <- tryCatch({
      suppressMessages(invisible(trace(
        "renv_install_step_ok",
        where = renv_namespace,
        tracer = quote({
          state <- getOption("drb.setup.restore.progress")
          if (!is.null(state)) {
            state$completed <- state$completed + 1L
            percent <- min(100L, round(100 * state$completed / state$total))
            cat(
              sprintf(
                "[DRB restore %d/%d | %d%%] %s\n",
                state$completed,
                state$total,
                percent,
                record$Package
              )
            )
            flush.console()
          }
        }),
        print = FALSE
      )))
      NULL
    }, error = identity)
    trace_installed_package <- is.null(trace_result)
  }

  on.exit({
    if (trace_installed_package) {
      suppressMessages(untrace("renv_install_step_ok", where = renv_namespace))
    }

    if (is.null(old_renv_verbose)) {
      options(renv.verbose = NULL)
    } else {
      options(renv.verbose = old_renv_verbose)
    }

    if (is.null(old_progress_state)) {
      options(drb.setup.restore.progress = NULL)
    } else {
      options(drb.setup.restore.progress = old_progress_state)
    }
  }, add = TRUE)

  renv::restore(
    project = project,
    exclude = reusable_r_packages,
    prompt = FALSE
  )
  cat("[1/3] Package restore finished in ", format_setup_elapsed(restore_started_at), ".\n", sep = "")
}

restore_with_progress(project_dir)

cat("[2/3] Verifying required packages...\n")
missing <- DRB_REQUIRED_PACKAGES[
  !vapply(DRB_REQUIRED_PACKAGES, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing)) {
  stop(
    paste0("Restore completed but packages are missing: ", paste(missing, collapse = ", ")),
    call. = FALSE
  )
}

cat("[3/3] Confirming locked package versions...\n")
lock_path <- file.path(project_dir, "renv", "profiles", profile, "renv.lock")
lock <- jsonlite::fromJSON(lock_path, simplifyVector = FALSE)
expected_versions <- vapply(
  DRB_REQUIRED_PACKAGES,
  function(package) {
    record <- lock$Packages[[package]]
    if (is.null(record) || is.null(record$Version)) NA_character_ else record$Version
  },
  character(1)
)
missing_lock_records <- DRB_REQUIRED_PACKAGES[is.na(expected_versions)]
installed_versions <- vapply(
  DRB_REQUIRED_PACKAGES,
  function(package) as.character(utils::packageVersion(package)),
  character(1)
)
wrong_versions <- DRB_REQUIRED_PACKAGES[
  !is.na(expected_versions) & expected_versions != installed_versions
]

if (length(missing_lock_records) || length(wrong_versions)) {
  details <- c(
    if (length(missing_lock_records)) {
      paste0("Lockfile records missing: ", paste(missing_lock_records, collapse = ", "))
    },
    if (length(wrong_versions)) {
      paste0(
        "Version mismatch: ",
        paste(
          paste0(
            wrong_versions,
            " (expected ", expected_versions[wrong_versions],
            ", installed ", installed_versions[wrong_versions], ")"
          ),
          collapse = ", "
        )
      )
    }
  )
  stop(
    paste(c("The project environment does not match its profile lockfile.", details), collapse = "\n"),
    call. = FALSE
  )
}

cat(
  "\nDRB environment is ready.\n",
  "Selected profile: ", profile, " (R ", current_r, ").\n",
  "Everyday use: reopen DRB-Code.Rproj, then run run_gui.R.\n",
  sep = ""
)
