source("src/bootstrap/libs.R", local = environment())
source("src/bootstrap/utils.R", local = environment())
source("src/bootstrap/io_utils.R", local = environment())
source("src/03_create_ppt.R", local = environment())

raw_result_dt <- data.table::data.table(
  MSR = c(
    "A_G1_REQ_LOW", "A_G1_HIGH", "A_G1_REQ_HIGH",
    "A_G2_LOW", "A_G2_HIGH", "B_G1_HIGH", "A_G1_EQUAL", "A_G1_NA"
  ),
  ITEM_NAME = c(
    "A G1 Required Low", "A G1 High", "A G1 Required High",
    "A G2 Low", "A G2 High", "B G1 High", "A G1 Equal", "A G1 NA"
  ),
  Direction = c("Stable", "Up", "Down", "Stable", "Up", "Down", "Stable", "Stable"),
  Sigma_Score = c(0.5, 5, -2, 0.2, 4, -9, 1, NA_real_),
  Abs_Sigma_Score = c(0.5, 5, 2, 0.2, 4, 9, 1, NA_real_),
  Mean_REF = seq(10, 17),
  Mean_TGT = seq(11, 18),
  Category1 = c("A", "A", "A", "A", "A", "B", "A", "A"),
  Category2 = c("G1", "G1", "G1", "G2", "G2", "G1", "G1", "G1"),
  Category3 = "Leaf",
  SLIDE_REQUIRED_YN = c("Y", "", "Y", "Y", "", "Y", "", ""),
  SUMMARY_REQUIRED_YN = c("Y", "", "Y", "", "", "Y", "", "")
)

cfg <- resolve_ppt_config(list(
  ppt_category_scope = list(Category1 = "A", Category2 = c(" G1 ", "G2")),
  summary_category_columns = c("Category1", "Category2")
))
stopifnot(identical(cfg$ppt_category_scope, list(Category1 = "A", Category2 = c("G1", "G2"))))

plan <- build_ppt_workflow_plan(raw_result_dt, cfg, sigma_threshold = 1)
stopifnot(identical(plan$scoped_dt$MSR, raw_result_dt[Category1 == "A", MSR]))

# Required Summary keeps one representative per category combination. Required rows
# win first; the largest absolute Sigma wins among required rows. Without a
# required row, the category maximum is used.
stopifnot(identical(
  plan$main_summary_dt$MSR,
  c("A_G1_REQ_HIGH", "A_G2_HIGH")
))
stopifnot(identical(
  plan$main_summary_dt$Selected_By,
  c("Required + Sigma", "Sigma")
))
equal_threshold_summary <- select_main_summary_dt(
  raw_result_dt[MSR == "A_G1_EQUAL"],
  c("Category1", "Category2"),
  sigma_threshold = 1
)
stopifnot(equal_threshold_summary$Selected_By == "Group Max")

# Required detail is driven only by SLIDE_REQUIRED_YN.
stopifnot(identical(
  plan$main_detail_dt$MSR,
  c("A_G1_REQ_HIGH", "A_G1_REQ_LOW", "A_G2_LOW")
))

# Alarm Summary keeps every strictly over-threshold MSR in scope and orders
# within each category by absolute Sigma. Alarm detail intentionally includes
# Required detail rows when they are also Sigma flagged.
stopifnot(identical(
  plan$suggested_summary_dt$MSR,
  c("A_G1_HIGH", "A_G1_REQ_HIGH", "A_G2_HIGH")
))
stopifnot(identical(
  plan$suggested_detail_dt$MSR,
  c("A_G1_HIGH", "A_G2_HIGH", "A_G1_REQ_HIGH")
))
stopifnot("A_G1_REQ_HIGH" %in% plan$main_detail_dt$MSR)
stopifnot("A_G1_REQ_HIGH" %in% plan$suggested_detail_dt$MSR)
stopifnot(!"B_G1_HIGH" %in% unlist(lapply(plan[c(
  "main_summary_dt", "main_detail_dt", "suggested_summary_dt", "suggested_detail_dt"
)], function(x) x$MSR), use.names = FALSE))

suggested_display <- build_summary_display_dt(
  plan$suggested_summary_dt,
  cfg$summary_category_columns,
  ref_group = "REF",
  target_group = "TGT",
  show_main_status = TRUE
)
status_by_item <- stats::setNames(suggested_display$Note, suggested_display$Item)
stopifnot(status_by_item[["A G1 Required High"]] == "Required 요약+상세")
stopifnot(status_by_item[["A G1 High"]] == " ")
stopifnot(status_by_item[["A G2 High"]] == "Required 요약")

no_required_dt <- data.table::copy(raw_result_dt)
no_required_dt[, `:=`(SLIDE_REQUIRED_YN = "", SUMMARY_REQUIRED_YN = "")]
no_required_plan <- build_ppt_workflow_plan(no_required_dt, cfg, sigma_threshold = 1)
stopifnot(nrow(no_required_plan$main_detail_dt) == 0L)
stopifnot(identical(
  no_required_plan$main_summary_dt$MSR,
  c("A_G1_HIGH", "A_G2_HIGH")
))

empty_scope_cfg <- cfg
empty_scope_cfg$ppt_category_scope <- list(Category1 = "NOT_FOUND")
empty_scope_plan <- suppressWarnings(build_ppt_workflow_plan(
  raw_result_dt,
  empty_scope_cfg,
  sigma_threshold = 1
))
stopifnot(nrow(empty_scope_plan$scoped_dt) == 0L)
stopifnot(nrow(empty_scope_plan$main_summary_dt) == 0L)
stopifnot(nrow(empty_scope_plan$suggested_summary_dt) == 0L)

# Required Summary is always a single slide, even beyond the ordinary
# per-slide row limit. Alarm-all keeps ordinary pagination.
required_16 <- data.table::data.table(row_id = seq_len(16L))
required_pages <- build_summary_section_pages(required_16, "required", cfg)
stopifnot(length(required_pages) == 1L)
stopifnot(nrow(required_pages[[1L]]$data) == 16L)
stopifnot(required_pages[[1L]]$section_title == "Summary (Required)")

alarm_31 <- data.table::data.table(row_id = seq_len(31L))
alarm_pages <- build_summary_section_pages(alarm_31, "alarm", cfg)
stopifnot(length(alarm_pages) == 3L)
stopifnot(identical(
  vapply(alarm_pages, function(page) nrow(page$data), integer(1)),
  c(15L, 15L, 1L)
))
stopifnot(all(vapply(
  alarm_pages,
  function(page) page$section_title == "Summary (Alarm-all)",
  logical(1)
)))

# The integrated slide plan is the single source of truth for cover, TOC, and
# exact page numbers. This fixture has no GOOBAE rows and one page per detail
# category/status combination.
slide_plan <- build_integrated_ppt_slide_plan(plan, cfg)
stopifnot(slide_plan$cover$page_no == 1L)
stopifnot(length(slide_plan$toc_pages) == 1L)
stopifnot(slide_plan$total_slides == 8L)
stopifnot(identical(
  slide_plan$toc_entries$label,
  c(
    "Summary (Required)", "Summary (Alarm-all)",
    "G1 (Required)", "G1 (Alarm)",
    "G2 (Required)", "G2 (Alarm)"
  )
))
stopifnot(identical(slide_plan$toc_entries$page_text, as.character(3:8)))
stopifnot(identical(
  slide_plan$category_counts,
  data.table::data.table(
    Category = c("G1", "G2"),
    Required = c(2L, 1L),
    Alarm = c(2L, 1L)
  )
))

# A category keeps its Required/Alarm pair even when one side has zero MSRs.
one_sided_plan_input <- plan
one_sided_plan_input$main_detail_dt <- plan$main_detail_dt[Category2 == "G1"]
one_sided_slide_plan <- build_integrated_ppt_slide_plan(one_sided_plan_input, cfg)
one_sided_detail_pages <- Filter(
  function(page) page$kind == "detail",
  one_sided_slide_plan$content_pages
)
stopifnot(identical(
  vapply(one_sided_detail_pages, `[[`, character(1), "toc_label"),
  c("G1 (Required)", "G1 (Alarm)", "G2 (Required)", "G2 (Alarm)")
))
g2_required_page <- Filter(
  function(page) page$toc_label == "G2 (Required)",
  one_sided_detail_pages
)[[1L]]
stopifnot(g2_required_page$total_count == 0L)
stopifnot(g2_required_page$start_index == 0L)
stopifnot(g2_required_page$end_index == 0L)
stopifnot(nrow(g2_required_page$data) == 0L)
stopifnot(one_sided_slide_plan$category_counts[Category == "G2", Required] == 0L)
stopifnot(one_sided_slide_plan$category_counts[Category == "G2", Alarm] == 1L)

# Alarm uses the threshold itself, not a pre-existing Direction value: equality
# and non-finite scores are excluded even when Direction says otherwise.
threshold_contract_dt <- data.table::data.table(
  MSR = c("ABOVE", "EQUAL", "NA_SCORE"),
  Sigma_Score = c(1.0001, 1, NA_real_),
  Abs_Sigma_Score = c(1.0001, 1, NA_real_),
  Direction = c("Stable", "Up", "Down")
)
threshold_contract <- prepare_ppt_result_dt(threshold_contract_dt, sigma_threshold = 1)
stopifnot(identical(threshold_contract$ppt_flagged, c(TRUE, FALSE, FALSE)))

invalid_scope_error <- tryCatch(
  {
    resolve_ppt_config(list(ppt_category_scope = list(BadCategory = "A")))
    NULL
  },
  error = identity
)
stopifnot(inherits(invalid_scope_error, "error"))

empty_scope_value_error <- tryCatch(
  {
    resolve_ppt_config(list(ppt_category_scope = list(Category1 = character())))
    NULL
  },
  error = identity
)
stopifnot(inherits(empty_scope_value_error, "error"))

pagination_fixture <- data.table::data.table(row_id = seq_len(31L))
pages <- paginate_ppt_rows(pagination_fixture, 15L)
stopifnot(length(pages) == 3L)
stopifnot(identical(unname(vapply(pages, nrow, integer(1))), c(15L, 15L, 1L)))
stopifnot(identical(unname(unlist(lapply(pages, `[[`, "row_id"))), seq_len(31L)))
stopifnot(length(paginate_ppt_rows(pagination_fixture[0], 15L)) == 0L)

cat("PASS: test_ppt_workflow_partition.R\n")
