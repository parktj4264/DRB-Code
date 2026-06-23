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

summary_raw_dt <- data.table::data.table(
  MSR = c(
    "REQ_ONLY_LOW",
    "NONREQ_HIGH_SAME_GROUP",
    "SIGMA_LOSE",
    "SIGMA_WIN",
    "B_REQ_LOW",
    "B_REQ_HIGH",
    "GROUP_LOW",
    "GROUP_MAX",
    "TIE_B",
    "TIE_A"
  ),
  ITEM_NAME = c(
    "Required Low",
    "Non Required High",
    "Sigma Lose",
    "Sigma Win",
    "B Required Low",
    "B Required High",
    "Group Low",
    "Group Max",
    "Tie B",
    "Tie A"
  ),
  Direction = c("Stable", "Up", "Up", "Down", "Stable", "Down", "Stable", "Stable", "Up", "Down"),
  Sigma_Score = c(0.2, 5.0, 1.1, -2.2, 0.4, -1.6, 0.2, -0.4, 1.5, -1.5),
  Abs_Sigma_Score = c(0.2, 5.0, 1.1, 2.2, 0.4, 1.6, 0.2, 0.4, 1.5, 1.5),
  Category1 = c("A", "A", "A", "A", "B", "B", "A", "A", "A", "A"),
  Category2 = c("A1", "A1", "A1", "A1", "B1", "B1", "A2", "A2", "A2", "A2"),
  Category3 = c("G1", "G1", "G2", "G2", "G1", "G1", "G1", "G1", "G2", "G2"),
  SLIDE_REQUIRED_YN = "",
  SUMMARY_REQUIRED_YN = c("Y", "", "", "", "Y", "Y", "", "", "", "")
)

summary_candidates <- select_summary_candidate_dt(
  summary_raw_dt,
  c("Category1", "Category2", "Category3"),
  sigma_threshold = 1
)
summary_group_count <- data.table::uniqueN(summary_raw_dt[, .(Category1, Category2, Category3)])
stopifnot(nrow(summary_candidates) == summary_group_count)
stopifnot(identical(
  summary_candidates$MSR,
  c("REQ_ONLY_LOW", "SIGMA_WIN", "GROUP_MAX", "TIE_A", "B_REQ_HIGH")
))
stopifnot(identical(
  summary_candidates$Selected_By,
  c("Required", "Sigma", "Group Max", "Sigma", "Required + Sigma")
))
stopifnot(setequal(
  unique(summary_candidates$Selected_By),
  c("Required", "Required + Sigma", "Sigma", "Group Max")
))

summary_candidate_display <- build_summary_display_dt(
  summary_candidates,
  c("Category1", "Category2", "Category3")
)
stopifnot(identical(
  names(summary_candidate_display),
  c("Cat1", "Cat2", "Cat3", "MSR", "Score", "Dir", "Selected_By")
))
stopifnot(identical(summary_candidate_display$Cat1, c("A", "A", "A", "A", "B")))
stopifnot(identical(summary_candidate_display$Cat2, c("A1", "A1", "A2", "A2", "B1")))
summary_ft <- style_summary_flextable(summary_candidate_display, build_ppt_defaults(), sigma_threshold = 1)
stopifnot(inherits(summary_ft, "flextable"))

cat("PASS: test_ppt_msr_selection.R\n")
