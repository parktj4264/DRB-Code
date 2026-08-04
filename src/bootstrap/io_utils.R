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

atomic_copy_file_bundle <- function(sources, paths, attempts = 5L) {
    if (length(sources) == 0L || length(sources) != length(paths)) {
        stop("sources and paths must have the same non-zero length.")
    }

    source_paths <- normalizePath(sources, winslash = "/", mustWork = TRUE)
    target_paths <- normalizePath(paths, winslash = "/", mustWork = FALSE)
    if (anyDuplicated(target_paths)) {
        stop("Bundle target paths must be unique.")
    }

    target_dirs <- unique(dirname(target_paths))
    for (target_dir in target_dirs) {
        if (!dir.exists(target_dir) && !dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)) {
            stop("Could not create output directory: ", target_dir)
        }
    }

    item_count <- length(source_paths)
    temp_paths <- character(item_count)
    backup_paths <- character(item_count)
    had_target <- file.exists(target_paths)
    published <- rep(FALSE, item_count)
    completed <- FALSE

    rollback_bundle <- function() {
        restore_errors <- character()
        for (i in rev(seq_len(item_count))) {
            if (published[[i]]) {
                if (file.exists(target_paths[[i]])) {
                    unlink(target_paths[[i]], force = TRUE)
                }
                if (file.exists(target_paths[[i]])) {
                    restore_errors <- c(restore_errors, target_paths[[i]])
                    next
                }
                published[[i]] <<- FALSE
            }
            if (nzchar(backup_paths[[i]]) && file.exists(backup_paths[[i]])) {
                if (!retry_file_rename(backup_paths[[i]], target_paths[[i]], attempts = attempts)) {
                    restore_errors <- c(restore_errors, target_paths[[i]])
                } else {
                    backup_paths[[i]] <<- ""
                }
            }
        }
        unique(restore_errors)
    }

    on.exit({
        if (!completed) {
            rollback_bundle()
        }
        for (temp_path in temp_paths[nzchar(temp_paths)]) {
            if (file.exists(temp_path)) unlink(temp_path, force = TRUE)
        }
        if (completed) {
            for (backup_path in backup_paths[nzchar(backup_paths)]) {
                if (file.exists(backup_path)) unlink(backup_path, force = TRUE)
            }
        }
    }, add = TRUE)

    for (i in seq_len(item_count)) {
        temp_paths[[i]] <- tempfile(
            pattern = paste0(".", basename(target_paths[[i]]), "_bundle_"),
            tmpdir = dirname(target_paths[[i]]),
            fileext = ".tmp"
        )
        copied <- isTRUE(file.copy(
            source_paths[[i]],
            temp_paths[[i]],
            overwrite = TRUE,
            copy.mode = TRUE,
            copy.date = TRUE
        ))
        source_size <- suppressWarnings(file.info(source_paths[[i]])$size)
        temp_size <- suppressWarnings(file.info(temp_paths[[i]])$size)
        if (
            !copied || !file.exists(temp_paths[[i]]) ||
            is.na(source_size) || is.na(temp_size) ||
            source_size <= 0 || temp_size != source_size
        ) {
            stop("Temporary bundle copy failed: ", temp_paths[[i]])
        }
    }

    for (i in seq_len(item_count)) {
        if (had_target[[i]]) {
            backup_paths[[i]] <- tempfile(
                pattern = paste0(".", basename(target_paths[[i]]), "_previous_"),
                tmpdir = dirname(target_paths[[i]]),
                fileext = ".bak"
            )
            if (!retry_file_rename(target_paths[[i]], backup_paths[[i]], attempts = attempts)) {
                stop("Could not replace latest bundle file (file may be locked): ", target_paths[[i]])
            }
        }
    }

    for (i in seq_len(item_count)) {
        if (!retry_file_rename(temp_paths[[i]], target_paths[[i]], attempts = attempts)) {
            restore_errors <- rollback_bundle()
            if (length(restore_errors) > 0L) {
                stop(
                    "PPT bundle publication failed and previous files could not be restored: ",
                    paste(restore_errors, collapse = ", ")
                )
            }
            stop("Could not publish latest bundle file: ", target_paths[[i]])
        }
        published[[i]] <- TRUE
        temp_paths[[i]] <- ""
    }

    completed <- TRUE
    invisible(target_paths)
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
