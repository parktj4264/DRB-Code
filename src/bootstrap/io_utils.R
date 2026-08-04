#' @title Atomic Output Utilities
#' @description Safely publishes generated files without leaving partial outputs.

retry_file_rename <- function(from, to, attempts = 5L) {
    attempts <- max(1L, suppressWarnings(as.integer(attempts)[1]))
    for (attempt in seq_len(attempts)) {
        renamed <- isTRUE(suppressWarnings(file.rename(from, to)))
        if (renamed) {
            return(TRUE)
        }
        if (attempt < attempts) {
            Sys.sleep(0.05 * attempt)
        }
    }
    FALSE
}

atomic_copy_file <- function(source, path, attempts = 5L) {
    source_path <- normalizePath(source, winslash = "/", mustWork = TRUE)
    target_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (identical(source_path, target_path)) {
        return(invisible(target_path))
    }

    target_dir <- dirname(target_path)
    if (!dir.exists(target_dir) && !dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Could not create output directory: ", target_dir)
    }

    temp_path <- tempfile(
        pattern = paste0(".", basename(target_path), "_"),
        tmpdir = target_dir,
        fileext = ".tmp"
    )
    backup_path <- NULL
    on.exit({
        if (file.exists(temp_path)) {
            unlink(temp_path, force = TRUE)
        }
        if (!is.null(backup_path) && file.exists(backup_path)) {
            if (!file.exists(target_path)) {
                retry_file_rename(backup_path, target_path, attempts = attempts)
            } else {
                unlink(backup_path, force = TRUE)
            }
        }
    }, add = TRUE)

    copied <- isTRUE(file.copy(
        source_path,
        temp_path,
        overwrite = TRUE,
        copy.mode = TRUE,
        copy.date = TRUE
    ))
    source_size <- suppressWarnings(file.info(source_path)$size)
    temp_size <- suppressWarnings(file.info(temp_path)$size)
    if (
        !copied ||
        !file.exists(temp_path) ||
        is.na(source_size) ||
        is.na(temp_size) ||
        source_size <= 0 ||
        temp_size != source_size
    ) {
        stop("Temporary file copy failed: ", temp_path)
    }

    if (retry_file_rename(temp_path, target_path, attempts = attempts)) {
        return(invisible(target_path))
    }

    if (file.exists(target_path)) {
        backup_path <- tempfile(
            pattern = paste0(".", basename(target_path), "_previous_"),
            tmpdir = target_dir,
            fileext = ".bak"
        )
        if (!retry_file_rename(target_path, backup_path, attempts = attempts)) {
            stop("Could not replace latest file (file may be locked): ", target_path)
        }
    }

    if (!retry_file_rename(temp_path, target_path, attempts = attempts)) {
        restored <- is.null(backup_path) ||
            !file.exists(backup_path) ||
            retry_file_rename(backup_path, target_path, attempts = attempts)
        if (!restored) {
            stop(
                "Latest file publication failed and the previous file could not be restored. Backup: ",
                backup_path
            )
        }
        stop("Could not publish latest file: ", target_path)
    }

    if (!is.null(backup_path) && file.exists(backup_path)) {
        unlink(backup_path, force = TRUE)
    }
    invisible(target_path)
}

atomic_fwrite <- function(x, path, attempts = 5L) {
    target_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    target_dir <- dirname(target_path)
    if (!dir.exists(target_dir) && !dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Could not create output directory: ", target_dir)
    }

    temp_path <- tempfile(
        pattern = paste0(".", basename(target_path), "_"),
        tmpdir = target_dir,
        fileext = ".tmp"
    )
    backup_path <- NULL
    on.exit({
        if (file.exists(temp_path)) {
            unlink(temp_path, force = TRUE)
        }
        if (!is.null(backup_path) && file.exists(backup_path) && file.exists(target_path)) {
            unlink(backup_path, force = TRUE)
        }
    }, add = TRUE)

    data.table::fwrite(x, temp_path)
    if (!file.exists(temp_path) || is.na(file.info(temp_path)$size) || file.info(temp_path)$size <= 0) {
        stop("Temporary CSV write failed: ", temp_path)
    }

    # On platforms that support replacement rename, this is a single atomic
    # publication. The Windows fallback is rollback-oriented (not crash-atomic)
    # and restores the previous latest file when an ordinary rename fails.
    if (retry_file_rename(temp_path, target_path, attempts = attempts)) {
        return(invisible(target_path))
    }

    if (file.exists(target_path)) {
        backup_path <- tempfile(
            pattern = paste0(".", basename(target_path), "_previous_"),
            tmpdir = target_dir,
            fileext = ".bak"
        )
        if (!retry_file_rename(target_path, backup_path, attempts = attempts)) {
            stop("Could not replace latest CSV (file may be locked): ", target_path)
        }
    }

    if (!retry_file_rename(temp_path, target_path, attempts = attempts)) {
        restored <- is.null(backup_path) ||
            !file.exists(backup_path) ||
            retry_file_rename(backup_path, target_path, attempts = attempts)
        if (!restored) {
            stop(
                "Latest CSV publication failed and the previous file could not be restored. Backup: ",
                backup_path
            )
        }
        stop("Could not publish latest CSV: ", target_path)
    }

    if (!is.null(backup_path) && file.exists(backup_path)) {
        unlink(backup_path, force = TRUE)
    }
    invisible(target_path)
}
