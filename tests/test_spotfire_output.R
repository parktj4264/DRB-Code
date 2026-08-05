# Regression test: fixed Spotfire schema, pair selection, and latest-file replacement.
source("src/bootstrap/libs.R", local = environment())
source("src/bootstrap/utils.R", local = environment())
source("src/bootstrap/io_utils.R", local = environment())
source("src/04_create_spotfire.R", local = environment())
source("src/05_finalize_outputs.R", local = environment())

result_dt <- data.table::data.table(
  MSR = c("M1", "M2", "M3"),
  Mean_A = c(1, 2, NA),
  Mean_B = c(1.2, 2.7, NA),
  Mean_C = c(0.1, 2.4, NA),
  SD_A = c(1, 1, NA),
  SD_B = c(1.1, 1.2, NA),
  SD_C = c(0.9, 1.3, NA),
  N_valid_A = c(100, 99, 0),
  N_valid_B = c(90, 89, 0),
  N_valid_C = c(80, 79, 0),
  metric_one_sigma_A_B = c(0.2, 0.7, NA),
  metric_one_sigma_A_C = c(-0.9, 0.4, NA),
  metric_one_sigma = c(-0.9, 0.7, NA),
  ITEM_NAME = c("측정 1", "측정 2", "측정 3"),
  ITEM_GROUP_ID = c("G1", "G2", "G3"),
  SPEC_TYPE = c(" u ", "D", "n"),
  Category1 = c("CAT_A", "CAT_B", "CAT_C"),
  Category2 = c("SUB_A", "SUB_B", "SUB_C"),
  SLIDE_REQUIRED_YN = c("Y", "N", "N"),
  SUMMARY_REQUIRED_YN = c("N", "Y", "N")
)
raw_dt <- data.table::data.table(
  ROOTID = c("A1", "A2", "B1", "C1", "C2", "C3"),
  GROUP = c("A", "A", "B", "C", "C", "C")
)

feed <- build_spotfire_sigma_table(
  result_dt = result_dt,
  dt = raw_dt,
  final_ref = "A",
  final_tgt = c("B", "C"),
  sigma_threshold = 0.5,
  raw_filename = "raw.csv",
  generated_at = as.POSIXct("2026-07-29 01:02:03", tz = "Asia/Seoul")
)

stopifnot(identical(names(feed), get_spotfire_sigma_columns()))
stopifnot(nrow(feed) == 6L)
selected_counts <- feed[, .(selected_n = sum(is_selected_pair)), by = MSR]
stopifnot(selected_counts[MSR %in% c("M1", "M2"), all(selected_n == 1L)])
stopifnot(selected_counts[MSR == "M3", selected_n] == 0L)
stopifnot(feed[MSR == "M1" & is_selected_pair, target_group] == "C")
stopifnot(feed[MSR == "M2" & is_selected_pair, target_group] == "B")
stopifnot(feed[ref_group == "A", unique(n_ref_wf)] == 2L)
stopifnot(feed[target_group == "C", unique(n_tgt_wf)] == 3L)
stopifnot(all(c("Category3", "Category4", "Category5") %in% names(feed)))
stopifnot(all(is.na(feed$Category3)))
stopifnot(feed[MSR == "M1", all(SPEC_TYPE == "U" & SPEC_TYPE_KO == "망소")])
stopifnot(feed[MSR == "M2", all(SPEC_TYPE == "D" & SPEC_TYPE_KO == "망대")])
stopifnot(feed[MSR == "M3", all(SPEC_TYPE == "N" & SPEC_TYPE_KO == "망목")])

output_dir <- tempfile("drb_spotfire_atomic_")
stopifnot(dir.create(output_dir, recursive = TRUE, showWarnings = FALSE))
on.exit(unlink(output_dir, recursive = TRUE, force = TRUE), add = TRUE)
latest_path <- file.path(output_dir, "sigma_score_raw.csv")

atomic_fwrite(feed[1L], latest_path)
atomic_fwrite(feed[2:6], latest_path)
round_trip <- data.table::fread(latest_path)
stopifnot(nrow(round_trip) == 5L)
stopifnot(identical(round_trip$item_name, feed$item_name[2:6]))

atomic_fwrite(empty_spotfire_sigma_table(), latest_path)
header_only <- data.table::fread(latest_path)
stopifnot(nrow(header_only) == 0L)
stopifnot(identical(names(header_only), get_spotfire_sigma_columns()))
stopifnot(length(list.files(output_dir, pattern = "\\.(tmp|bak)$")) == 0L)

legacy_path <- file.path(output_dir, "legacy_sigma_score_raw.csv")
writeLines("legacy", legacy_path)
stopifnot(remove_legacy_spotfire_output(legacy_path))
stopifnot(!file.exists(legacy_path))

cat("PASS: test_spotfire_output.R\n")
