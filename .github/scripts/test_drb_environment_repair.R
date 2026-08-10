if (!identical(Sys.getenv("DRB_ENV_TEST_ALLOW_MUTATION"), "true")) {
  stop(
    "Set DRB_ENV_TEST_ALLOW_MUTATION=true only in an isolated test environment.",
    call. = FALSE
  )
}

local({
  source(".Rprofile")
  spec <- drb_environment_spec(project_dir = getwd(), create = FALSE)
  expected_root <- normalizePath(
    file.path(Sys.getenv("LOCALAPPDATA"), "DRB"),
    winslash = "/",
    mustWork = TRUE
  )
  actual_root <- normalizePath(spec$root, winslash = "/", mustWork = TRUE)
  stopifnot(startsWith(tolower(actual_root), paste0(tolower(expected_root), "/")))

  package <- "R6"
  package_path <- file.path(spec$library, package)
  backup_path <- file.path(spec$root, "environment-repair-test-R6-backup")
  stopifnot(file.exists(file.path(package_path, "DESCRIPTION")))
  stopifnot(!dir.exists(backup_path))

  # Keep renv loaded in the parent session. The repair must still run from a
  # clean child R process and restore the package into the shared library.
  loadNamespace("renv", lib.loc = spec$library)
  stopifnot(file.rename(package_path, backup_path))
  unlink(spec$hash_file, force = TRUE)

  repaired <- FALSE
  on.exit({
    if (dir.exists(backup_path)) {
      if (dir.exists(package_path)) {
        unlink(package_path, recursive = TRUE, force = TRUE)
      }
      file.rename(backup_path, package_path)
    }
    if (!repaired) unlink(spec$hash_file, force = TRUE)
  }, add = TRUE)

  source("00_setup_environment.R")
  info <- drb_env()
  stopifnot(isTRUE(info$ready))
  stopifnot(file.exists(file.path(package_path, "DESCRIPTION")))
  stopifnot(!dir.exists("renv/library"))
  stopifnot(!dir.exists(file.path("renv", "profiles", spec$profile, "renv", "library")))

  repaired <- TRUE
  unlink(backup_path, recursive = TRUE, force = TRUE)
  stopifnot(!dir.exists(backup_path))
  cat("PARTIAL_SHARED_LIBRARY_REPAIR_OK\n")
})
