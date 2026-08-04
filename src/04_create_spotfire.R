#' @title Create Spotfire Data Bundle
#' @description Writes fixed-path Spotfire inputs for a reusable DXP shell.

normalize_spotfire_generation_flag <- function(value, default = TRUE) {
    if (is.null(value) || length(value) == 0L) {
        return(isTRUE(default))
    }
    value <- value[[1L]]
    if (is.logical(value) && !is.na(value)) {
        return(isTRUE(value))
    }

    value_text <- toupper(trimws(as.character(value)))
    if (value_text %in% c("TRUE", "T", "YES", "Y", "1")) {
        return(TRUE)
    }
    if (value_text %in% c("FALSE", "F", "NO", "N", "0")) {
        return(FALSE)
    }

    log_msg(paste0(
        "[Warning] Invalid GENERATE_SPOTFIRE='", as.character(value),
        "'. Fallback to ", toupper(as.character(isTRUE(default))), "."
    ))
    isTRUE(default)
}

spotfire_type_from_vector <- function(x) {
    if (inherits(x, "POSIXt")) return("DateTime")
    if (inherits(x, "Date") || inherits(x, "IDate")) return("Date")
    if (inherits(x, "integer64")) return("LongInteger")
    if (is.logical(x)) return("Boolean")
    if (is.integer(x)) return("Integer")
    if (is.numeric(x)) return("Real")
    "String"
}

build_spotfire_raw_schema <- function(raw_path, sample_rows = 1000L) {
    source_path <- normalizePath(raw_path, winslash = "/", mustWork = TRUE)
    sample_rows <- max(1L, suppressWarnings(as.integer(sample_rows)[1]))
    sample_dt <- data.table::fread(
        source_path,
        nrows = sample_rows,
        showProgress = FALSE
    )
    partid_idx <- match("PARTID", names(sample_dt))
    if (is.na(partid_idx)) {
        stop("Spotfire raw export requires a PARTID column: ", source_path)
    }
    if (partid_idx == ncol(sample_dt)) {
        stop("Spotfire raw export found no MSR columns after PARTID: ", source_path)
    }

    types <- vapply(sample_dt, spotfire_type_from_vector, character(1))
    types[seq.int(partid_idx + 1L, ncol(sample_dt))] <- "Real"
    data.table::data.table(
        COLUMN = names(sample_dt),
        TYPE = unname(types),
        IS_MSR = seq_along(types) > partid_idx
    )
}

publish_spotfire_temp_file <- function(temp_path, path, attempts = 5L) {
    temp_path <- normalizePath(temp_path, winslash = "/", mustWork = TRUE)
    target_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    backup_path <- NULL
    on.exit({
        if (file.exists(temp_path)) unlink(temp_path, force = TRUE)
        if (!is.null(backup_path) && file.exists(backup_path)) {
            if (!file.exists(target_path)) {
                retry_file_rename(backup_path, target_path, attempts = attempts)
            } else {
                unlink(backup_path, force = TRUE)
            }
        }
    }, add = TRUE)

    if (retry_file_rename(temp_path, target_path, attempts = attempts)) {
        return(invisible(target_path))
    }
    if (file.exists(target_path)) {
        backup_path <- tempfile(
            pattern = paste0(".", basename(target_path), "_previous_"),
            tmpdir = dirname(target_path),
            fileext = ".bak"
        )
        if (!retry_file_rename(target_path, backup_path, attempts = attempts)) {
            stop("Could not replace Spotfire file (file may be locked): ", target_path)
        }
    }
    if (!retry_file_rename(temp_path, target_path, attempts = attempts)) {
        restored <- is.null(backup_path) ||
            !file.exists(backup_path) ||
            retry_file_rename(backup_path, target_path, attempts = attempts)
        if (!restored) {
            stop("Spotfire file publication failed and backup restore also failed: ", backup_path)
        }
        stop("Could not publish Spotfire file: ", target_path)
    }
    if (!is.null(backup_path) && file.exists(backup_path)) {
        unlink(backup_path, force = TRUE)
    }
    invisible(target_path)
}

write_spotfire_text_atomic <- function(lines, path) {
    target_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    target_dir <- dirname(target_path)
    if (!dir.exists(target_dir) && !dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Could not create Spotfire directory: ", target_dir)
    }
    temp_path <- tempfile(
        pattern = paste0(".", basename(target_path), "_"),
        tmpdir = target_dir,
        fileext = ".tmp"
    )
    on.exit(if (file.exists(temp_path)) unlink(temp_path, force = TRUE), add = TRUE)
    writeLines(lines, temp_path, useBytes = TRUE)
    publish_spotfire_temp_file(temp_path, target_path)
}

get_spotfire_raw_signature <- function(raw_path) {
    source_path <- normalizePath(raw_path, winslash = "/", mustWork = TRUE)
    info <- file.info(source_path)
    paste(
        "schema-v1",
        source_path,
        format(info$size, scientific = FALSE, trim = TRUE),
        sprintf("%.6f", as.numeric(info$mtime)),
        sep = "|"
    )
}

stream_raw_with_spotfire_type_row <- function(raw_path, temp_path, type_row, chunk_size = 1024L * 1024L) {
    source_path <- normalizePath(raw_path, winslash = "/", mustWork = TRUE)
    input <- file(source_path, open = "rb")
    output <- file(temp_path, open = "wb")
    on.exit(if (!is.null(input)) close(input), add = TRUE)
    on.exit(if (!is.null(output)) close(output), add = TRUE)

    header_bytes <- raw()
    type_bytes <- NULL
    repeat {
        chunk <- readBin(input, what = "raw", n = chunk_size)
        if (length(chunk) == 0L) {
            stop("Raw CSV has no data row after its header: ", source_path)
        }
        newline_idx <- which(chunk == as.raw(0x0A))[1]
        if (is.na(newline_idx)) {
            header_bytes <- c(header_bytes, chunk)
            if (length(header_bytes) > 16L * 1024L * 1024L) {
                stop("Raw CSV header is unexpectedly large: ", source_path)
            }
            next
        }

        header_bytes <- c(header_bytes, chunk[seq_len(newline_idx)])
        eol <- if (
            length(header_bytes) >= 2L &&
            identical(header_bytes[(length(header_bytes) - 1L):length(header_bytes)], as.raw(c(0x0D, 0x0A)))
        ) "\r\n" else "\n"
        type_bytes <- charToRaw(paste0(type_row, eol))
        writeBin(header_bytes, output)
        writeBin(type_bytes, output)
        if (newline_idx < length(chunk)) {
            writeBin(chunk[(newline_idx + 1L):length(chunk)], output)
        }
        break
    }

    repeat {
        chunk <- readBin(input, what = "raw", n = chunk_size)
        if (length(chunk) == 0L) break
        writeBin(chunk, output)
    }
    close(output)
    output <- NULL

    source_size <- file.info(source_path)$size
    temp_size <- file.info(temp_path)$size
    expected_size <- source_size + length(type_bytes)
    if (!is.finite(temp_size) || temp_size != expected_size) {
        stop("Spotfire raw CSV size validation failed: ", temp_path)
    }
    invisible(temp_path)
}

write_spotfire_raw_csv <- function(raw_path, path, sample_rows = 1000L) {
    source_path <- normalizePath(raw_path, winslash = "/", mustWork = TRUE)
    target_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    target_dir <- dirname(target_path)
    if (!dir.exists(target_dir) && !dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Could not create Spotfire directory: ", target_dir)
    }

    signature <- get_spotfire_raw_signature(source_path)
    signature_path <- file.path(target_dir, ".raw_source_signature")
    existing_signature <- if (file.exists(signature_path)) {
        readLines(signature_path, n = 1L, warn = FALSE)
    } else {
        character()
    }
    if (file.exists(target_path) && identical(existing_signature, signature)) {
        return(list(path = target_path, updated = FALSE, schema = NULL))
    }

    schema <- build_spotfire_raw_schema(source_path, sample_rows = sample_rows)
    type_row <- paste(schema$TYPE, collapse = ",")
    temp_path <- tempfile(
        pattern = paste0(".", basename(target_path), "_"),
        tmpdir = target_dir,
        fileext = ".tmp"
    )
    on.exit(if (file.exists(temp_path)) unlink(temp_path, force = TRUE), add = TRUE)
    stream_raw_with_spotfire_type_row(source_path, temp_path, type_row)
    publish_spotfire_temp_file(temp_path, target_path)
    write_spotfire_text_atomic(signature, signature_path)
    list(path = target_path, updated = TRUE, schema = schema)
}

empty_spotfire_goobae_table <- function() {
    data.table::data.table(
        GOOBAE_Category1 = character(),
        GOOBAE_Category2 = character(),
        GOOBAE_NAME = character(),
        GOOBAE_ORDER = numeric(),
        MSR = character(),
        GROUP = character(),
        VALUE = numeric()
    )
}

build_spotfire_goobae_table <- function(result_dt, dt) {
    result <- data.table::copy(data.table::as.data.table(result_dt))
    raw_dt <- data.table::as.data.table(dt)
    required_result <- c("MSR", "GOOBAE_Category1", "GOOBAE_Category2", "GOOBAE_NAME", "GOOBAE_ORDER")
    if (!all(required_result %in% names(result)) || !"GROUP" %in% names(raw_dt)) {
        return(empty_spotfire_goobae_table())
    }

    mapping <- unique(result[, ..required_result])
    for (column in setdiff(required_result, "GOOBAE_ORDER")) {
        mapping[, (column) := trimws(as.character(get(column)))]
        mapping[is.na(get(column)), (column) := ""]
    }
    mapping[, GOOBAE_ORDER := suppressWarnings(as.numeric(GOOBAE_ORDER))]
    mapping <- mapping[
        nzchar(MSR) & nzchar(GOOBAE_Category1) & nzchar(GOOBAE_Category2) &
            nzchar(GOOBAE_NAME) & is.finite(GOOBAE_ORDER)
    ]
    if (nrow(mapping) == 0L) {
        return(empty_spotfire_goobae_table())
    }

    msr_columns <- intersect(mapping$MSR, names(raw_dt))
    if (length(msr_columns) == 0L) {
        return(empty_spotfire_goobae_table())
    }
    long_dt <- data.table::melt(
        raw_dt[, c("GROUP", msr_columns), with = FALSE],
        id.vars = "GROUP",
        measure.vars = msr_columns,
        variable.name = "MSR",
        value.name = "VALUE",
        variable.factor = FALSE
    )
    long_dt[, GROUP := trimws(as.character(GROUP))]
    long_dt[, MSR := as.character(MSR)]
    long_dt[, VALUE := suppressWarnings(as.numeric(VALUE))]
    long_dt <- long_dt[!is.na(GROUP) & nzchar(GROUP)]
    average_dt <- long_dt[
        ,
        .(VALUE = {
            finite_values <- VALUE[is.finite(VALUE)]
            if (length(finite_values) == 0L) NA_real_ else mean(finite_values)
        }),
        by = .(MSR, GROUP)
    ]

    out <- merge(mapping, average_dt, by = "MSR", all = FALSE, sort = FALSE)
    data.table::setcolorder(out, names(empty_spotfire_goobae_table()))
    data.table::setorderv(
        out,
        c("GOOBAE_Category1", "GOOBAE_Category2", "GOOBAE_ORDER", "GROUP", "MSR")
    )
    out[]
}

write_spotfire_bundle <- function(result_dt, sigma_dt, dt, raw_path, root_path, output_dir) {
    output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)
    if (!dir.exists(output_dir) && !dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Could not create Spotfire output directory: ", output_dir)
    }

    results_path <- file.path(output_dir, "results.csv")
    sigma_path <- file.path(output_dir, "sigma_score_raw.csv")
    goobae_path <- file.path(output_dir, "goobae.csv")
    raw_path_out <- file.path(output_dir, "raw.csv")
    root_path_out <- file.path(output_dir, "rootid.csv")
    atomic_fwrite(data.table::as.data.table(result_dt), results_path)
    atomic_fwrite(data.table::as.data.table(sigma_dt), sigma_path)
    atomic_fwrite(build_spotfire_goobae_table(result_dt, dt), goobae_path)
    atomic_fwrite(data.table::fread(root_path, showProgress = FALSE), root_path_out)
    raw_result <- write_spotfire_raw_csv(raw_path, raw_path_out)

    list(
        output_dir = output_dir,
        results_path = results_path,
        sigma_path = sigma_path,
        goobae_path = goobae_path,
        root_path = root_path_out,
        raw_path = raw_result$path,
        raw_updated = raw_result$updated
    )
}
