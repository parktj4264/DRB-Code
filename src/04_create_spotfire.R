#' @title Create Spotfire Data Bundle
#' @description Writes fixed-path Spotfire inputs for a reusable DXP shell.

normalize_spotfire_group_vector <- function(x) {
    values <- trimws(as.character(x))
    unique(values[!is.na(values) & nzchar(values)])
}

get_spotfire_sigma_columns <- function() {
    c(
        "run_id", "generated_at", "raw_file", "MSR", "item_name",
        "item_group_id", "ref_group", "target_group", "mean_ref", "mean_tgt",
        "sd_ref", "sd_tgt", "n_ref_wf", "n_tgt_wf", "n_ref_valid",
        "n_tgt_valid", "sigma_score", "abs_sigma_score", "direction",
        "is_selected_pair", "sigma_threshold", "SPEC_TYPE", "SPEC_TYPE_KO",
        paste0("Category", 1:5),
        "SLIDE_REQUIRED_YN", "SUMMARY_REQUIRED_YN"
    )
}

empty_spotfire_sigma_table <- function() {
    out <- data.table::data.table(
        run_id = character(),
        generated_at = character(),
        raw_file = character(),
        MSR = character(),
        item_name = character(),
        item_group_id = character(),
        ref_group = character(),
        target_group = character(),
        mean_ref = numeric(),
        mean_tgt = numeric(),
        sd_ref = numeric(),
        sd_tgt = numeric(),
        n_ref_wf = integer(),
        n_tgt_wf = integer(),
        n_ref_valid = numeric(),
        n_tgt_valid = numeric(),
        sigma_score = numeric(),
        abs_sigma_score = numeric(),
        direction = character(),
        is_selected_pair = logical(),
        sigma_threshold = numeric()
    )
    for (column in c(
        "SPEC_TYPE", "SPEC_TYPE_KO", paste0("Category", 1:5),
        "SLIDE_REQUIRED_YN", "SUMMARY_REQUIRED_YN"
    )) {
        out[, (column) := character()]
    }
    data.table::setcolorder(out, get_spotfire_sigma_columns())
    out
}

build_spotfire_sigma_table <- function(
    result_dt,
    dt,
    final_ref,
    final_tgt,
    sigma_threshold,
    raw_filename,
    generated_at = Sys.time()
) {
    result <- data.table::copy(data.table::as.data.table(result_dt))
    if (nrow(result) == 0L) {
        return(empty_spotfire_sigma_table())
    }
    if (!"MSR" %in% names(result)) {
        stop("Spotfire sigma export requires an MSR column.")
    }

    ref_groups <- normalize_spotfire_group_vector(final_ref)
    target_groups <- normalize_spotfire_group_vector(final_tgt)
    pair_specs <- data.table::rbindlist(lapply(ref_groups, function(ref_group) {
        valid_targets <- target_groups[target_groups != ref_group]
        if (length(valid_targets) == 0L) {
            return(NULL)
        }
        data.table::data.table(
            ref_group = rep(ref_group, length(valid_targets)),
            target_group = valid_targets
        )
    }), use.names = TRUE)
    if (nrow(pair_specs) == 0L) {
        return(empty_spotfire_sigma_table())
    }

    get_numeric_column <- function(column_name) {
        if (!column_name %in% names(result)) {
            return(rep(NA_real_, nrow(result)))
        }
        suppressWarnings(as.numeric(result[[column_name]]))
    }
    get_text_column <- function(column_name) {
        if (!column_name %in% names(result)) {
            return(rep(NA_character_, nrow(result)))
        }
        values <- as.character(result[[column_name]])
        values[is.na(values)] <- NA_character_
        values
    }

    pair_score_columns <- vapply(seq_len(nrow(pair_specs)), function(i) {
        pair_id <- paste0(pair_specs$ref_group[i], "_", pair_specs$target_group[i])
        pair_column <- paste0("metric_one_sigma_", pair_id)
        legacy_pair_column <- paste0("Sigma_Score_", pair_id)
        if (pair_column %in% names(result)) {
            pair_column
        } else if (legacy_pair_column %in% names(result)) {
            legacy_pair_column
        } else if (nrow(pair_specs) == 1L && "metric_one_sigma" %in% names(result)) {
            "metric_one_sigma"
        } else {
            NA_character_
        }
    }, character(1))
    pair_scores <- lapply(pair_score_columns, function(column_name) {
        if (is.na(column_name)) rep(NA_real_, nrow(result)) else get_numeric_column(column_name)
    })
    score_matrix <- do.call(cbind, pair_scores)
    abs_matrix <- abs(score_matrix)
    abs_matrix[!is.finite(abs_matrix)] <- -Inf
    selected_pair_index <- max.col(abs_matrix, ties.method = "first")
    no_finite_pair <- rowSums(is.finite(score_matrix)) == 0L
    selected_pair_index[no_finite_pair] <- NA_integer_

    raw_dt <- data.table::as.data.table(dt)
    wafer_counts <- if (all(c("GROUP", "ROOTID") %in% names(raw_dt))) {
        raw_dt[, .(n_wf = data.table::uniqueN(ROOTID)), by = GROUP]
    } else {
        data.table::data.table(GROUP = character(), n_wf = integer())
    }
    get_wafer_count <- function(group_name) {
        count <- wafer_counts[as.character(GROUP) == group_name, n_wf]
        if (length(count) == 0L) NA_integer_ else as.integer(count[[1]])
    }

    threshold <- suppressWarnings(as.numeric(sigma_threshold)[1])
    if (!is.finite(threshold)) {
        threshold <- NA_real_
    }
    generated_at_text <- format(generated_at, "%Y-%m-%dT%H:%M:%S%z")
    run_id <- format(generated_at, "%Y%m%dT%H%M%S%z")

    rows <- lapply(seq_len(nrow(pair_specs)), function(pair_index) {
        ref_group <- as.character(pair_specs$ref_group[pair_index])
        target_group <- as.character(pair_specs$target_group[pair_index])
        score <- as.numeric(pair_scores[[pair_index]])
        direction <- rep("Stable", length(score))
        if (is.finite(threshold)) {
            direction[is.finite(score) & score > threshold] <- "Up"
            direction[is.finite(score) & score < -threshold] <- "Down"
        }
        direction[!is.finite(score)] <- NA_character_

        pair_dt <- data.table::data.table(
            run_id = rep(run_id, nrow(result)),
            generated_at = rep(generated_at_text, nrow(result)),
            raw_file = rep(basename(raw_filename), nrow(result)),
            MSR = as.character(result$MSR),
            item_name = get_text_column("ITEM_NAME"),
            item_group_id = get_text_column("ITEM_GROUP_ID"),
            ref_group = rep(ref_group, nrow(result)),
            target_group = rep(target_group, nrow(result)),
            mean_ref = get_numeric_column(paste0("Mean_", ref_group)),
            mean_tgt = get_numeric_column(paste0("Mean_", target_group)),
            sd_ref = get_numeric_column(paste0("SD_", ref_group)),
            sd_tgt = get_numeric_column(paste0("SD_", target_group)),
            n_ref_wf = rep(get_wafer_count(ref_group), nrow(result)),
            n_tgt_wf = rep(get_wafer_count(target_group), nrow(result)),
            n_ref_valid = get_numeric_column(paste0("N_valid_", ref_group)),
            n_tgt_valid = get_numeric_column(paste0("N_valid_", target_group)),
            sigma_score = score,
            abs_sigma_score = abs(score),
            direction = direction,
            is_selected_pair = !no_finite_pair & selected_pair_index == pair_index,
            sigma_threshold = rep(threshold, nrow(result)),
            SPEC_TYPE = normalize_msrinfo_spec_type(get_text_column("SPEC_TYPE")),
            SPEC_TYPE_KO = msrinfo_spec_type_label_ko(get_text_column("SPEC_TYPE"))
        )
        for (column in c(paste0("Category", 1:5), "SLIDE_REQUIRED_YN", "SUMMARY_REQUIRED_YN")) {
            pair_dt[, (column) := get_text_column(column)]
        }
        pair_dt
    })

    out <- data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
    data.table::setcolorder(out, get_spotfire_sigma_columns())
    data.table::setorderv(out, c("MSR", "ref_group", "target_group"))
    out[]
}

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

normalize_spotfire_open_flag <- function(value, default = FALSE) {
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
        "[Warning] Invalid OPEN_SPOTFIRE='", as.character(value),
        "'. Fallback to ", toupper(as.character(isTRUE(default))), "."
    ))
    isTRUE(default)
}

normalize_spotfire_dxp_filename <- function(value, default = "drb_spotfire.dxp") {
    if (is.null(value) || length(value) == 0L) {
        return(default)
    }
    file_name <- trimws(as.character(value)[1L])
    if (is.na(file_name) || !nzchar(file_name)) default else file_name
}

resolve_spotfire_dxp_path <- function(
    dxp_filename = "drb_spotfire.dxp",
    spotfire_dir = here::here("spotfire")
) {
    file_name <- normalize_spotfire_dxp_filename(dxp_filename)
    is_absolute <- (
        grepl("^[A-Za-z]:[/\\\\]", file_name) ||
            startsWith(file_name, "/") ||
            startsWith(file_name, "\\\\")
    )
    path <- if (is_absolute) file_name else file.path(spotfire_dir, file_name)
    normalizePath(path.expand(path), winslash = "/", mustWork = FALSE)
}

default_spotfire_dxp_opener <- function(path) {
    if (.Platform$OS.type == "windows") {
        shell.exec(normalizePath(path, winslash = "\\", mustWork = TRUE))
        return(invisible(TRUE))
    }

    command <- if (identical(Sys.info()[["sysname"]], "Darwin")) "open" else "xdg-open"
    if (!nzchar(Sys.which(command))) {
        stop("No desktop file opener is available: ", command)
    }
    status <- system2(command, shQuote(path), wait = FALSE, stdout = FALSE, stderr = FALSE)
    if (!identical(as.integer(status), 0L)) {
        stop("Desktop file opener returned status ", status, ".")
    }
    invisible(TRUE)
}

open_spotfire_dxp <- function(
    enabled,
    dxp_filename = "drb_spotfire.dxp",
    spotfire_dir = here::here("spotfire"),
    opener = NULL
) {
    open_enabled <- normalize_spotfire_open_flag(enabled, default = FALSE)
    if (!open_enabled) {
        return(list(
            enabled = FALSE,
            attempted = FALSE,
            opened = FALSE,
            path = NULL,
            reason = "disabled"
        ))
    }

    path <- resolve_spotfire_dxp_path(dxp_filename, spotfire_dir = spotfire_dir)
    if (!file.exists(path)) {
        log_msg(paste0(
            "[Warning] Spotfire DXP not found; open skipped: ",
            path
        ))
        return(list(
            enabled = TRUE,
            attempted = FALSE,
            opened = FALSE,
            path = path,
            reason = "not_found"
        ))
    }

    if (is.null(opener)) {
        opener <- default_spotfire_dxp_opener
    }
    open_error <- tryCatch(
        {
            opener(path)
            NULL
        },
        error = identity
    )
    if (!is.null(open_error)) {
        log_msg(paste0(
            "[Warning] Spotfire DXP could not be opened; analysis will continue: ",
            conditionMessage(open_error)
        ))
        return(list(
            enabled = TRUE,
            attempted = TRUE,
            opened = FALSE,
            path = path,
            reason = "open_failed"
        ))
    }

    log_msg(paste0("Spotfire DXP open requested: ", path))
    list(
        enabled = TRUE,
        attempted = TRUE,
        opened = TRUE,
        path = path,
        reason = "opened"
    )
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

get_spotfire_raw_output_name <- function(raw_path) {
    paste0(tools::file_path_sans_ext(basename(raw_path)), "_spotfire.csv")
}

write_spotfire_bundle <- function(result_dt, sigma_dt, dt, raw_path, root_path, output_dir) {
    output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)
    if (!dir.exists(output_dir) && !dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Could not create Spotfire output directory: ", output_dir)
    }

    results_path <- file.path(output_dir, "results.csv")
    sigma_path <- file.path(output_dir, "sigma_score_raw.csv")
    goobae_path <- file.path(output_dir, "goobae.csv")
    raw_output_name <- get_spotfire_raw_output_name(raw_path)
    raw_path_out <- file.path(output_dir, raw_output_name)
    legacy_raw_path <- file.path(output_dir, "raw.csv")
    root_path_out <- file.path(output_dir, "rootid.csv")
    atomic_fwrite(data.table::as.data.table(result_dt), results_path)
    atomic_fwrite(data.table::as.data.table(sigma_dt), sigma_path)
    atomic_fwrite(build_spotfire_goobae_table(result_dt, dt), goobae_path)
    atomic_fwrite(data.table::fread(root_path, showProgress = FALSE), root_path_out)
    raw_result <- write_spotfire_raw_csv(raw_path, raw_path_out)
    legacy_raw_removed <- FALSE
    if (file.exists(legacy_raw_path)) {
        legacy_raw_removed <- isTRUE(unlink(legacy_raw_path, force = TRUE) == 0L) &&
            !file.exists(legacy_raw_path)
        if (!legacy_raw_removed) {
            log_msg(paste0(
                "[Warning] Could not remove legacy Spotfire raw file (file may be locked): ",
                legacy_raw_path
            ))
        }
    }

    list(
        output_dir = output_dir,
        results_path = results_path,
        sigma_path = sigma_path,
        goobae_path = goobae_path,
        root_path = root_path_out,
        raw_path = raw_result$path,
        raw_updated = raw_result$updated,
        legacy_raw_removed = legacy_raw_removed
    )
}
