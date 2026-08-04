source("src/bootstrap/io_utils.R", local = environment())

bundle_dir <- tempfile("ppt_bundle_publish_")
stopifnot(dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE))
tryCatch({
  source_main <- file.path(bundle_dir, "archive_main.pptx")
  source_suggested <- file.path(bundle_dir, "archive_suggested.pptx")
  target_main <- file.path(bundle_dir, "latest_main.pptx")
  target_suggested <- file.path(bundle_dir, "latest_suggested.pptx")

  writeBin(as.raw(c(1, 2, 3, 4)), source_main)
  writeBin(as.raw(c(5, 6, 7, 8, 9)), source_suggested)
  writeBin(as.raw(c(91, 92)), target_main)
  writeBin(as.raw(c(93, 94)), target_suggested)

  atomic_copy_file_bundle(
    c(source_main, source_suggested),
    c(target_main, target_suggested)
  )
  stopifnot(identical(
    readBin(target_main, what = "raw", n = file.info(target_main)$size),
    readBin(source_main, what = "raw", n = file.info(source_main)$size)
  ))
  stopifnot(identical(
    readBin(target_suggested, what = "raw", n = file.info(target_suggested)$size),
    readBin(source_suggested, what = "raw", n = file.info(source_suggested)$size)
  ))

  main_hash_before <- unname(tools::md5sum(target_main))
  suggested_hash_before <- unname(tools::md5sum(target_suggested))
  missing_source_error <- tryCatch(
    {
      atomic_copy_file_bundle(
        c(source_main, file.path(bundle_dir, "missing.pptx")),
        c(target_main, target_suggested)
      )
      NULL
    },
    error = identity
  )
  stopifnot(inherits(missing_source_error, "error"))
  stopifnot(identical(unname(tools::md5sum(target_main)), main_hash_before))
  stopifnot(identical(unname(tools::md5sum(target_suggested)), suggested_hash_before))

  writeBin(as.raw(c(81, 82, 83)), target_main)
  writeBin(as.raw(c(84, 85, 86)), target_suggested)
  rollback_main_hash <- unname(tools::md5sum(target_main))
  rollback_suggested_hash <- unname(tools::md5sum(target_suggested))
  original_retry_file_rename <- retry_file_rename
  failure_target <- normalizePath(target_suggested, winslash = "/", mustWork = FALSE)
  failure_injected <- FALSE
  retry_file_rename <- function(from, to, attempts = 5L) {
    normalized_to <- normalizePath(to, winslash = "/", mustWork = FALSE)
    is_bundle_publish <- grepl("_bundle_", basename(from), fixed = TRUE)
    if (!failure_injected && is_bundle_publish && identical(normalized_to, failure_target)) {
      failure_injected <<- TRUE
      return(FALSE)
    }
    original_retry_file_rename(from, to, attempts = attempts)
  }
  publish_error <- tryCatch(
    {
      atomic_copy_file_bundle(
        c(source_main, source_suggested),
        c(target_main, target_suggested)
      )
      NULL
    },
    error = identity
  )
  retry_file_rename <- original_retry_file_rename
  stopifnot(inherits(publish_error, "error"))
  stopifnot(isTRUE(failure_injected))
  stopifnot(file.exists(target_main), file.exists(target_suggested))
  stopifnot(identical(unname(tools::md5sum(target_main)), rollback_main_hash))
  stopifnot(identical(unname(tools::md5sum(target_suggested)), rollback_suggested_hash))
  stopifnot(length(list.files(bundle_dir, pattern = "\\.(tmp|bak)$")) == 0L)
}, finally = {
  unlink(bundle_dir, recursive = TRUE, force = TRUE)
})

cat("PASS: test_ppt_bundle_publish.R\n")
