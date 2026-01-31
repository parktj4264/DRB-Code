#' @title Load and Filter Data
#' @description Reads raw data, filters by Hot Bin, and merges with Group info.
#' @param raw_path STRING. Path to the large raw CSV.
#' @param root_path STRING. Path to the ROOTID mapping CSV.
#' @param hot_bin_limit NUMERIC. cutoff for 'LDS Hot Bin'.
#' @return A list containing the filtered data.table and a vector of MSR column names.

load_and_filter_data <- function(raw_path, root_path, good_chip_limit = 130) {
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

    # Determine Filter Column (Priority: Cold Bin > Hot Bin)
    filter_col <- NULL

    if ("LDS Cold Bin" %in% all_cols) {
        filter_col <- "LDS Cold Bin"
    } else if ("LDS Hot Bin" %in% all_cols) {
        filter_col <- "LDS Hot Bin"
    }

    # Validating Columns
    required_cols <- c("ROOTID")

    if (!is.null(filter_col)) {
        required_cols <- c(required_cols, filter_col)
    }

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
    if (!is.null(filter_col) && !is.null(good_chip_limit)) { # Changed hot_bin_limit to good_chip_limit
        if ("LDS Cold Bin" %in% names(dt)) {
            log_msg(paste0("Step 3: Filtering rows (LDS Cold Bin < ", good_chip_limit, ")..."))
            initial_rows <- nrow(dt)
            dt <- dt[`LDS Cold Bin` < good_chip_limit]
            final_rows <- nrow(dt)
            log_msg(paste0("[Filter Result] ", format(initial_rows, big.mark = ","), " -> ", format(final_rows, big.mark = ","), " rows (", round((1 - final_rows / initial_rows) * 100, 1), "% reduced)"))
        } else if ("LDS Hot Bin" %in% names(dt)) {
            log_msg(paste0("Step 3: Filtering rows (LDS Hot Bin < ", good_chip_limit, ")..."))
            initial_rows <- nrow(dt)
            dt <- dt[`LDS Hot Bin` < good_chip_limit]
            final_rows <- nrow(dt)
            log_msg(paste0("[Filter Result] ", format(initial_rows, big.mark = ","), " -> ", format(final_rows, big.mark = ","), " rows (", round((1 - final_rows / initial_rows) * 100, 1), "% reduced)"))
        }
        # Remove filter column to save memory
        dt[, (filter_col) := NULL]
    } else {
        msg <- "Step 3: Filtering skipped"
        if (is.null(filter_col)) {
            msg <- paste0(msg, " (No 'LDS Cold/Hot Bin' column found).")
        } else if (is.null(good_chip_limit)) msg <- paste0(msg, " (No limit provided).") # Changed hot_bin_limit to good_chip_limit
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

    # Inner Join to keep only matching ROOTIDs
    dt <- map_dt[dt, nomatch = 0]

    log_msg(paste0("Step 4: Merging with ROOTID map..."))
    log_msg(paste0("Merge complete. Final dataset: ", nrow(dt), " rows."))

    return(list(data = dt, msr_cols = msr_cols, wf_counts = wf_counts))
}
