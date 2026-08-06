#' @title Load and Filter Data
#' @description Reads raw data, filters by Hot/Cold Bin rules, and merges with Group info.
#' @param raw_path STRING. Path to the large raw CSV.
#' @param root_path STRING. Path to the ROOTID mapping CSV.
#' @param good_chip_limit_hot NUMERIC/NULL. Legacy cutoff for 'LDS Hot Bin' (used only when rule is NULL).
#' @param good_chip_limit_cold NUMERIC/NULL. Legacy cutoff for 'LDS Cold Bin' (used only when rule is NULL).
#' @param good_chip_rule_hot FUNCTION/NULL. Rule function for Hot bin; input numeric vector, output logical vector.
#' @param good_chip_rule_cold FUNCTION/NULL. Rule function for Cold bin; input numeric vector, output logical vector.
#' @param msrinfo_path STRING/NULL. Optional msrinfo.csv path; FIELD values define MSR columns when available.
#' @param requested_msr_cols CHARACTER/NULL. Optional validated MSR subset for lightweight consumers such as GUI Preview.
#' @return A list containing the filtered data.table and a vector of MSR column names.

read_csv_header <- function(path) {
    # Some in-house data.table builds fail while auto-detecting a CSV with
    # nrows = 0. Reading one physical data row and then dropping it keeps the
    # same header-only contract while exercising fread's normal parser path.
    data.table::fread(path, nrows = 1L, showProgress = FALSE)[0]
}

validate_rootid_map <- function(map_dt, path_label = "ROOTID.csv") {
    map_dt <- data.table::copy(data.table::as.data.table(map_dt))
    data.table::setnames(
        map_dt,
        old = names(map_dt),
        new = sub("^\ufeff", "", trimws(names(map_dt)))
    )

    required_cols <- c("ROOTID", "GROUP")
    missing_cols <- setdiff(required_cols, names(map_dt))
    if (length(missing_cols) > 0L) {
        stop(
            path_label,
            " must contain columns: ",
            paste(required_cols, collapse = ", "),
            ". Missing: ",
            paste(missing_cols, collapse = ", ")
        )
    }

    map_dt[, ROOTID := trimws(as.character(ROOTID))]
    map_dt[, GROUP := trimws(as.character(GROUP))]
    invalid_rows <- which(
        is.na(map_dt$ROOTID) | !nzchar(map_dt$ROOTID) |
            is.na(map_dt$GROUP) | !nzchar(map_dt$GROUP)
    )
    if (length(invalid_rows) > 0L) {
        stop(
            path_label,
            " contains blank ROOTID or GROUP values at row(s): ",
            paste(utils::head(invalid_rows + 1L, 20L), collapse = ", "),
            if (length(invalid_rows) > 20L) " ..." else ""
        )
    }

    duplicate_rootids <- unique(map_dt[duplicated(ROOTID) | duplicated(ROOTID, fromLast = TRUE), ROOTID])
    if (length(duplicate_rootids) > 0L) {
        stop(
            path_label,
            " must map each ROOTID exactly once. Duplicate ROOTID value(s): ",
            paste(utils::head(duplicate_rootids, 20L), collapse = ", "),
            if (length(duplicate_rootids) > 20L) " ..." else ""
        )
    }

    map_dt
}

resolve_raw_msr_columns <- function(all_cols, msrinfo_path = NULL) {
    all_cols <- as.character(all_cols)
    if (!is.null(msrinfo_path) && length(msrinfo_path) > 0L && file.exists(msrinfo_path[[1L]])) {
        msrinfo_path <- as.character(msrinfo_path[[1L]])
        msrinfo_header <- names(read_csv_header(msrinfo_path))
        if (!"FIELD" %in% msrinfo_header) {
            stop(basename(msrinfo_path), " must contain a FIELD column.")
        }
        msr_info <- data.table::fread(msrinfo_path, select = "FIELD", showProgress = FALSE)
        configured <- trimws(as.character(msr_info$FIELD))
        configured <- configured[!is.na(configured) & nzchar(configured)]
        duplicate_fields <- unique(configured[duplicated(configured)])
        if (length(duplicate_fields) > 0L) {
            stop(
                basename(msrinfo_path),
                " contains duplicate FIELD values: ",
                paste(utils::head(duplicate_fields, 20L), collapse = ", "),
                if (length(duplicate_fields) > 20L) " ..." else ""
            )
        }
        matched <- configured[configured %in% all_cols]
        if (length(matched) == 0L) {
            stop("No FIELD values from ", basename(msrinfo_path), " were found in the Raw header.")
        }
        return(list(
            columns = matched,
            source = paste0(basename(msrinfo_path), " FIELD"),
            missing_configured = setdiff(configured, all_cols)
        ))
    }

    partid_idx <- which(all_cols == "PARTID")
    if (length(partid_idx) == 0L) {
        stop("MSR columns could not be resolved: msrinfo.csv was not found and Raw has no PARTID column.")
    }
    if (length(partid_idx) > 1L) {
        stop("Raw contains more than one PARTID column.")
    }
    if (partid_idx == length(all_cols)) {
        stop("'PARTID' is the last column. No MSR columns found.")
    }
    list(
        columns = all_cols[seq.int(partid_idx + 1L, length(all_cols))],
        source = "Raw columns after PARTID (msrinfo.csv not found)",
        missing_configured = character()
    )
}

coerce_msr_numeric <- function(values, column_name) {
    if (is.numeric(values)) {
        return(as.numeric(values))
    }
    if (is.factor(values)) {
        values <- as.character(values)
    }
    if (!is.character(values)) {
        stop("MSR column must be numeric or numeric text: ", column_name, " (type: ", typeof(values), ")")
    }

    text_values <- trimws(values)
    converted <- suppressWarnings(as.numeric(text_values))
    invalid <- !is.na(values) & nzchar(text_values) & is.na(converted)
    if (any(invalid)) {
        examples <- unique(text_values[invalid])
        stop(
            "MSR column contains non-numeric value(s): ",
            column_name,
            " | examples: ",
            paste(utils::head(examples, 5L), collapse = ", "),
            " | invalid rows: ",
            format(sum(invalid), big.mark = ",")
        )
    }
    converted
}

load_and_filter_data <- function(raw_path, root_path, good_chip_limit_hot = NULL, good_chip_limit_cold = NULL, good_chip_rule_hot = NULL, good_chip_rule_cold = NULL, msrinfo_path = NULL, requested_msr_cols = NULL) {
    # 1. Read Raw Data
    log_msg("Step 1: Inspecting file headers...")

    # Read header only to identify columns
    header_only <- read_csv_header(raw_path)
    all_cols <- names(header_only)

    msr_resolution <- resolve_raw_msr_columns(all_cols, msrinfo_path = msrinfo_path)
    msr_cols <- msr_resolution$columns
    if (!is.null(requested_msr_cols)) {
        requested_msr_cols <- unique(trimws(as.character(requested_msr_cols)))
        requested_msr_cols <- requested_msr_cols[!is.na(requested_msr_cols) & nzchar(requested_msr_cols)]
        if (length(requested_msr_cols) == 0L) {
            stop("requested_msr_cols must contain at least one MSR column name.")
        }
        invalid_requested <- setdiff(requested_msr_cols, msr_cols)
        if (length(invalid_requested) > 0L) {
            stop(
                "Requested MSR column(s) are not available: ",
                paste(invalid_requested, collapse = ", ")
            )
        }
        msr_cols <- requested_msr_cols
        msr_resolution$source <- paste0(msr_resolution$source, " | requested subset")
    }

    # PARTID remains the metadata boundary even when MSR columns come from msrinfo.csv.
    partid_idx <- which(all_cols == "PARTID")

    if (length(partid_idx) == 0) {
        fallback_meta_candidates <- c(
            "LOTID", "WF", "Chip", "X", "Y", "ROOTID", "Radius",
            "EDGE", "PIE", "8 INCH", "EDS Hot Bin", "EDS Cold Bin", "LDS Hot Bin", "LDS Cold Bin"
        )
        meta_cols <- intersect(fallback_meta_candidates, all_cols)
    } else {
        # Keep all metadata columns up to PARTID so raw_access can expose full context.
        meta_cols <- all_cols[seq_len(partid_idx)]
    }

    # Determine available bin columns
    has_cold_bin <- "LDS Cold Bin" %in% all_cols
    has_hot_bin <- "LDS Hot Bin" %in% all_cols

    # Validating Columns
    required_cols <- c("ROOTID")
    if (has_cold_bin) required_cols <- c(required_cols, "LDS Cold Bin")
    if (has_hot_bin) required_cols <- c(required_cols, "LDS Hot Bin")

    missing_cols <- setdiff(required_cols, all_cols)
    if (length(missing_cols) > 0) stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))

    cols_to_keep <- unique(c(required_cols, meta_cols, msr_cols))

    log_msg(paste0("Step 2: Reading data... (Target: ", length(cols_to_keep), " cols)"))
    log_msg(paste0("MSR Columns detected: ", length(msr_cols), " (source: ", msr_resolution$source, ")"))
    if (length(msr_resolution$missing_configured) > 0L) {
        log_msg(paste0(
            "[Warning] ", length(msr_resolution$missing_configured),
            " configured MSR(s) were not found in Raw: ",
            paste(utils::head(msr_resolution$missing_configured, 10L), collapse = ", "),
            if (length(msr_resolution$missing_configured) > 10L) " ..." else ""
        ))
    }

    # Read with filter on columns
    dt <- data.table::fread(
        raw_path,
        select = cols_to_keep,
        nThread = 4
    )

    # Filtering
    fallback_count_by_root <- data.table::data.table(ROOTID = character(), fallback_cnt = integer())
    auto_good_count_by_root <- data.table::data.table(ROOTID = character(), auto_good_cnt = integer())

    has_hot_criterion <- has_hot_bin && (is.function(good_chip_rule_hot) || !is.null(good_chip_limit_hot))
    has_cold_criterion <- has_cold_bin && (is.function(good_chip_rule_cold) || !is.null(good_chip_limit_cold))

    if (has_hot_criterion || has_cold_criterion) {
        initial_rows <- nrow(dt)
        log_msg(
            "Step 3: Filtering rows (priority: Cold rule -> Hot fallback when Cold is NA -> if both are NA, auto-good)..."
        )

        hot_vals <- rep(NA_real_, nrow(dt))
        cold_vals <- rep(NA_real_, nrow(dt))
        hot_is_present <- rep(FALSE, nrow(dt))
        cold_is_present <- rep(FALSE, nrow(dt))
        hot_good <- rep(FALSE, nrow(dt))
        cold_good <- rep(FALSE, nrow(dt))

        if (has_hot_bin) {
            hot_vals <- dt[["LDS Hot Bin"]]
            hot_is_present <- !is.na(hot_vals)
        }

        if (has_cold_bin) {
            cold_vals <- dt[["LDS Cold Bin"]]
            cold_is_present <- !is.na(cold_vals)
        }

        if (has_hot_criterion) {
            if (is.function(good_chip_rule_hot)) {
                hot_good <- as.logical(good_chip_rule_hot(hot_vals))
            } else {
                hot_good <- hot_is_present & (hot_vals < good_chip_limit_hot)
            }
        }

        if (has_cold_criterion) {
            if (is.function(good_chip_rule_cold)) {
                cold_good <- as.logical(good_chip_rule_cold(cold_vals))
            } else {
                cold_good <- cold_is_present & (
                    (cold_vals < good_chip_limit_cold) |
                    (cold_vals >= 790 & cold_vals < 800)
                )
            }
        }

        hot_good[is.na(hot_good)] <- FALSE
        cold_good[is.na(cold_good)] <- FALSE

        keep_idx <- if (has_cold_bin && has_hot_bin) {
            ifelse(cold_is_present, cold_good, ifelse(hot_is_present, hot_good, TRUE))
        } else if (has_cold_bin) {
            ifelse(cold_is_present, cold_good, TRUE)
        } else {
            ifelse(hot_is_present, hot_good, TRUE)
        }

        cold_path_idx <- rep(FALSE, nrow(dt))
        hot_path_idx <- rep(FALSE, nrow(dt))
        auto_good_idx <- rep(FALSE, nrow(dt))

        if (has_cold_bin && has_hot_bin) {
            cold_path_idx <- cold_is_present
            hot_path_idx <- !cold_is_present & hot_is_present
            auto_good_idx <- !cold_is_present & !hot_is_present
        } else if (has_cold_bin) {
            cold_path_idx <- cold_is_present
            auto_good_idx <- !cold_is_present
        } else if (has_hot_bin) {
            hot_path_idx <- hot_is_present
            auto_good_idx <- !hot_is_present
        }

        log_msg(
            paste0(
                "[GoodChip N] use lds cold bin=", format(sum(cold_path_idx), big.mark = ","),
                " | use lds hot bin=", format(sum(hot_path_idx), big.mark = ","),
                " | both na -> good=", format(sum(auto_good_idx), big.mark = ",")
            )
        )

        # Count rows evaluated by fallback path (Cold missing -> Hot used), by ROOTID
        if (has_cold_bin && has_hot_bin) {
            fallback_idx <- hot_path_idx
            fallback_count_by_root <- dt[fallback_idx, .(fallback_cnt = .N), by = ROOTID][order(-fallback_cnt)]
            auto_good_count_by_root <- dt[auto_good_idx, .(auto_good_cnt = .N), by = ROOTID][order(-auto_good_cnt)]
        }

        dt <- dt[keep_idx]
        final_rows <- nrow(dt)
        log_msg(paste0("[Filter Result] ", format(initial_rows, big.mark = ","), " -> ", format(final_rows, big.mark = ","), " rows (", round((1 - final_rows / initial_rows) * 100, 1), "% reduced)"))

        # Release full-row temporary vectors before the map join to reduce peak memory.
        rm(
            hot_vals, cold_vals, hot_is_present, cold_is_present,
            hot_good, cold_good, keep_idx, cold_path_idx, hot_path_idx,
            auto_good_idx
        )
        if (exists("fallback_idx", inherits = FALSE)) {
            rm(fallback_idx)
        }

        # Keep bin columns because they are part of metadata context for raw_access.
    } else {
        msg <- "Step 3: Filtering skipped"
        if (!(has_cold_bin || has_hot_bin)) {
            msg <- paste0(msg, " (No 'LDS Cold/Hot Bin' column found; all rows treated as good chip).")
            auto_good_count_by_root <- dt[, .(auto_good_cnt = .N), by = ROOTID][order(-auto_good_cnt)]
        } else if (!has_hot_criterion && !has_cold_criterion) {
            msg <- paste0(msg, " (No valid Hot/Cold filter rule or legacy limit provided; all rows treated as good chip).")
            auto_good_count_by_root <- dt[, .(auto_good_cnt = .N), by = ROOTID][order(-auto_good_cnt)]
        }
        log_msg(msg)
    }

    # Garbage collect
    gc()

    # Load ROOTID map
    if (!file.exists(root_path)) {
        stop("ROOTID file not found: ", root_path)
    }

    map_dt <- validate_rootid_map(
        data.table::fread(root_path, showProgress = FALSE),
        path_label = basename(root_path)
    )
    dt[, ROOTID := trimws(as.character(ROOTID))]
    data.table::setkey(map_dt, ROOTID)
    data.table::setkey(dt, ROOTID)

    # Merge with Map
    log_msg(paste0("Step 4: Merging with ROOTID map..."))
    
    pre_merge_wfs <- data.table::uniqueN(dt$ROOTID)

    # Inner Join to keep only matching ROOTIDs (Filters out ROOTIDs not in map)
    dt <- map_dt[dt, nomatch = 0]
    
    post_merge_wfs <- data.table::uniqueN(dt$ROOTID)
    if (post_merge_wfs == 0L) {
        stop("No matching ROOTID values were found between raw data and ", basename(root_path), ".")
    }

    wf_counts <- unique(dt[, .(ROOTID, GROUP)])[
        ,
        .(N = data.table::uniqueN(ROOTID)),
        by = GROUP
    ]
    data.table::setorder(wf_counts, GROUP)
    dropped_wfs <- pre_merge_wfs - post_merge_wfs
    
    # Missing: In Map but NOT in Raw
    map_wfs <- data.table::uniqueN(map_dt$ROOTID)
    missing_wfs <- map_wfs - post_merge_wfs 
    
    # Calculate Union for intuitive logging (Union - Excluded_A - Excluded_B = Intersection)
    total_wfs <- pre_merge_wfs + missing_wfs
    
    log_msg(paste0("[Merge Info] WFs (Union): ", format(total_wfs, big.mark = ","), " -> ", format(post_merge_wfs, big.mark = ",")))
    
    # Consolidate Exclusions
    excl_msg <- c()
    if (dropped_wfs > 0) excl_msg <- c(excl_msg, paste0(format(dropped_wfs, big.mark = ","), " (not in ROOTID.csv)"))
    if (missing_wfs > 0) excl_msg <- c(excl_msg, paste0(format(missing_wfs, big.mark = ","), " (not in raw data)"))
    
    if (length(excl_msg) > 0) {
        log_msg(paste0("[Merge Info] Excluded: ", paste(excl_msg, collapse = ", ")))
    } else {
        log_msg("[Merge Info] No outlier/missing WFs.")
    }

    # [Type Enforcement]
    # Ensure all MSR columns are numeric (double) to prevent melt warnings
    # Mixed types (integer vs double) cause warnings in 02_calc_stats.R
    log_msg("Step 5: Enforcing numeric types for MSR columns...")
    
    # Identify MSR cols present in the final dt
    existing_msr_cols <- intersect(msr_cols, names(dt))
    
    # Convert integer/numeric-text MSRs to double and fail on non-numeric values.
    for (col in existing_msr_cols) {
        data.table::set(dt, j = col, value = coerce_msr_numeric(dt[[col]], col))
    }
    
    log_msg(paste0("Process complete. Final dataset: ", nrow(dt), " rows."))

    return(list(data = dt, msr_cols = msr_cols, wf_counts = wf_counts, fallback_count_by_root = fallback_count_by_root, auto_good_count_by_root = auto_good_count_by_root))
}

# Stage wrapper:
# - resolves input file paths
# - applies good-chip filter settings from runtime config
# - prints fallback/auto-good summaries and returns prepared data payload
run_stage_load_data <- function(raw_filename, root_filename, general_config) {
    RAW_FILE <- here::here("data", raw_filename)
    ROOT_FILE <- here::here("data", root_filename)

    load_res <- load_and_filter_data(
        RAW_FILE,
        ROOT_FILE,
        good_chip_limit_hot = general_config$GOOD_CHIP_LIMIT_HOT,
        good_chip_limit_cold = general_config$GOOD_CHIP_LIMIT_COLD,
        good_chip_rule_hot = general_config$GOOD_CHIP_RULE_HOT,
        good_chip_rule_cold = general_config$GOOD_CHIP_RULE_COLD,
        msrinfo_path = here::here("data", "msrinfo.csv")
    )

    if (nrow(load_res$fallback_count_by_root) > 0) {
        log_msg("[GoodChip] Cold NA -> Hot fallback rows by ROOTID (top 10):")
        print(utils::head(load_res$fallback_count_by_root, 10))
    }

    if (nrow(load_res$auto_good_count_by_root) > 0) {
        log_msg("[GoodChip] Auto-good rows by ROOTID (no evaluable Cold/Hot bin value or no filter criteria; top 10):")
        print(utils::head(load_res$auto_good_count_by_root, 10))
    }

    log_msg("Data Loaded Successfully.")
    gc()

    load_res
}
