# DRB Shared Package Loading -------------------------------------------------
# Packages are installed once per Windows user and R minor version into the
# LocalAppData DRB library. Runtime code never installs or updates packages.
environment_bootstrap <- file.path("src", "bootstrap", "drb_environment.R")
if (!file.exists(environment_bootstrap)) {
  stop("The DRB environment bootstrap is missing.", call. = FALSE)
}
sys.source(environment_bootstrap, envir = globalenv())
drb_assert_environment_ready()

source("src/bootstrap/package_manifest.R", local = environment())

library_load <- function(packages) {
  packages <- unique(as.character(packages))
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing)) {
    stop(
      paste0(
        "The DRB shared environment is not ready. Missing: ",
        paste(missing, collapse = ", "), "\n",
        "Open DRB-Code.Rproj, then run 00_setup_environment.R once."
      ),
      call. = FALSE
    )
  }

  invisible(lapply(packages, function(package) {
    # CRAN Windows binaries can be built with a newer patch release in the
    # same R minor series (for example, 4.5.3 on R 4.5.2). That warning is
    # expected after a successful locked restore and is not actionable for a
    # normal DRB user.
    suppressWarnings(suppressPackageStartupMessages(
      library(package, character.only = TRUE, lib.loc = .libPaths())
    ))
  }))
}

# Core Package List ---------------------------------------------------------
cat("Loading DRB shared libraries...\n")

library_load(DRB_CORE_PACKAGES)

.DRB_LIBRARIES_LOADED <- TRUE
