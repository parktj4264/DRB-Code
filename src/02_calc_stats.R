#' @title Calculate Sigma Score
#' @description Computes one_sigma-based Sigma Score and additional metric columns.
#' @param dt data.table. The data containing MSR columns and group info.
#' @param msr_cols Character vector. Names of the MSR columns.
#' @param threshold Numeric. Cutoff for Up/Down direction.
#' @param ref_name Character. Optional user-specified Reference group name.
#' @param target_name Character. Optional user-specified Target group name.
#' @param metric_dir Character. Directory that contains metric_*.R definitions.
#' @param na_policy Character. Non-finite metric handling policy: "na"/"blank" (default) or "zero".
#' @return list. Named list with results table, selected ref groups, target groups,
#' metric issue table, and metric runtime summary table.

load_metric_functions <- function(metric_dir = here::here("src", "metrics")) {
  if (!dir.exists(metric_dir)) {
    stop("Metric directory not found: ", metric_dir)
  }

  metric_files <- list.files(metric_dir, pattern = "\\.R$", full.names = TRUE)
  if (length(metric_files) == 0) {
    stop("No metric definition files found in: ", metric_dir)
  }

  metric_env <- new.env(parent = baseenv())
  for (metric_file in metric_files) {
    sys.source(metric_file, envir = metric_env)
  }

  metric_names <- sort(ls(metric_env, pattern = "^metric_"))
  if (length(metric_names) == 0) {
    stop("No metric_* functions found in: ", metric_dir)
  }

  metric_fns <- lapply(metric_names, function(metric_name) {
    get(metric_name, envir = metric_env)
  })
  names(metric_fns) <- metric_names

  metric_fns <- metric_fns[vapply(metric_fns, is.function, logical(1))]
  if (length(metric_fns) == 0) {
    stop("No metric functions are callable in: ", metric_dir)
  }

  if (!"metric_one_sigma" %in% names(metric_fns)) {
    stop("Required metric function 'metric_one_sigma' is missing.")
  }

  ordered_names <- c("metric_one_sigma", setdiff(names(metric_fns), "metric_one_sigma"))
  metric_fns[ordered_names]
}

normalize_na_policy <- function(na_policy = "na") {
  if (is.null(na_policy) || length(na_policy) == 0) {
    return("na")
  }

  policy <- tolower(as.character(na_policy[[1]]))
  if (policy == "blank") {
    policy <- "na"
  }

  if (!policy %in% c("zero", "na")) {
    stop("Invalid na_policy: ", na_policy, ". Use 'zero', 'na', or 'blank'.")
  }

  policy
}

normalize_metric_values <- function(values, na_policy = "na") {
  policy <- normalize_na_policy(na_policy)
  values <- as.numeric(values)

  invalid <- !is.finite(values)
  if (policy == "zero") {
    values[invalid] <- 0
  } else {
    values[invalid] <- NA_real_
  }

  values
}

build_metric_fallback <- function(expected_length, na_policy = "na") {
  normalize_metric_values(rep(NA_real_, expected_length), na_policy = na_policy)
}

empty_metric_issue_table <- function() {
  data.table::data.table(
    metric_name = character(),
    issue_type = character(),
    pair_id = character(),
    message = character(),
    count = integer()
  )
}

normalize_metric_issue_table <- function(metric_issues) {
  if (is.null(metric_issues) || nrow(metric_issues) == 0) {
    return(empty_metric_issue_table())
  }

  out <- data.table::data.table(
    metric_name = as.character(metric_issues$metric_name),
    issue_type = as.character(metric_issues$issue_type),
    pair_id = as.character(metric_issues$pair_id),
    message = as.character(metric_issues$message),
    count = as.integer(metric_issues$count)
  )

  out[is.na(count) | count < 1L, count := 1L]
  out
}

summarize_metric_issues <- function(metric_issues) {
  issue_dt <- normalize_metric_issue_table(metric_issues)
  if (nrow(issue_dt) == 0) {
    return(issue_dt)
  }

  issue_dt[
    ,
    .(count = as.integer(sum(count))),
    by = .(metric_name, issue_type, pair_id, message)
  ][order(metric_name, issue_type, pair_id, message)]
}

empty_metric_timing_table <- function() {
  data.table::data.table(
    metric_name = character(),
    pair_id = character(),
    elapsed_sec = numeric()
  )
}

normalize_metric_timing_table <- function(metric_timing) {
  if (is.null(metric_timing) || nrow(metric_timing) == 0) {
    return(empty_metric_timing_table())
  }

  out <- data.table::data.table(
    metric_name = as.character(metric_timing$metric_name),
    pair_id = as.character(metric_timing$pair_id),
    elapsed_sec = as.numeric(metric_timing$elapsed_sec)
  )

  out[!is.finite(elapsed_sec) | elapsed_sec < 0, elapsed_sec := 0]
  out
}

summarize_metric_timing <- function(metric_timing) {
  timing_dt <- normalize_metric_timing_table(metric_timing)
  if (nrow(timing_dt) == 0) {
    return(timing_dt)
  }

  timing_dt[
    ,
    .(
      elapsed_sec = sum(elapsed_sec),
      pair_count = data.table::uniqueN(pair_id)
    ),
    by = .(metric_name)
  ][order(-elapsed_sec, metric_name)]
}

new_metric_issue_collector <- function() {
  rows <- list()

  add_issue <- function(metric_name, issue_type, pair_id, message, count = 1L) {
    rows[[length(rows) + 1L]] <<- data.table::data.table(
      metric_name = as.character(metric_name),
      issue_type = as.character(issue_type),
      pair_id = as.character(pair_id),
      message = as.character(message),
      count = as.integer(count)
    )
    invisible(NULL)
  }

  get_issues <- function() {
    if (length(rows) == 0) {
      return(empty_metric_issue_table())
    }
    summarize_metric_issues(data.table::rbindlist(rows, fill = TRUE))
  }

  list(add = add_issue, get = get_issues)
}

validate_metric_vector <- function(metric_name, values, expected_length,
                                   na_policy = "na", pair_id = "single_pair",
                                   add_issue = NULL) {
  if (!is.numeric(values)) {
    if (is.function(add_issue)) {
      add_issue(
        metric_name = metric_name,
        issue_type = "type_mismatch",
        pair_id = pair_id,
        message = "Returned non-numeric values; filled by na_policy."
      )
    }
    return(build_metric_fallback(expected_length, na_policy = na_policy))
  }

  if (length(values) != expected_length) {
    if (is.function(add_issue)) {
      add_issue(
        metric_name = metric_name,
        issue_type = "length_mismatch",
        pair_id = pair_id,
        message = paste0(
          "Returned length ", length(values),
          " but expected ", expected_length, "; filled by na_policy."
        )
      )
    }
    return(build_metric_fallback(expected_length, na_policy = na_policy))
  }

  normalize_metric_values(values, na_policy = na_policy)
}

build_metric_pair_stats <- function(final_dt, ref_group, target_group, n_by_group) {
  col_mean_ref <- paste0("Mean_", ref_group)
  col_mean_tgt <- paste0("Mean_", target_group)
  col_sd_ref <- paste0("SD_", ref_group)
  col_sd_tgt <- paste0("SD_", target_group)
  col_n_valid_ref <- paste0("N_valid_", ref_group)
  col_n_valid_tgt <- paste0("N_valid_", target_group)

  required_cols <- c(col_mean_ref, col_mean_tgt, col_sd_ref, col_sd_tgt, col_n_valid_ref, col_n_valid_tgt)
  if (!all(required_cols %in% names(final_dt))) {
    return(NULL)
  }

  if (!all(c(ref_group, target_group) %in% names(n_by_group))) {
    return(NULL)
  }

  data.table::data.table(
    MSR = final_dt[["MSR"]],
    ref_group = ref_group,
    target_group = target_group,
    mean_ref = as.numeric(final_dt[[col_mean_ref]]),
    mean_tgt = as.numeric(final_dt[[col_mean_tgt]]),
    sd_ref = as.numeric(final_dt[[col_sd_ref]]),
    sd_tgt = as.numeric(final_dt[[col_sd_tgt]]),
    n_ref = as.numeric(n_by_group[[ref_group]]),
    n_tgt = as.numeric(n_by_group[[target_group]]),
    n_ref_valid = as.numeric(final_dt[[col_n_valid_ref]]),
    n_tgt_valid = as.numeric(final_dt[[col_n_valid_tgt]])
  )
}

make_raw_cache_key <- function(msr, group_name) {
  paste0(as.character(msr), "\t", as.character(group_name))
}

get_raw_cache_entry <- function(raw_cache_env, msr, group_name) {
  cache_key <- make_raw_cache_key(msr, group_name)
  if (!exists(cache_key, envir = raw_cache_env, inherits = FALSE)) {
    return(NULL)
  }
  get(cache_key, envir = raw_cache_env, inherits = FALSE)
}

build_group_stats_and_raw_cache <- function(dt, msr_cols, group_col, batch_size = 500) {
  chunks <- split(msr_cols, ceiling(seq_along(msr_cols) / batch_size))
  total_chunks <- length(chunks)

  stats_list <- vector("list", total_chunks)
  raw_cache_env <- new.env(parent = emptyenv(), hash = TRUE)
  meta_cols <- setdiff(names(dt), c(group_col, msr_cols))
  meta_dt <- dt[, ..meta_cols]
  pb <- utils::txtProgressBar(min = 0, max = total_chunks, style = 3)

  for (i in seq_along(chunks)) {
    chunk_cols <- chunks[[i]]
    sub_dt <- dt[, c(group_col, chunk_cols), with = FALSE]

    dt_long <- data.table::melt(sub_dt,
      id.vars = group_col,
      measure.vars = chunk_cols,
      variable.name = "MSR",
      value.name = "Value"
    )
    dt_long[, Value := as.numeric(Value)]

    stats_list[[i]] <- dt_long[, .(
      Mean = mean(Value, na.rm = TRUE),
      SD = sd(Value, na.rm = TRUE),
      N_valid = sum(is.finite(Value))
    ), by = c("MSR", group_col)]

    # Cache finite raw values + row indices so raw_access can retrieve metadata quickly.
    for (msr in chunk_cols) {
      msr_values <- as.numeric(dt[[msr]])
      finite_idx <- which(is.finite(msr_values))
      if (length(finite_idx) == 0) {
        next
      }

      msr_cache_dt <- data.table::data.table(
        group_name = as.character(dt[[group_col]][finite_idx]),
        row_idx = as.integer(finite_idx),
        raw_value = msr_values[finite_idx]
      )

      grouped_cache <- msr_cache_dt[, .(
        row_idx = list(as.integer(row_idx)),
        raw_values = list(as.numeric(raw_value))
      ), by = group_name]

      if (nrow(grouped_cache) > 0) {
        for (j in seq_len(nrow(grouped_cache))) {
          cache_key <- make_raw_cache_key(msr, grouped_cache$group_name[[j]])
          assign(cache_key, list(
            row_idx = grouped_cache$row_idx[[j]],
            raw_values = grouped_cache$raw_values[[j]]
          ), envir = raw_cache_env)
        }
      }
    }

    utils::setTxtProgressBar(pb, i)
    rm(sub_dt, dt_long)
  }

  close(pb)

  list(
    all_stats = data.table::rbindlist(stats_list),
    raw_cache_env = raw_cache_env,
    meta_dt = meta_dt,
    meta_cols = meta_cols
  )
}

build_raw_access <- function(raw_cache_env, meta_dt, meta_cols) {
  get_group_values <- function(msr, group_name) {
    cache_entry <- get_raw_cache_entry(raw_cache_env, msr, group_name)
    if (is.null(cache_entry)) {
      return(numeric(0))
    }
    as.numeric(cache_entry$raw_values)
  }

  get_group_meta <- function(msr, group_name, include_values = FALSE) {
    cache_entry <- get_raw_cache_entry(raw_cache_env, msr, group_name)
    if (is.null(cache_entry)) {
      empty_meta <- data.table::data.table(matrix(nrow = 0, ncol = length(meta_cols)))
      data.table::setnames(empty_meta, meta_cols)
      if (include_values) {
        empty_meta[, raw_value := numeric(0)]
      }
      return(empty_meta)
    }

    out <- data.table::copy(meta_dt[cache_entry$row_idx, ..meta_cols])
    if (include_values) {
      out[, raw_value := as.numeric(cache_entry$raw_values)]
    }
    out
  }

  get_group_data <- function(msr, group_name) {
    get_group_meta(msr, group_name, include_values = TRUE)
  }

  has_pair <- function(msr, ref_group, target_group) {
    length(get_group_values(msr, ref_group)) > 0 &&
      length(get_group_values(msr, target_group)) > 0
  }

  get_pair_meta <- function(msr, ref_group, target_group, include_values = FALSE) {
    list(
      ref_meta = get_group_meta(msr, ref_group, include_values = include_values),
      tgt_meta = get_group_meta(msr, target_group, include_values = include_values)
    )
  }

  get_pair <- function(msr, ref_group, target_group) {
    pair_meta <- get_pair_meta(msr, ref_group, target_group, include_values = TRUE)
    list(
      ref_values = get_group_values(msr, ref_group),
      tgt_values = get_group_values(msr, target_group),
      ref_meta = pair_meta$ref_meta,
      tgt_meta = pair_meta$tgt_meta
    )
  }

  list(
    meta_columns = meta_cols,
    get_group_values = get_group_values,
    get_group_meta = get_group_meta,
    get_group_data = get_group_data,
    has_pair = has_pair,
    get_pair_meta = get_pair_meta,
    get_pair = get_pair
  )
}

call_metric_function <- function(metric_name, metric_fn, pair_stats, raw_access) {
  metric_arity <- length(formals(metric_fn))

  if (metric_arity <= 1) {
    return(metric_fn(pair_stats))
  }

  metric_fn(pair_stats, raw_access)
}

evaluate_metric_set <- function(pair_stats, metric_fns, raw_access,
                                na_policy = "na", pair_id = "single_pair") {
  expected_length <- nrow(pair_stats)
  metric_values <- vector("list", length(metric_fns))
  names(metric_values) <- names(metric_fns)
  issue_collector <- new_metric_issue_collector()
  timing_rows <- vector("list", length(metric_fns))
  timing_idx <- 0L

  for (metric_name in names(metric_fns)) {
    start_elapsed <- unname(proc.time()[["elapsed"]])

    raw_values <- tryCatch(
      call_metric_function(metric_name, metric_fns[[metric_name]], pair_stats, raw_access),
      error = function(e) {
        issue_collector$add(
          metric_name = metric_name,
          issue_type = "error",
          pair_id = pair_id,
          message = as.character(e$message)
        )
        build_metric_fallback(expected_length, na_policy = na_policy)
      }
    )
    end_elapsed <- unname(proc.time()[["elapsed"]])

    metric_values[[metric_name]] <- validate_metric_vector(
      metric_name,
      raw_values,
      expected_length,
      na_policy = na_policy,
      pair_id = pair_id,
      add_issue = issue_collector$add
    )

    timing_idx <- timing_idx + 1L
    timing_rows[[timing_idx]] <- data.table::data.table(
      metric_name = metric_name,
      pair_id = pair_id,
      elapsed_sec = as.numeric(end_elapsed - start_elapsed)
    )
  }

  list(
    values = metric_values,
    issues = issue_collector$get(),
    timings = normalize_metric_timing_table(data.table::rbindlist(timing_rows, fill = TRUE))
  )
}

write_metric_issue_reports <- function(metric_issues, archive_dir, timestamp_str,
                                       latest_path = here::here("output", "metric_issues_latest.csv")) {
  issue_dt <- summarize_metric_issues(metric_issues)
  archive_path <- file.path(archive_dir, paste0("metric_issues_", timestamp_str, ".csv"))

  data.table::fwrite(issue_dt, archive_path)
  data.table::fwrite(issue_dt, latest_path)

  list(
    archive_path = archive_path,
    latest_path = latest_path,
    issue_count = nrow(issue_dt)
  )
}

calculate_sigma <- function(dt, msr_cols, threshold = 0.5,
                            ref_name = NULL, target_name = NULL,
                            metric_dir = here::here("src", "metrics"),
                            na_policy = "na") {
  require(data.table)
  na_policy <- normalize_na_policy(na_policy)

  log_msg("Starting Sigma Score calculation (Single Core).")

  group_col <- "GROUP"
  if (!group_col %in% names(dt)) {
    candidates <- names(dt)[!names(dt) %in% c("ROOTID", msr_cols)]
    if (length(candidates) == 1) {
      group_col <- candidates[1]
      log_msg(paste0("Auto-detected group column: ", group_col))
    } else {
      stop("Cannot identify GROUP column. ROOTID.csv must have a 'GROUP' column.")
    }
  }

  log_msg("Calculating statistics and preparing raw cache...")
  stats_and_raw <- build_group_stats_and_raw_cache(dt, msr_cols, group_col)
  all_stats <- stats_and_raw$all_stats
  raw_access <- build_raw_access(
    stats_and_raw$raw_cache_env,
    stats_and_raw$meta_dt,
    stats_and_raw$meta_cols
  )
  available_groups <- unique(all_stats[[group_col]])

  final_ref <- NULL
  final_tgt <- NULL

  if (!is.null(ref_name)) {
    valid_refs <- intersect(ref_name, available_groups)
    if (length(valid_refs) > 0) {
      final_ref <- valid_refs
      if (length(valid_refs) < length(ref_name)) {
        dropped <- setdiff(ref_name, valid_refs)
        log_msg(paste0("[Warning] Groups not found and ignored: ", paste(dropped, collapse = ", ")))
      }
    } else {
      log_msg("[Warning] None of the defined Ref groups found. Falling back to auto-detect.")
    }
  }

  if (!is.null(target_name)) {
    valid_tgts <- intersect(target_name, available_groups)
    if (length(valid_tgts) > 0) {
      final_tgt <- valid_tgts
      if (length(valid_tgts) < length(target_name)) {
        dropped <- setdiff(target_name, valid_tgts)
        log_msg(paste0("[Warning] Groups not found and ignored: ", paste(dropped, collapse = ", ")))
      }
    } else {
      log_msg("[Warning] None of the defined Target groups found. Falling back to auto-detect.")
    }
  }

  sorted_groups <- sort(available_groups)
  if (is.null(final_ref) && length(sorted_groups) > 0) {
    final_ref <- sorted_groups[1]
  }

  if (is.null(final_tgt)) {
    remaining <- setdiff(sorted_groups, final_ref)
    if (length(remaining) > 0) {
      final_tgt <- remaining[1]
    }
  }

  if (is.null(final_ref) || is.null(final_tgt)) {
    stop("Could not determine Reference and Target groups. Available groups: ",
      paste(available_groups, collapse = ", "))
  }

  n_by_group_dt <- dt[, .(N = uniqueN(ROOTID)), by = group_col]
  n_by_group <- setNames(n_by_group_dt$N, n_by_group_dt[[group_col]])

  for (r in final_ref) {
    n_r <- n_by_group[[r]]
    log_msg(paste0("Reference Group: [", r, "] (N=", format(n_r, big.mark = ","), ")"))
  }
  for (t in final_tgt) {
    n_t <- n_by_group[[t]]
    log_msg(paste0("Target Group:    [", t, "] (N=", format(n_t, big.mark = ","), ")"))
  }

  final_dt <- dcast(all_stats, MSR ~ get(group_col), value.var = c("Mean", "SD", "N_valid"))

  metric_fns <- load_metric_functions(metric_dir = metric_dir)
  metric_names <- names(metric_fns)
  log_msg(paste0("Loaded metric functions: ", paste(metric_names, collapse = ", ")))

  log_msg("Calculating metric scores...")
  issue_tables <- list()
  timing_tables <- list()

  if (length(final_ref) == 1 && length(final_tgt) == 1) {
    pair_stats <- build_metric_pair_stats(final_dt, final_ref, final_tgt, n_by_group)
    if (is.null(pair_stats)) {
      stop("Missing columns required for metric calculation.")
    }

    single_pair_id <- paste0(as.character(final_ref[[1]]), "_", as.character(final_tgt[[1]]))
    eval_res <- evaluate_metric_set(
      pair_stats, metric_fns, raw_access,
      na_policy = na_policy,
      pair_id = single_pair_id
    )
    metric_values <- eval_res$values
    issue_tables[[length(issue_tables) + 1L]] <- eval_res$issues
    timing_tables[[length(timing_tables) + 1L]] <- eval_res$timings

    for (metric_name in metric_names) {
      final_dt[, (metric_name) := metric_values[[metric_name]]]
      final_dt[, (paste0("abs_", metric_name)) := abs(metric_values[[metric_name]])]
    }
  } else {
    log_msg(paste0("Multi-group mode detected. Ref=", length(final_ref), ", Target=", length(final_tgt)))

    pair_ids <- character()
    pair_metric_cols <- setNames(vector("list", length(metric_names)), metric_names)
    pair_abs_one_sigma_cols <- character()

    for (r in final_ref) {
      for (t in final_tgt) {
        if (r == t) {
          next
        }

        pair_stats <- build_metric_pair_stats(final_dt, r, t, n_by_group)
        if (is.null(pair_stats)) {
          log_msg(paste0("[Skip] Missing columns for pair ", r, " vs ", t))
          next
        }

        pair_id <- paste0(r, "_", t)
        pair_ids <- c(pair_ids, pair_id)

        eval_res <- evaluate_metric_set(
          pair_stats, metric_fns, raw_access,
          na_policy = na_policy,
          pair_id = pair_id
        )
        metric_values <- eval_res$values
        issue_tables[[length(issue_tables) + 1L]] <- eval_res$issues
        timing_tables[[length(timing_tables) + 1L]] <- eval_res$timings

        for (metric_name in metric_names) {
          pair_col <- paste0(metric_name, "_", pair_id)
          pair_abs_col <- paste0("abs_", metric_name, "_", pair_id)

          final_dt[, (pair_col) := metric_values[[metric_name]]]
          final_dt[, (pair_abs_col) := abs(metric_values[[metric_name]])]

          pair_metric_cols[[metric_name]] <- c(pair_metric_cols[[metric_name]], pair_col)

          if (metric_name == "metric_one_sigma") {
            legacy_col <- paste0("Sigma_Score_", pair_id)
            legacy_abs_col <- paste0("Abs_Sigma_Score_", pair_id)
            final_dt[, (legacy_col) := metric_values[[metric_name]]]
            final_dt[, (legacy_abs_col) := abs(metric_values[[metric_name]])]
            pair_abs_one_sigma_cols <- c(pair_abs_one_sigma_cols, pair_abs_col)
          }
        }
      }
    }

    if (length(pair_ids) == 0 || length(pair_abs_one_sigma_cols) == 0) {
      stop("No valid group combinations found for Sigma Score calculation.")
    }

    one_sigma_abs_matrix <- as.matrix(final_dt[, ..pair_abs_one_sigma_cols])
    one_sigma_abs_matrix[!is.finite(one_sigma_abs_matrix)] <- -Inf

    max_idx <- max.col(one_sigma_abs_matrix, ties.method = "first")
    valid_rows <- rowSums(is.finite(one_sigma_abs_matrix)) > 0
    if (any(!valid_rows)) {
      max_idx[!valid_rows] <- 1L
    }

    row_idx <- seq_len(nrow(final_dt))

    for (metric_name in metric_names) {
      metric_cols <- pair_metric_cols[[metric_name]]

      if (length(metric_cols) == 0) {
        fallback_value <- if (na_policy == "zero") 0 else NA_real_
        final_dt[, (metric_name) := fallback_value]
        final_dt[, (paste0("abs_", metric_name)) := abs(fallback_value)]
        next
      }

      metric_matrix <- as.matrix(final_dt[, ..metric_cols])
      selected_values <- as.numeric(metric_matrix[cbind(row_idx, max_idx)])
      selected_values <- normalize_metric_values(selected_values, na_policy = na_policy)

      final_dt[, (metric_name) := selected_values]
      final_dt[, (paste0("abs_", metric_name)) := abs(selected_values)]
    }
  }

  final_dt[, Sigma_Score := metric_one_sigma]
  final_dt[, Abs_Sigma_Score := abs_metric_one_sigma]

  final_dt <- final_dt[order(-Abs_Sigma_Score)]

  final_dt[, Direction := "Stable"]
  final_dt[Sigma_Score > threshold, Direction := "Up"]
  final_dt[Sigma_Score < -threshold, Direction := "Down"]

  metric_issues <- empty_metric_issue_table()
  if (length(issue_tables) > 0) {
    metric_issues <- summarize_metric_issues(data.table::rbindlist(issue_tables, fill = TRUE))
  }

  metric_timings <- empty_metric_timing_table()
  if (length(timing_tables) > 0) {
    metric_timings <- normalize_metric_timing_table(data.table::rbindlist(timing_tables, fill = TRUE))
  }
  metric_timing_summary <- summarize_metric_timing(metric_timings)
  if (nrow(metric_timing_summary) > 0) {
    log_msg("Metric runtime summary (seconds):")
    for (i in seq_len(nrow(metric_timing_summary))) {
      metric_name <- as.character(metric_timing_summary$metric_name[i])
      elapsed_sec <- as.numeric(metric_timing_summary$elapsed_sec[i])
      pair_count <- as.integer(metric_timing_summary$pair_count[i])
      log_msg(sprintf("  - %s: %.3f sec (pairs=%d)", metric_name, elapsed_sec, pair_count))
    }
    log_msg(sprintf("Metric runtime total: %.3f sec", sum(metric_timing_summary$elapsed_sec)))
  }

  list(
    res = final_dt,
    ref = final_ref,
    tgt = final_tgt,
    metric_issues = metric_issues,
    metric_runtime_summary = metric_timing_summary
  )
}
