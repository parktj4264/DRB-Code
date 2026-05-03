#' @title Calculate Sigma Score
#' @description Computes one_sigma-based Sigma Score and additional metric columns.
#' @param dt data.table. The data containing MSR columns and group info.
#' @param msr_cols Character vector. Names of the MSR columns.
#' @param threshold Numeric. Cutoff for Up/Down direction and Glass flag.
#' @param ref_name Character. Optional user-specified Reference group name.
#' @param target_name Character. Optional user-specified Target group name.
#' @param metric_dir Character. Directory that contains metric_*.R definitions.
#' @param na_policy Character. Non-finite metric handling policy: "na"/"blank" (default) or "zero".
#' @param warn_on_metric_issue Logical. If TRUE, emit warnings when metric output is invalid.
#' @return list. Named list with results table, selected ref groups, and target groups.

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

emit_metric_issue_warning <- function(enabled, ...) {
  if (isTRUE(enabled)) {
    warning(...)
  }
}

validate_metric_vector <- function(metric_name, values, expected_length,
                                   na_policy = "na", warn_on_metric_issue = FALSE) {
  if (!is.numeric(values)) {
    emit_metric_issue_warning(
      warn_on_metric_issue,
      metric_name, " returned non-numeric values. Filling this metric by na_policy."
    )
    return(build_metric_fallback(expected_length, na_policy = na_policy))
  }

  if (length(values) != expected_length) {
    emit_metric_issue_warning(
      warn_on_metric_issue,
      metric_name, " returned length ", length(values),
      " but expected ", expected_length, ". Filling this metric by na_policy."
    )
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

build_group_stats_and_raw_cache <- function(dt, msr_cols, group_col, batch_size = 500) {
  chunks <- split(msr_cols, ceiling(seq_along(msr_cols) / batch_size))
  total_chunks <- length(chunks)

  stats_list <- vector("list", total_chunks)
  raw_cache_env <- new.env(parent = emptyenv(), hash = TRUE)
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

    batch_raw <- dt_long[is.finite(Value), .(
      raw_values = list(as.numeric(Value))
    ), by = c("MSR", group_col)]

    if (nrow(batch_raw) > 0) {
      batch_groups <- as.character(batch_raw[[group_col]])
      for (j in seq_len(nrow(batch_raw))) {
        cache_key <- make_raw_cache_key(batch_raw$MSR[[j]], batch_groups[[j]])
        assign(cache_key, batch_raw$raw_values[[j]], envir = raw_cache_env)
      }
    }

    utils::setTxtProgressBar(pb, i)
    rm(sub_dt, dt_long, batch_raw)
  }

  close(pb)

  list(
    all_stats = data.table::rbindlist(stats_list),
    raw_cache_env = raw_cache_env
  )
}

build_raw_access <- function(raw_cache_env) {
  get_group_values <- function(msr, group_name) {
    cache_key <- make_raw_cache_key(msr, group_name)
    if (!exists(cache_key, envir = raw_cache_env, inherits = FALSE)) {
      return(numeric(0))
    }
    as.numeric(get(cache_key, envir = raw_cache_env, inherits = FALSE))
  }

  has_pair <- function(msr, ref_group, target_group) {
    length(get_group_values(msr, ref_group)) > 0 &&
      length(get_group_values(msr, target_group)) > 0
  }

  get_pair <- function(msr, ref_group, target_group) {
    list(
      ref_values = get_group_values(msr, ref_group),
      tgt_values = get_group_values(msr, target_group)
    )
  }

  list(
    get_group_values = get_group_values,
    has_pair = has_pair,
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
                                na_policy = "na", warn_on_metric_issue = FALSE) {
  expected_length <- nrow(pair_stats)
  metric_values <- vector("list", length(metric_fns))
  names(metric_values) <- names(metric_fns)

  for (metric_name in names(metric_fns)) {
    raw_values <- tryCatch(
      call_metric_function(metric_name, metric_fns[[metric_name]], pair_stats, raw_access),
      error = function(e) {
        emit_metric_issue_warning(
          warn_on_metric_issue,
          metric_name, " failed: ", e$message, ". Filling this metric by na_policy."
        )
        build_metric_fallback(expected_length, na_policy = na_policy)
      }
    )

    metric_values[[metric_name]] <- validate_metric_vector(
      metric_name,
      raw_values,
      expected_length,
      na_policy = na_policy,
      warn_on_metric_issue = warn_on_metric_issue
    )
  }

  metric_values
}

calculate_sigma <- function(dt, msr_cols, threshold = 0.5,
                            ref_name = NULL, target_name = NULL,
                            metric_dir = here::here("src", "metrics"),
                            na_policy = "na",
                            warn_on_metric_issue = FALSE) {
  require(data.table)
  na_policy <- normalize_na_policy(na_policy)
  warn_on_metric_issue <- isTRUE(warn_on_metric_issue)

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
  raw_access <- build_raw_access(stats_and_raw$raw_cache_env)
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

  if (length(final_ref) == 1 && length(final_tgt) == 1) {
    pair_stats <- build_metric_pair_stats(final_dt, final_ref, final_tgt, n_by_group)
    if (is.null(pair_stats)) {
      stop("Missing columns required for metric calculation.")
    }

    metric_values <- evaluate_metric_set(
      pair_stats, metric_fns, raw_access,
      na_policy = na_policy,
      warn_on_metric_issue = warn_on_metric_issue
    )

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

        metric_values <- evaluate_metric_set(
          pair_stats, metric_fns, raw_access,
          na_policy = na_policy,
          warn_on_metric_issue = warn_on_metric_issue
        )

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
  final_dt[, Glass_Flag := Abs_Sigma_Score >= threshold]

  final_dt <- final_dt[order(-Abs_Sigma_Score)]

  final_dt[, Direction := "Stable"]
  final_dt[Sigma_Score > threshold, Direction := "Up"]
  final_dt[Sigma_Score < -threshold, Direction := "Down"]

  list(res = final_dt, ref = final_ref, tgt = final_tgt)
}
