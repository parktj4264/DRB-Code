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
stopifnot(identical(
  names(summary_display),
  c("Cat1", "Cat4", "Cat5", "Item", "REF", "TGT", "Delta", "Sigma Delta", "Result", "Note", "TREND")
))
stopifnot(identical(summary_display$Item, c("Flagged Only", "Required Flagged")))

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
  Mean_A = seq(10, 19),
  Mean_B = seq(11, 20),
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
  c("Category1", "Category2", "Category3"),
  ref_group = "A",
  target_group = "B"
)
stopifnot(identical(
  names(summary_candidate_display),
  c("Cat1", "Cat2", "Cat3", "Item", "REF", "TGT", "Delta", "Sigma Delta", "Result", "Note", "TREND")
))
stopifnot(identical(summary_candidate_display$Cat1, c("A", "A", "A", "A", "B")))
stopifnot(identical(summary_candidate_display$Cat2, c("A1", "A1", "A2", "A2", "B1")))
stopifnot(identical(summary_candidate_display$Item, c("Required Low", "Sigma Win", "Group Max", "Tie A", "B Required High")))
stopifnot(identical(summary_candidate_display$REF, c("10.00", "13.00", "17.00", "19.00", "15.00")))
stopifnot(identical(summary_candidate_display$TGT, c("11.00", "14.00", "18.00", "20.00", "16.00")))
stopifnot(identical(summary_candidate_display$Delta, rep("+1.00", 5L)))
stopifnot(identical(summary_candidate_display[["Sigma Delta"]], c("+0.2sig", "-2.2sig", "-0.4sig", "-1.5sig", "-1.6sig")))
stopifnot(identical(summary_candidate_display$Result, c("\u2B24 Stable", "\u2B24 Down", "\u2B24 Stable", "\u2B24 Down", "\u2B24 Down")))
stopifnot(all(summary_candidate_display$TREND == " "))
stopifnot(all(summary_candidate_display$Note == " "))
summary_ft <- style_summary_flextable(summary_candidate_display, build_ppt_defaults(), sigma_threshold = 1)
stopifnot(inherits(summary_ft, "flextable"))

goobae_raw_dt <- data.table::data.table(
  MSR = c("M1", "M2", "M3", "M4", "M5", "M6", "M7"),
  Direction = "Stable",
  Sigma_Score = 0,
  Abs_Sigma_Score = 0,
  SLIDE_REQUIRED_YN = "",
  SUMMARY_REQUIRED_YN = "",
  GOOBAE_Category1 = c("WLS", "WLS", "WLS", "WTC", "WTC", "", "WLS"),
  GOOBAE_Category2 = c("1WL", "1WL", "2WL", "1WL", "1WL", "", "1WL"),
  GOOBAE_NAME = c("WL001", "WL000", "WL000", "WL001", "WL000", "WL000", ""),
  GOOBAE_ORDER = c("2", "1", "1", "2", "1", "1", "3")
)
goobae_candidates <- select_goobae_candidate_dt(goobae_raw_dt)
stopifnot(identical(goobae_candidates$MSR, c("M2", "M1", "M3", "M5", "M4")))
stopifnot(identical(goobae_candidates$GOOBAE_NAME, c("WL000", "WL001", "WL000", "WL000", "WL001")))
stopifnot(identical(goobae_candidates$goobae_order, c(1, 2, 1, 1, 2)))

goobae_groups <- build_goobae_group_index(goobae_candidates)
stopifnot(identical(
  paste(goobae_groups$GOOBAE_Category1, goobae_groups$GOOBAE_Category2),
  c("WLS 1WL", "WLS 2WL", "WTC 1WL")
))
goobae_pages <- split_goobae_group_pages(goobae_groups, slots_per_slide = 2L)
stopifnot(length(goobae_pages) == 2L)
stopifnot(nrow(goobae_pages[[1L]]) == 2L)
stopifnot(nrow(goobae_pages[[2L]]) == 1L)

label_dt <- get_goobae_y_label_dt(goobae_candidates, data.table::as.data.table(goobae_pages[[1L]]))
stopifnot(identical(label_dt$GOOBAE_NAME, c("WL000", "WL001")))
stopifnot(identical(label_dt$goobae_order, c(1, 2)))
stopifnot(identical(get_goobae_y_limits(label_dt), c(0.5, 2.5)))
visible_label_dt <- select_goobae_visible_y_label_dt(label_dt, plot_height_in = 4.6, ppt_cfg = build_ppt_defaults())
stopifnot(identical(visible_label_dt, label_dt))

long_label_dt <- data.table::data.table(
  GOOBAE_NAME = sprintf("WL%03d", 0:299),
  goobae_order = seq_len(300L)
)
visible_long_label_dt <- select_goobae_visible_y_label_dt(
  long_label_dt,
  plot_height_in = 4.6,
  ppt_cfg = build_ppt_defaults()
)
stopifnot(nrow(visible_long_label_dt) < nrow(long_label_dt))
stopifnot(nrow(visible_long_label_dt) <= get_goobae_y_label_max_count(4.6, build_ppt_defaults()))
stopifnot(visible_long_label_dt$GOOBAE_NAME[[1L]] == "WL000")
stopifnot(visible_long_label_dt$GOOBAE_NAME[[nrow(visible_long_label_dt)]] == "WL299")
label_strip_plot <- build_goobae_y_label_strip_plot(
  visible_long_label_dt,
  get_goobae_y_limits(long_label_dt),
  build_ppt_defaults()
)
stopifnot(inherits(label_strip_plot, "ggplot"))
stopifnot(any(vapply(label_strip_plot$layers, function(layer) inherits(layer$geom, "GeomText"), logical(1))))

goobae_plot_raw_dt <- data.table::data.table(
  GROUP = c("A", "A", "B", "B"),
  M1 = c(10, 14, 30, 34),
  M2 = c(1, 3, 5, 7)
)
goobae_plot_dt <- build_goobae_plot_data(
  dt = goobae_plot_raw_dt,
  group_rows = get_goobae_group_rows(goobae_candidates, goobae_groups[1L]),
  ref_groups = "A",
  tgt_groups = "B"
)
goobae_expected <- data.table::data.table(
  Side = factor(c("REF", "TARGET", "REF", "TARGET"), levels = c("REF", "TARGET")),
  value = c(2, 6, 12, 32),
  GOOBAE_NAME = c("WL000", "WL000", "WL001", "WL001"),
  goobae_order = c(1, 1, 2, 2)
)
stopifnot(identical(goobae_plot_dt, goobae_expected))
goobae_plot <- build_goobae_trend_plot(goobae_plot_dt, get_goobae_y_limits(label_dt), build_ppt_defaults())
stopifnot(inherits(goobae_plot$layers[[1L]]$geom, "GeomPath"))
stopifnot(!any(vapply(goobae_plot$layers, function(layer) inherits(layer$geom, "GeomPoint"), logical(1))))
goobae_point_cfg <- build_ppt_defaults()
goobae_point_cfg$goobae_point_enabled <- TRUE
goobae_plot_with_points <- build_goobae_trend_plot(
  goobae_plot_dt,
  get_goobae_y_limits(label_dt),
  goobae_point_cfg
)
stopifnot(any(vapply(goobae_plot_with_points$layers, function(layer) inherits(layer$geom, "GeomPoint"), logical(1))))

cat("PASS: test_ppt_msr_selection.R\n")
