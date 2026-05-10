# Regression test: raw_access exposes metadata columns (e.g., EDGE/Radius) for metric logic.
source("src/00_libs.R")
source(here::here("src", "00_utils.R"))
source(here::here("src", "02_calc_stats.R"))

tmp_metric_dir <- file.path(tempdir(), paste0("metric_meta_test_", as.integer(Sys.time())))
dir.create(tmp_metric_dir, recursive = TRUE, showWarnings = FALSE)

metric_file <- file.path(tmp_metric_dir, "metric_meta_set.R")
writeLines(c(
  "metric_one_sigma <- function(pair_stats) {",
  "  out <- as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)",
  "  out[!is.finite(out)] <- 0",
  "  as.numeric(out)",
  "}",
  "",
  "metric_meta_radius_gap <- function(pair_stats, raw_access) {",
  "  out <- vapply(seq_len(nrow(pair_stats)), function(i) {",
  "    msr <- as.character(pair_stats$MSR[i])",
  "    ref_group <- as.character(pair_stats$ref_group[i])",
  "    tgt_group <- as.character(pair_stats$target_group[i])",
  "    pair_meta <- raw_access$get_pair_meta(msr, ref_group, tgt_group)",
  "    ref_radius <- as.numeric(pair_meta$ref_meta$Radius)",
  "    tgt_radius <- as.numeric(pair_meta$tgt_meta$Radius)",
  "    if (length(ref_radius) == 0 || length(tgt_radius) == 0) return(0)",
  "    val <- mean(tgt_radius) - mean(ref_radius)",
  "    if (!is.finite(val)) return(0)",
  "    as.numeric(val)",
  "  }, numeric(1))",
  "  out[!is.finite(out)] <- 0",
  "  as.numeric(out)",
  "}",
  "",
  "metric_meta_edge_e1_ratio_gap <- function(pair_stats, raw_access) {",
  "  out <- vapply(seq_len(nrow(pair_stats)), function(i) {",
  "    msr <- as.character(pair_stats$MSR[i])",
  "    ref_group <- as.character(pair_stats$ref_group[i])",
  "    tgt_group <- as.character(pair_stats$target_group[i])",
  "    raw_pair <- raw_access$get_pair(msr, ref_group, tgt_group)",
  "    ref_edge <- as.character(raw_pair$ref_meta$EDGE)",
  "    tgt_edge <- as.character(raw_pair$tgt_meta$EDGE)",
  "    if (length(ref_edge) == 0 || length(tgt_edge) == 0) return(0)",
  "    ref_ratio <- mean(ref_edge == 'E1')",
  "    tgt_ratio <- mean(tgt_edge == 'E1')",
  "    val <- tgt_ratio - ref_ratio",
  "    if (!is.finite(val)) return(0)",
  "    as.numeric(val)",
  "  }, numeric(1))",
  "  out[!is.finite(out)] <- 0",
  "  as.numeric(out)",
  "}"
), con = metric_file)

dt <- data.table::data.table(
  ROOTID = paste0("W", 1:8),
  GROUP = c("REF", "REF", "REF", "REF", "TGT", "TGT", "TGT", "TGT"),
  EDGE = c("E1", "E1", "E2", "E2", "E1", "E3", "E3", "E4"),
  Radius = c(10, 12, 11, 13, 20, 18, 22, 20),
  PARTID = c("P1", "P1", "P2", "P2", "P1", "P1", "P2", "P2"),
  M1 = c(1, 2, 3, 4, 5, 6, 7, 8),
  M2 = c(11, 12, 13, 14, 15, 16, 17, 18)
)

res <- calculate_sigma(
  dt = dt,
  msr_cols = c("M1", "M2"),
  threshold = 1,
  ref_name = "REF",
  target_name = "TGT",
  metric_dir = tmp_metric_dir
)$res

required_cols <- c("metric_meta_radius_gap", "metric_meta_edge_e1_ratio_gap")
missing_cols <- setdiff(required_cols, names(res))
stopifnot(length(missing_cols) == 0)

radius_gap <- setNames(res$metric_meta_radius_gap, res$MSR)
edge_gap <- setNames(res$metric_meta_edge_e1_ratio_gap, res$MSR)

expected_radius_gap <- c(M1 = 8.5, M2 = 8.5)
expected_edge_gap <- c(M1 = -0.25, M2 = -0.25)

stopifnot(all(abs(radius_gap[names(expected_radius_gap)] - expected_radius_gap) < 1e-12))
stopifnot(all(abs(edge_gap[names(expected_edge_gap)] - expected_edge_gap) < 1e-12))

cat("PASS: test_raw_access_metadata.R\n")
