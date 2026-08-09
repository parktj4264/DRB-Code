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

cat("[3/3] Confirming lockfile status...\n")
status <- renv::status(project = project_dir)
if (!isTRUE(status$synchronized)) {
  stop(
    "The project library does not match its profile lockfile. Run 00_setup_environment.R again.",
    call. = FALSE
  )
}

cat(
  "\nDRB environment is ready.\n",
  "Selected profile: ", profile, " (R ", current_r, ").\n",
  "Everyday use: reopen DRB-Code.Rproj, then run run_gui.R.\n",
  sep = ""
)
