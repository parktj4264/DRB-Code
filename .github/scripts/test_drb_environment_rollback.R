if (!identical(Sys.getenv("DRB_ENV_TEST_ALLOW_MUTATION"), "true")) {
  stop(
    "Set DRB_ENV_TEST_ALLOW_MUTATION=true only in an isolated test environment.",
    call. = FALSE
  )
}

local({
  source(".Rprofile")
  spec <- drb_environment_spec(project_dir = getwd(), create = FALSE)
  original_project <- getwd()
  original_project_option <- getOption("drb.environment.project", NULL)
  package <- "R6"
  package_path <- file.path(spec$library, package)
  description_file <- file.path(package_path, "DESCRIPTION")
  original_version <- as.character(read.dcf(
    description_file,
    fields = "Version"
  )[[1L, "Version"]])
  original_hash <- readLines(spec$hash_file, warn = FALSE, n = 1L)

  test_project <- file.path(spec$root, "environment-rollback-test-project")
  safety_root <- file.path(spec$root, "environment-rollback-test-safety")
  stopifnot(!dir.exists(test_project), !dir.exists(safety_root))
  dir.create(file.path(test_project, "src", "bootstrap"), recursive = TRUE)
  dir.create(
    file.path(test_project, "renv", "profiles", spec$profile),
    recursive = TRUE
  )
  dir.create(safety_root)
  stopifnot(file.copy(package_path, safety_root, recursive = TRUE))

  completed <- FALSE
  on.exit({
    setwd(original_project)
    if (!file.exists(description_file)) {
      file.copy(file.path(safety_root, package), spec$library, recursive = TRUE)
    }
    unlink(test_project, recursive = TRUE, force = TRUE)
    unlink(safety_root, recursive = TRUE, force = TRUE)
    options(drb.environment.project = original_project_option)
    if (!completed) {
      writeLines(original_hash, spec$hash_file, useBytes = TRUE)
    }
  }, add = TRUE)

  stopifnot(file.copy(
    "00_setup_environment.R",
    file.path(test_project, "00_setup_environment.R")
  ))
  stopifnot(file.copy(
    file.path("src", "bootstrap", "drb_environment.R"),
    file.path(test_project, "src", "bootstrap", "drb_environment.R")
  ))
  stopifnot(file.copy(
    file.path("src", "bootstrap", "package_manifest.R"),
    file.path(test_project, "src", "bootstrap", "package_manifest.R")
  ))
  writeLines("Version: 1.0", file.path(test_project, "DRB-Code.Rproj"))

  loadNamespace("renv", lib.loc = spec$library)
  lock <- renv::lockfile_read(spec$lockfile)
  lock$Packages[[package]][["Version"]] <- "999.999.999"
  lock$Packages[[package]][["Hash"]] <- NULL
  test_lockfile <- file.path(
    test_project,
    "renv",
    "profiles",
    spec$profile,
    "renv.lock"
  )
  renv::lockfile_write(lock, file = test_lockfile)

  setwd(test_project)
  options(drb.environment.project = test_project)
  setup_error <- tryCatch({
    source("00_setup_environment.R")
    NULL
  }, error = identity)
  setwd(original_project)

  stopifnot(inherits(setup_error, "error"))
  stopifnot(grepl(
    "DRB setup failed during shared library restore",
    conditionMessage(setup_error),
    fixed = TRUE
  ))
  restored_version <- as.character(read.dcf(
    description_file,
    fields = "Version"
  )[[1L, "Version"]])
  stopifnot(identical(restored_version, original_version))
  stopifnot(identical(
    readLines(spec$hash_file, warn = FALSE, n = 1L),
    original_hash
  ))

  completed <- TRUE
  cat("FAILED_UPDATE_ROLLBACK_OK\n")
})
