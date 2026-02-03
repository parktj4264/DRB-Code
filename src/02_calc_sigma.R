#' @title Calculate Sigma Score
#' @description Computes Sigma Score (Glass's Delta) between Reference and Target groups using standard single-core processing.
#' @param dt data.table. The data containing MSR columns and Group info.
#' @param msr_cols Character vector. Names of the MSR columns.
#' @param threshold Numeric. Cutoff for Up/Down direction.
#' @param ref_name Character. Optional user-specified Reference group name.
#' @param target_name Character. Optional user-specified Target group name.
#' @return data.table. The results table.

calculate_sigma <- function(dt, msr_cols, threshold = 0.5,
                            ref_name = NULL, target_name = NULL) {
  require(data.table)

  log_msg("Starting Sigma Score calculation (Single Core).")

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

  log_msg("Calculating statistics...")

  # ------------------------------------------------------------------
  # [Progress Bar Implementation]
  # Processing all columns at once can be slow and silent.
  # We split MSR columns into batches to show a progress bar.
  # ------------------------------------------------------------------

  # Define batch size (adjust if needed, 500 is a reasonable balance)
  batch_size <- 500
  chunks <- split(msr_cols, ceiling(seq_along(msr_cols) / batch_size))
  total_chunks <- length(chunks)
  
  results_list <- list()
  
  # Setup Progress Bar
  pb <- utils::txtProgressBar(min = 0, max = total_chunks, style = 3)
  
  for (i in seq_along(chunks)) {
    chunk_cols <- chunks[[i]]
    
    # 1. Subset & Melt (Batch)
    sub_dt <- dt[, c(group_col, chunk_cols), with = FALSE]
    
    dt_long <- data.table::melt(sub_dt,
       id.vars = group_col, measure.vars = chunk_cols,
       variable.name = "MSR", value.name = "Value"
    )
    
    # 2. Aggregate (Batch)
    batch_stats <- dt_long[, .(
      Mean = mean(Value, na.rm = TRUE),
      SD = sd(Value, na.rm = TRUE)
    ), by = c("MSR", group_col)]
    
    results_list[[i]] <- batch_stats
    
    # Update Progress Bar
    utils::setTxtProgressBar(pb, i)
    
    # Optional: Garbage Collection for very large data
    rm(sub_dt, dt_long, batch_stats)
    # gc() # Only uncomment if strictly necessary (slows down loop)
  }
  close(pb) # Close the progress bar
  
  # Combine all batches
  all_stats <- data.table::rbindlist(results_list)

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

  # Calculate N for Ref and Target
  n_ref <- uniqueN(all_stats[get(group_col) == final_ref, .(MSR)]) # Caution: all_stats is aggregated by MSR/Group. We need raw WF counts? 
  # Wait, all_stats is ALREADY aggregated (Mean/SD). We don't have raw rows here.
  # We cannot count WFs from `all_stats`. We need to verify where to get N.
  # `calculate_sigma` takes `dt` as input. `dt` has raw data.
  
  n_ref <- uniqueN(dt[get(group_col) == final_ref, ROOTID])
  n_tgt <- uniqueN(dt[get(group_col) == final_tgt, ROOTID])

  log_msg(paste0("Reference Group: [", final_ref, "] (N=", format(n_ref, big.mark = ","), ")"))
  log_msg(paste0("Target Group:    [", final_tgt, "] (N=", format(n_tgt, big.mark = ","), ")"))

  # Cast (Wide Format)
  # This automatically creates Mean_<Group> and SD_<Group> columns
  final_dt <- dcast(all_stats, MSR ~ get(group_col), value.var = c("Mean", "SD"))

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
  
  # Abs Sigma Score & Sorting
  final_dt[, Abs_Sigma_Score := abs(Sigma_Score)]
  final_dt <- final_dt[order(-Abs_Sigma_Score)]

  # Assign Direction
  final_dt[, Direction := "Stable"]
  final_dt[Sigma_Score > threshold, Direction := "Up"]
  final_dt[Sigma_Score < -threshold, Direction := "Down"]

  return(list(res = final_dt, ref = final_ref, tgt = final_tgt))
}
