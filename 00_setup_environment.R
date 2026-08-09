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
source(activate_file, local = globalenv())

options(pkgType = "win.binary")
options(install.packages.check.source = "no")
options(install.packages.compile.from.source = "never")

source("src/bootstrap/package_manifest.R", local = environment())

cat("\n[1/3] Restoring the DRB project package environment...\n")
renv::restore(project = project_dir, prompt = FALSE)

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
