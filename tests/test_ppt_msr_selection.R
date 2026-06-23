source("src/03_create_ppt.R", local = environment())

stopifnot(identical(
  normalize_required_yn(c("Y", "yes", "TRUE", "1", "", "N", NA)),
  c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)
))

cfg <- resolve_ppt_config(list(
  detail_group_by = "Category5",
  detail_msr_selection_mode = "both",
  summary_msr_selection_mode = "required_only",
  summary_category_columns = c("Category1", "Category4", "Category5")
))
stopifnot(cfg$detail_group_by == "Category5")
stopifnot(cfg$detail_msr_selection_mode == "both")
stopifnot(cfg$summary_msr_selection_mode == "required_only")
stopifnot(identical(cfg$summary_category_columns, c("Category1", "Category4", "Category5")))

raw_result_dt <- data.table::data.table(
  MSR = c("R_STABLE", "FLAG_ONLY", "REQ_FLAG", "NONE"),
  ITEM_NAME = c("Required Stable", "Flagged Only", "Required Flagged", "None"),
  Direction = c("Stable", "Up", "Down", "Stable"),
  Abs_Sigma_Score = c(0.1, 5.0, 2.0, 0.0),
  Sigma_Score = c(0.1, 5.0, -2.0, 0.0),
  Category1 = c("PERI", "PERI", "CORE", ""),
  Category2 = c("PB", "PB", "", ""),
  Category3 = c("", "", "", ""),
  SLIDE_REQUIRED_YN = c("Y", "", "yes", ""),
  SUMMARY_REQUIRED_YN = c("", "TRUE", "1", "")
)

result_dt <- prepare_ppt_result_dt(raw_result_dt)
stopifnot(all(c("Category4", "Category5", "SLIDE_REQUIRED_YN", "SUMMARY_REQUIRED_YN") %in% names(result_dt)))
stopifnot(identical(result_dt$ppt_slide_required, c(TRUE, FALSE, TRUE, FALSE)))
stopifnot(identical(result_dt$ppt_summary_required, c(FALSE, TRUE, TRUE, FALSE)))

detail_both <- select_ppt_candidate_dt(result_dt, "both", "ppt_slide_required")
stopifnot(identical(detail_both$MSR, c("REQ_FLAG", "R_STABLE", "FLAG_ONLY")))

detail_required <- select_ppt_candidate_dt(result_dt, "required_only", "ppt_slide_required")
stopifnot(identical(detail_required$MSR, c("REQ_FLAG", "R_STABLE")))

detail_flagged <- select_ppt_candidate_dt(result_dt, "flagged_only", "ppt_slide_required")
stopifnot(identical(detail_flagged$MSR, c("REQ_FLAG", "FLAG_ONLY")))

summary_required <- select_ppt_candidate_dt(result_dt, "required_only", "ppt_summary_required")
stopifnot(identical(summary_required$MSR, c("FLAG_ONLY", "REQ_FLAG")))

detail_grouped <- add_detail_group_columns(detail_both, "Category5")
group_labels <- stats::setNames(detail_grouped$ppt_detail_group_label, detail_grouped$MSR)
stopifnot(group_labels[["REQ_FLAG"]] == "Category1: CORE")
stopifnot(group_labels[["R_STABLE"]] == "Category2: PB")
stopifnot(group_labels[["FLAG_ONLY"]] == "Category2: PB")

summary_display <- build_summary_display_dt(summary_required, cfg$summary_category_columns)
stopifnot(identical(names(summary_display), c("Cat1", "Cat4", "Cat5", "MSR", "Score", "Dir")))
stopifnot(identical(summary_display$MSR, c("Flagged Only", "Required Flagged")))

cat("PASS: test_ppt_msr_selection.R\n")
