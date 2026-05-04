#' @title Load and Filter Data
#' @description Reads raw data, filters by Hot/Cold Bin rules, and merges with Group info.
#' @param raw_path STRING. Path to the large raw CSV.
#' @param root_path STRING. Path to the ROOTID mapping CSV.
#' @param good_chip_limit_hot NUMERIC/NULL. Legacy cutoff for 'LDS Hot Bin' (used only when rule is NULL).
#' @param good_chip_limit_cold NUMERIC/NULL. Legacy cutoff for 'LDS Cold Bin' (used only when rule is NULL).
#' @param good_chip_rule_hot FUNCTION/NULL. Rule function for Hot bin; input numeric vector, output logical vector.
#' @param good_chip_rule_cold FUNCTION/NULL. Rule function for Cold bin; input numeric vector, output logical vector.
#' @return A list containing the filtered data.table and a vector of MSR column names.

load_and_filter_data <- function(raw_path, root_path, good_chip_limit_hot = NULL, good_chip_limit_cold = NULL, good_chip_rule_hot = NULL, good_chip_rule_cold = NULL) {
    # 1. Read Raw Data
    log_msg("Step 1: Inspecting file headers...")

    # Read header only to identify columns
    start_read <- Sys.time()
    header_only <- data.table::fread(raw_path, nrows = 0)
    all_cols <- names(header_only)

    # Identify MSR columns dynamically based on 'PARTID'
    partid_idx <- which(all_cols == "PARTID")

    if (length(partid_idx) == 0) {
        # Fallback if PARTID not found (though user implies it exists)
        warning("'PARTID' column not found. Falling back to all non-key columns.")
        key_cols <- c("ROOTID", "LDS Hot Bin")
        msr_cols <- setdiff(all_cols, key_cols)
    } else {
        # Select all columns AFTER 'PARTID'
        if (partid_idx == length(all_cols)) {
            stop("'PARTID' is the last column. No MSR columns found.")
        }
        msr_cols <- all_cols[(partid_idx + 1):length(all_cols)]
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

    cols_to_keep <- c(required_cols, msr_cols)

    log_msg(paste0("Step 2: Reading data... (Target: ", length(cols_to_keep), " cols)"))
    log_msg(paste0("MSR Columns detected: ", length(msr_cols), " (starts after PARTID)"))

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

        # Count rows evaluated by fallback path (Cold missing -> Hot used), by ROOTID
        if (has_cold_bin && has_hot_bin) {
            fallback_idx <- !cold_is_present & hot_is_present
            fallback_count_by_root <- dt[fallback_idx, .(fallback_cnt = .N), by = ROOTID][order(-fallback_cnt)]
            auto_good_idx <- !cold_is_present & !hot_is_present
            auto_good_count_by_root <- dt[auto_good_idx, .(auto_good_cnt = .N), by = ROOTID][order(-auto_good_cnt)]
        }

        dt <- dt[keep_idx]
        final_rows <- nrow(dt)
        log_msg(paste0("[Filter Result] ", format(initial_rows, big.mark = ","), " -> ", format(final_rows, big.mark = ","), " rows (", round((1 - final_rows / initial_rows) * 100, 1), "% reduced)"))

        # Remove filter columns to save memory
        drop_cols <- intersect(c("LDS Cold Bin", "LDS Hot Bin"), names(dt))
        if (length(drop_cols) > 0) dt[, (drop_cols) := NULL]
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

    map_dt <- data.table::fread(root_path) # Merge with Map
    # map_dt has columns: "ROOTID", "GROUP"
    data.table::setkey(map_dt, ROOTID)
    data.table::setkey(dt, ROOTID)

    # Calculate WF Counts per Group (from the Map)
    wf_counts <- map_dt[, .N, by = "GROUP"]

    # Merge with Map
    log_msg(paste0("Step 4: Merging with ROOTID map..."))
    
    pre_merge_wfs <- data.table::uniqueN(dt$ROOTID)

    # Inner Join to keep only matching ROOTIDs (Filters out ROOTIDs not in map)
    dt <- map_dt[dt, nomatch = 0]
    
    post_merge_wfs <- data.table::uniqueN(dt$ROOTID)
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
    
    # Loop and set to numeric if integer (efficient in-place modification)
    for (col in existing_msr_cols) {
        if (is.integer(dt[[col]])) {
            set(dt, j = col, value = as.numeric(dt[[col]]))
        }
    }
    
    log_msg(paste0("Process complete. Final dataset: ", nrow(dt), " rows."))

    return(list(data = dt, msr_cols = msr_cols, wf_counts = wf_counts, fallback_count_by_root = fallback_count_by_root, auto_good_count_by_root = auto_good_count_by_root))
}
