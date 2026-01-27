#' @title Load and Filter Data
#' @description Reads raw data, filters by Hot Bin, and merges with Group info.
#' @param raw_path STRING. Path to the large raw CSV.
#' @param root_path STRING. Path to the ROOTID mapping CSV.
#' @param hot_bin_limit NUMERIC. cutoff for 'LDS Hot Bin'.
#' @return A list containing the filtered data.table and a vector of MSR column names.

load_and_filter_data <- function(raw_path, root_path, hot_bin_limit) {
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

    # Validating Columns
    required_cols <- c("ROOTID", "LDS Hot Bin")
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
    before_n <- nrow(dt)
    log_msg(paste0("Step 3: Filtering rows (LDS Hot Bin < ", hot_bin_limit, ")..."))

    # Use exact logic from snippet: keep rows LESS THAN limit
    dt <- dt[get("LDS Hot Bin") < hot_bin_limit]

    after_n <- nrow(dt)
    reduction <- round((before_n - after_n) / before_n * 100, 1)

    log_msg(sprintf(
        "[Filter Result] %s -> %s rows (%s%% reduced)",
        format(before_n, big.mark = ","),
        format(after_n, big.mark = ","),
        reduction
    ))

    # Remove filter column to save memory
    data.table::set(dt, j = "LDS Hot Bin", value = NULL)

    # Garbage collect
    gc()

    log_msg("Step 4: Merging with ROOTID map...")
    # Load ROOTID map
    if (!file.exists(root_path)) {
        stop("ROOTID file not found: ", root_path)
    }

    root_dt <- data.table::fread(root_path)
    data.table::setkey(root_dt, ROOTID)
    data.table::setkey(dt, ROOTID)

    # Merge (Inner Join)
    dt <- root_dt[dt, nomatch = 0]

    log_msg(paste0("Merge complete. Final dataset: ", nrow(dt), " rows."))

    return(list(data = dt, msr_cols = msr_cols))
}
