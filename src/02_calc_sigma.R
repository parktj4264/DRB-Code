#' @title Calculate Sigma Score in Parallel
#' @description Computes Sigma Score (Glass's Delta) between Reference and Target groups using parallel processing.
#' @param dt data.table. The data containing MSR columns and Group info.
#' @param msr_cols Character vector. Names of the MSR columns.
#' @param n_cores Integer. Number of cores to use.
#' @param chunk_size Integer. Number of columns to process per chunk.
#' @param threshold Numeric. Cutoff for Up/Down direction.
#' @return data.table. The results table.

calculate_sigma_parallel <- function(dt, msr_cols, n_cores, chunk_size = 100, threshold = 0.5,
                                     ref_name = NULL, target_name = NULL) {
  require(data.table)
  require(future)
  require(future.apply)
  require(progressr)

  # Prevent "future.globals.maxSize" error by increasing limit to 2GB (default is 500MB)
  # We are optimizing to NOT send the whole data, but this is a safety net.
  options(future.globals.maxSize = 2000 * 1024^2)

  log_msg(paste0("Starting parallel calculation with ", n_cores, " cores."))

  # Setup parallel plan
  plan(multisession, workers = n_cores)

  # Chunking MSR columns
  chunks <- split(msr_cols, ceiling(seq_along(msr_cols) / chunk_size))
  log_msg(paste0("Splitting ", length(msr_cols), " columns into ", length(chunks), " chunks."))

  group_col <- "GROUP"
  # Standardize Group Column if possible or verify
  if (!group_col %in% names(dt)) {
    candidates <- names(dt)[!names(dt) %in% c("ROOTID", msr_cols)]
    if (length(candidates) == 1) {
      group_col <- candidates[1]
      log_msg(paste0("Auto-detected group column: ", group_col))
    } else {
      stop("Cannot identify GROUP column. ROOTID.csv must have a 'GROUP' column.")
    }
  }

  log_msg("Processing chunks...")

  # Execute parallel map in BATCHES
  results_list <- list()

  # Process in batches of 'n_cores' size
  batch_size <- n_cores
  batch_indices <- split(seq_along(chunks), ceiling(seq_along(chunks) / batch_size))
  total_batches <- length(batch_indices)

  # Initialize Progress Bar (Standard R Text Bar)
  pb <- utils::txtProgressBar(min = 0, max = total_batches, style = 3)

  for (i in seq_along(batch_indices)) {
    batch_idx <- batch_indices[[i]]

    # Prepare data subsets for this batch ONLY
    batch_task_data <- lapply(batch_idx, function(k) {
      cols <- chunks[[k]]
      # Create a lightweight subset
      sub_dt <- dt[, c(group_col, cols), with = FALSE]
      list(sub_dt = sub_dt, cols = cols)
    })

    # Run this batch in parallel
    batch_results <- future_lapply(batch_task_data, function(task) {
      # Unpack inside the worker
      d <- task$sub_dt
      c <- task$cols

      # Melt
      dt_long <- data.table::melt(d,
        id.vars = group_col, measure.vars = c,
        variable.name = "MSR", value.name = "Value"
      )

      # Calculate stats
      stats <- dt_long[, .(
        Mean = mean(Value, na.rm = TRUE),
        SD = sd(Value, na.rm = TRUE)
      ), by = c("MSR", group_col)]

      return(stats)
    }, future.seed = TRUE)

    # Aggregate results
    results_list <- c(results_list, batch_results)

    # Helper: clean up memory explicitly for this batch
    rm(batch_task_data, batch_results)
    gc()

    # Update Progress Bar
    utils::setTxtProgressBar(pb, i)
  }
  close(pb)

  log_msg("Aggregation and pivoting...")
  all_stats <- rbindlist(results_list)

  # Identify Groups and Validate User Input
  available_groups <- unique(all_stats[[group_col]])

  # Logic: Determine Ref and Target
  final_ref <- NULL
  final_tgt <- NULL

  # 1. Check User Input validity
  if (!is.null(ref_name) && ref_name %in% available_groups) {
    final_ref <- ref_name
  } else if (!is.null(ref_name)) {
    log_msg(paste0("[Warning] User defined Ref '", ref_name, "' not found in data. Falling back to auto-detect."))
  }

  if (!is.null(target_name) && target_name %in% available_groups) {
    final_tgt <- target_name
  } else if (!is.null(target_name)) {
    log_msg(paste0("[Warning] User defined Target '", target_name, "' not found in data. Falling back to auto-detect."))
  }

  # 2. Auto-detect if missing
  sorted_groups <- sort(available_groups)

  if (is.null(final_ref)) {
    if (length(sorted_groups) > 0) final_ref <- sorted_groups[1]
  }

  if (is.null(final_tgt)) {
    # If explicit Ref is set, pick the other one
    remaining <- setdiff(sorted_groups, final_ref)
    if (length(remaining) > 0) final_tgt <- remaining[1]
  }

  # 3. Final Validation
  if (is.null(final_ref) || is.null(final_tgt)) {
    stop("Could not determine Reference and Target groups. Available groups: ", paste(available_groups, collapse = ", "))
  }

  if (final_ref == final_tgt) {
    warning("Reference and Target groups are identical: ", final_ref, ". Sigma scores will be 0.")
  }

  log_msg(paste0("Reference Group: [", final_ref, "]"))
  log_msg(paste0("Target Group:    [", final_tgt, "]"))

  # Cast (Wide Format)
  # This automatically creates Mean_<Group> and SD_<Group> columns
  final_dt <- dcast(all_stats, MSR ~ get(group_col), value.var = c("Mean", "SD"))

  # User Request: "Current cols: Mean_A, Mean_B ... is better".
  # So we do NOT rename columns to generic 'mean_ref' etc.

  # Calculate Sigma Score strictly using identified groups
  col_mean_ref <- paste0("Mean_", final_ref)
  col_mean_tgt <- paste0("Mean_", final_tgt)
  col_sd_ref <- paste0("SD_", final_ref)

  # Verify columns exist (just in case)
  if (!all(c(col_mean_ref, col_mean_tgt, col_sd_ref) %in% names(final_dt))) {
    stop("Error in column generation. Expected columns: ", paste(c(col_mean_ref, col_mean_tgt, col_sd_ref), collapse = ", "))
  }

  log_msg("Calculating Sigma Score...")

  # Formula: (Mean_Target - Mean_Ref) / SD_Ref
  final_dt[, Sigma_Score := (get(col_mean_tgt) - get(col_mean_ref)) / get(col_sd_ref)]

  # Handle Division by Zero or NA
  final_dt[get(col_sd_ref) <= 0 | is.na(get(col_sd_ref)), Sigma_Score := 0] # Safety

  # Assign Direction
  final_dt[, Direction := "Stable"]
  final_dt[Sigma_Score > threshold, Direction := "Up"]
  final_dt[Sigma_Score < -threshold, Direction := "Down"]

  return(list(res = final_dt, ref = final_ref, tgt = final_tgt))
}
