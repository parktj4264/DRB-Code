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
  # ------------------------------------------------------------------

  # Define batch size
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
    
    # Optional: Garbage Collection
    rm(sub_dt, dt_long, batch_stats)
  }
  close(pb) # Close the progress bar
  
  # Combine all batches
  all_stats <- data.table::rbindlist(results_list)

  # Identify Groups and Validate User Input
  available_groups <- unique(all_stats[[group_col]])

  # Logic: Determine Ref and Target
  final_ref <- NULL
  final_tgt <- NULL

  # 1. Check User Input validity (Supports Vectors)
  if (!is.null(ref_name)) {
    # Intersect with available groups
    valid_refs <- intersect(ref_name, available_groups)
    if (length(valid_refs) > 0) {
      final_ref <- valid_refs
      # Warn if some were dropped
      if (length(valid_refs) < length(ref_name)) {
        dropped <- setdiff(ref_name, valid_refs)
        log_msg(paste0("[Warning] Groups not found and ignored: ", paste(dropped, collapse=", ")))
      }
    } else {
      log_msg("[Warning] None of the defined Ref groups found. Falling back to auto-detect.")
    }
  }

  if (!is.null(target_name)) {
    # Intersect with available groups
    valid_tgts <- intersect(target_name, available_groups)
    if (length(valid_tgts) > 0) {
      final_tgt <- valid_tgts
       if (length(valid_tgts) < length(target_name)) {
        dropped <- setdiff(target_name, valid_tgts)
        log_msg(paste0("[Warning] Groups not found and ignored: ", paste(dropped, collapse=", ")))
      }
    } else {
      log_msg("[Warning] None of the defined Target groups found. Falling back to auto-detect.")
    }
  }

  # 2. Auto-detect if missing (Logic primarily for single vs single default)
  sorted_groups <- sort(available_groups)

  if (is.null(final_ref)) {
    if (length(sorted_groups) > 0) final_ref <- sorted_groups[1]
  }

  if (is.null(final_tgt)) {
    # If explicit Ref is set, pick the other one(s) NOT in Ref
    # Default behavior: pick the first available non-ref
    remaining <- setdiff(sorted_groups, final_ref)
    if (length(remaining) > 0) {
        # If user didn't specify target, we usually pick ONE for simple default 1v1
        # But if user specified vector Ref, what should default Target be?
        # Maintaining original logic: pick 1st remaining.
        final_tgt <- remaining[1]
    }
  }

  # 3. Final Validation
  if (is.null(final_ref) || is.null(final_tgt)) {
    stop("Could not determine Reference and Target groups. Available groups: ", paste(available_groups, collapse = ", "))
  }

  # Calculate N for Ref and Target (Loop for multiple)
  for (r in final_ref) {
    n_r <- uniqueN(dt[get(group_col) == r, ROOTID])
    log_msg(paste0("Reference Group: [", r, "] (N=", format(n_r, big.mark = ","), ")"))
  }
  for (t in final_tgt) {
    n_t <- uniqueN(dt[get(group_col) == t, ROOTID])
    log_msg(paste0("Target Group:    [", t, "] (N=", format(n_t, big.mark = ","), ")"))
  }

  # Cast (Wide Format)
  # This automatically creates Mean_<Group> and SD_<Group> columns for ALL groups found
  final_dt <- dcast(all_stats, MSR ~ get(group_col), value.var = c("Mean", "SD"))

  log_msg("Calculating Sigma Score...")

  # ==============================================================================
  # BRANCHING LOGIC: Single vs Multi
  # ==============================================================================
  
  if (length(final_ref) == 1 && length(final_tgt) == 1) {
      # -------------------------------------------------------
      # CASE A: Single Ref, Single Target (Original Logic)
      # -------------------------------------------------------
      col_mean_ref <- paste0("Mean_", final_ref)
      col_mean_tgt <- paste0("Mean_", final_tgt)
      col_sd_ref   <- paste0("SD_", final_ref)

      if (!all(c(col_mean_ref, col_mean_tgt, col_sd_ref) %in% names(final_dt))) {
        stop("Error in column generation. Expected columns missing.")
      }

      # Formula: (Mean_Target - Mean_Ref) / SD_Ref
      final_dt[, Sigma_Score := (get(col_mean_tgt) - get(col_mean_ref)) / get(col_sd_ref)]
      
      # Handle Division by Zero or NA
      final_dt[get(col_sd_ref) <= 0 | is.na(get(col_sd_ref)), Sigma_Score := 0]

      final_dt[, Abs_Sigma_Score := abs(Sigma_Score)]

  } else {
      # -------------------------------------------------------
      # CASE B: Multi-Group (Combinatoric)
      # -------------------------------------------------------
      log_msg(paste0("Multi-group mode detected. Ref=", length(final_ref), ", Target=", length(final_tgt)))
      
      temp_score_cols <- c()
      temp_abs_cols   <- c()

      for (r in final_ref) {
          for (t in final_tgt) {
              if (r == t) next # Skip self-comparison

              col_mean_ref <- paste0("Mean_", r)
              col_mean_tgt <- paste0("Mean_", t)
              col_sd_ref   <- paste0("SD_", r)
              
              # Column names for specific pair
              # Naming convention: Sigma_Score_{ref}_{target}
              col_sigma     <- paste0("Sigma_Score_", r, "_", t)
              col_abs_sigma <- paste0("Abs_Sigma_Score_", r, "_", t)
              
              if (!all(c(col_mean_ref, col_mean_tgt, col_sd_ref) %in% names(final_dt))) {
                  log_msg(paste0("[Skip] Missing columns for pair ", r, " vs ", t))
                  next
              }

              # Calculate Pairwise Sigma Score
              final_dt[, (col_sigma) := (get(col_mean_tgt) - get(col_mean_ref)) / get(col_sd_ref)]
              
              # Safety: Div by 0
              final_dt[get(col_sd_ref) <= 0 | is.na(get(col_sd_ref)), (col_sigma) := 0]
              
              # Calculate Pairwise Abs
              final_dt[, (col_abs_sigma) := abs(get(col_sigma))]
              
              temp_score_cols <- c(temp_score_cols, col_sigma)
              temp_abs_cols   <- c(temp_abs_cols, col_abs_sigma)
          }
      }

      if (length(temp_score_cols) == 0) {
          stop("No valid group combinations found for Sigma Score calculation.")
      }

      # Find Max Absolute Sigma Score across all pairs for each row
      # logic: find which column index has the max value in temp_abs_cols rows
      # We want to assign the VALUE of the max abs score to 'Abs_Sigma_Score'
      # And the corresponding signed score to 'Sigma_Score'

      # Use pmax for vectorized row-wise max if simpler, but we need the signed value too.
      # A simple way:
      # 1. Calculate max abs value
      final_dt[, Abs_Sigma_Score := do.call(pmax, c(.SD, list(na.rm=TRUE))), .SDcols = temp_abs_cols]
      
      # 2. To get the signed 'Sigma_Score' corresponding to that Max Abs:
      # We iterate again (or find a smarter vector way). Since n_groups is small usually, a loop over rows is slow, 
      # but a loop over columns is fast.
      # Strategy: Initialize Sigma_Score with first pair. Update where next pair's abs is larger.
      
      final_dt[, Sigma_Score := 0] # Init
      final_dt[, Max_Abs_Track := -1] # Helper to track max
      
      for (i in seq_along(temp_score_cols)) {
          s_col <- temp_score_cols[i]
          a_col <- temp_abs_cols[i]
          
          # If this column's Abs is the Max Abs, take its signed value.
          # Note: if multiple pairs have exact same max abs, the last one visited wins (or first, depending on logic). 
          # Let's say we update if Abs > current_max_track.
          
          # Logic: Update Sigma_Score where this pair's Abs == final_dt$Abs_Sigma_Score
          # (Since we already computed global Max Abs)
          
          final_dt[get(a_col) == Abs_Sigma_Score, Sigma_Score := get(s_col)]
      }
      
      final_dt[, Max_Abs_Track := NULL] # Cleanup
  }
  
  # -------------------------------------------------------
  # Common Final Steps
  # -------------------------------------------------------

  # Sorting by Abs_Sigma_Score (Descending)
  final_dt <- final_dt[order(-Abs_Sigma_Score)]

  # Assign Direction globally based on the MAIN Sigma_Score
  final_dt[, Direction := "Stable"]
  final_dt[Sigma_Score > threshold, Direction := "Up"]
  final_dt[Sigma_Score < -threshold, Direction := "Down"]

  return(list(res = final_dt, ref = final_ref, tgt = final_tgt))
}
