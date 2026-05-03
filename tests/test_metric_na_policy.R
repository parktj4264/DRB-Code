# Regression test: non-finite metric handling policy (na_policy) works as expected.
source("src/00_libs.R")
source(here::here("src", "00_utils.R"))
source(here::here("src", "02_calc_stats.R"))

tmp_metric_dir <- file.path(tempdir(), paste0("metric_na_policy_", as.integer(Sys.time())))
dir.create(tmp_metric_dir, recursive = TRUE, showWarnings = FALSE)

metric_file <- file.path(tmp_metric_dir, "metric_test_set.R")
writeLines(c(
  "metric_one_sigma <- function(pair_stats) {",
  "  score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /",
  "    as.numeric(pair_stats$sd_ref)",
  "  score[!is.finite(score)] <- 0",
  "  as.numeric(score)",
  "}",
  "",
  "metric_non_finite <- function(pair_stats) {",
  "  out <- c(Inf, NA_real_)",
  "  as.numeric(out[seq_len(nrow(pair_stats))])",
  "}",
  "",
  "metric_bad_type <- function(pair_stats) {",
  "  c('x', 'y')",
  "}",
  "",
  "metric_bad_length <- function(pair_stats) {",
  "  c(1)",
  "}",
  "",
  "metric_boom <- function(pair_stats) {",
  "  stop('boom')",
  "}"
), con = metric_file)

dt <- data.table::data.table(
  ROOTID = paste0("W", 1:6),
  GROUP = c("REF", "REF", "REF", "TGT", "TGT", "TGT"),
  M1 = c(1, 2, 3, 4, 5, 6),
  M2 = c(2, 3, 4, 5, 6, 7)
)

common_args <- list(
  dt = dt,
  msr_cols = c("M1", "M2"),
  threshold = 1,
  ref_name = "REF",
  target_name = "TGT",
  metric_dir = tmp_metric_dir
)

res_zero <- do.call(calculate_sigma, c(common_args, list(na_policy = "zero")))$res
stopifnot(all(res_zero$metric_non_finite == 0))
stopifnot(all(res_zero$abs_metric_non_finite == 0))
stopifnot(all(res_zero$metric_bad_type == 0))
stopifnot(all(res_zero$metric_bad_length == 0))
stopifnot(all(res_zero$metric_boom == 0))

res_na <- do.call(calculate_sigma, c(common_args, list(na_policy = "na")))$res
stopifnot(all(is.na(res_na$metric_non_finite)))
stopifnot(all(is.na(res_na$abs_metric_non_finite)))
stopifnot(all(is.na(res_na$metric_bad_type)))
stopifnot(all(is.na(res_na$metric_bad_length)))
stopifnot(all(is.na(res_na$metric_boom)))

res_blank <- do.call(calculate_sigma, c(common_args, list(na_policy = "blank")))$res
stopifnot(all(is.na(res_blank$metric_non_finite)))
stopifnot(all(is.na(res_blank$abs_metric_non_finite)))

# Default is now "na"/blank.
res_default <- do.call(calculate_sigma, common_args)$res
stopifnot(all(is.na(res_default$metric_non_finite)))
stopifnot(all(is.na(res_default$metric_bad_type)))
stopifnot(all(is.na(res_default$metric_bad_length)))
stopifnot(all(is.na(res_default$metric_boom)))

err_msg <- tryCatch(
  {
    do.call(calculate_sigma, c(common_args, list(na_policy = "unknown")))
    ""
  },
  error = function(e) e$message
)
stopifnot(grepl("Invalid na_policy", err_msg))

cat("PASS: test_metric_na_policy.R\n")
