# Test PPT detail plot layout stays inside the expanded detail content box.
source("src/03_create_ppt.R", local = environment())

tol <- 1e-8
cfg <- build_ppt_defaults()
layout <- calculate_detail_plot_layout(cfg, grid_ncol = 4L, grid_nrow = 2L)

stopifnot(cfg$slide_title == "[DM] DRB Statistical Auto Report")
stopifnot(cfg$ppt_font_family == "Malgun Gothic")
stopifnot(resolve_ppt_slide_title(cfg) == "[DM] DRB Statistical Auto Report")
stopifnot(resolve_ppt_slide_title(resolve_ppt_config(list(slide_title = "Custom Title"))) == "Custom Title")
stopifnot(resolve_ppt_slide_title(resolve_ppt_config(list(slide_title = ""))) == "[DM] DRB Statistical Auto Report")
stopifnot(cfg$slide_bullet_symbol == "\u25A0")
stopifnot(cfg$slide_max_bullets == 2L)
stopifnot(cfg$ppt_template_path == file.path("data", "template_16_9.pptx"))
stopifnot(cfg$ppt_layout_mode == "template")
stopifnot(cfg$detail_group_by == "Category2")
stopifnot(identical(cfg$summary_category_columns, c("Category1", "Category2", "Category3")))
stopifnot(is.null(cfg$ppt_category_scope))
stopifnot(identical(resolve_ppt_config()$ppt_category_scope, list()))
stopifnot(cfg$cover_slide_title == "DRB Automated Analysis Report")
stopifnot(cfg$toc_slide_title == "Contents")
stopifnot(cfg$toc_rows_per_slide == 16L)
stopifnot(cfg$toc_table_left == 3.05)
stopifnot(cfg$toc_table_width == 7.25)
stopifnot(cfg$toc_section_col_width == 3.75)
stopifnot(cfg$toc_leader_col_width == 2.65)
stopifnot(cfg$toc_page_col_width == 0.75)
stopifnot(cfg$toc_font_size == 11.5)
stopifnot(cfg$required_section_color == "#2F5597")
stopifnot(cfg$alarm_section_color == "#C62828")
stopifnot(cfg$ppt_master == "Office Theme")
stopifnot(cfg$summary_slide_layout == "Title and Content")
stopifnot(cfg$detail_slide_layout == "Title Only")
stopifnot(resolve_ppt_header_mode(resolve_ppt_config(list(ppt_layout_mode = "dev"))) == "dev_overlay")
stopifnot(cfg$slide_header_title_placeholder_type == "title")
stopifnot(cfg$slide_header_title_placeholder_label == "DRB_Title_Placeholder")
stopifnot(cfg$slide_header_bullet_placeholder_type == "body")
stopifnot(cfg$slide_header_bullet_placeholder_label == "DRB_Body_Placeholder")
stopifnot(isTRUE(cfg$slide_header_bullet_bold))
stopifnot(abs(cfg$slide_affiliation_left - 9.0420079) < tol)
stopifnot(abs(cfg$slide_affiliation_width - 2.7559055) < tol)
stopifnot(resolve_ppt_header_mode(resolve_ppt_config(list(ppt_layout_mode = "template"))) == "template_placeholder")
summary_bullets <- resolve_ppt_slide_bullets(
  cfg,
  "summary_slide_bullets",
  list(
    ref = "A",
    target = "B",
    sigma_threshold = 0.5,
    flagged_count = 3L,
    selected_count = 2L,
    summary_category_columns = "Category1 > Category2",
    summary_page = 1L,
    summary_total_pages = 1L
  )
)
stopifnot(length(summary_bullets) == 2L)
stopifnot(identical(
  summary_bullets,
  c(
    "REF: A / TARGET: B | Threshold: 0.5",
    "TREND: plot \uC218\uB3D9 \uBD80\uCC29 / \uBE44\uACE0: \uC218\uB3D9 \uC791\uC131"
  )
))
detail_bullets <- resolve_ppt_slide_bullets(
  cfg,
  "detail_slide_bullets",
  list(
    category = "PB",
    detail_selected_start = 1L,
    detail_selected_end = 8L,
    category_msr_count = 10L,
    sigma_threshold = 0.5,
    ref = "A",
    target = "B"
  )
)
stopifnot(identical(detail_bullets, c(
  "Category: PB | Showing MSR 1-8 of 10",
  "REF: A / TARGET: B | Threshold: 0.5"
)))
required_detail_value <- build_detail_section_bullet_value(
  ppt_cfg = cfg,
  category = "PB",
  section_status = "Required",
  start_index = 1L,
  end_index = 8L,
  total_count = 10L,
  ref = "A",
  target = "B",
  sigma_threshold = 0.5
)
alarm_detail_value <- build_detail_section_bullet_value(
  ppt_cfg = cfg,
  category = "PB",
  section_status = "Alarm",
  start_index = 9L,
  end_index = 10L,
  total_count = 10L,
  ref = "A",
  target = "B",
  sigma_threshold = 0.5
)
extract_fpar_text <- function(block) {
  paste(vapply(block$chunks, `[[`, character(1), "value"), collapse = "")
}
stopifnot(extract_fpar_text(required_detail_value[[1L]]) ==
  "■ Category: PB (Required) | Showing MSR 1-8 of 10")
stopifnot(extract_fpar_text(required_detail_value[[2L]]) ==
  "■ REF: A / TARGET: B | Threshold: 0.5")
stopifnot(required_detail_value[[1L]]$chunks[[3L]]$pr$color == cfg$required_section_color)
stopifnot(alarm_detail_value[[1L]]$chunks[[3L]]$pr$color == cfg$alarm_section_color)
stopifnot(all(vapply(
  required_detail_value[[1L]]$chunks[c(1L, 2L, 4L)],
  function(chunk) chunk$pr$color == cfg$slide_header_bullet_color,
  logical(1)
)))
goobae_bullets <- resolve_ppt_slide_bullets(
  cfg,
  "goobae_slide_bullets",
  list(
    ref = "A",
    target = "B",
    sigma_threshold = 0.5,
    goobae_group_count = 14L,
    goobae_selected_start = 1L,
    goobae_selected_end = 12L
  )
)
stopifnot(identical(goobae_bullets, c(
  "GOOBAE: WL trend | Showing 1-12 of 14",
  "REF: A / TARGET: B | Threshold: 0.5"
)))
stopifnot(isTRUE(cfg$goobae_slide_enabled))
stopifnot(cfg$goobae_slide_layout == "Title Only")
stopifnot(cfg$goobae_slots_per_slide == 12L)
stopifnot(cfg$detail_label_font_size == 9)
stopifnot(cfg$detail_header_font_size == 10)
stopifnot(isTRUE(cfg$detail_legend_show))
stopifnot(abs(cfg$detail_legend_top_offset - 0.05) < tol)
stopifnot(abs(cfg$detail_legend_height - 0.24) < tol)
stopifnot(cfg$detail_legend_font_size == 10)
stopifnot(cfg$detail_legend_gap_spaces == "    ")
stopifnot(cfg$detail_sigma_font_size == 8)
stopifnot(cfg$detail_sigma_color == "#808080")
stopifnot(abs(cfg$summary_header_bullet_top - 1.0314961) < tol)
stopifnot(abs(cfg$summary_header_bullet_height - 0.6377953) < tol)
stopifnot(abs(cfg$summary_header_bullet_font_size - 13) < tol)
summary_box <- calculate_summary_table_box(cfg)
stopifnot(abs(summary_box$left - 0.32) < tol)
stopifnot(abs(summary_box$top - 1.68) < tol)
stopifnot(abs(summary_box$width - 12.69) < tol)
stopifnot(abs(summary_box$height - 5.32) < tol)
stopifnot(abs(cfg$summary_trend_col_width - 3.80) < tol)
stopifnot(abs(cfg$summary_note_col_width - 2.44) < tol)
goobae_layout <- calculate_goobae_plot_layout(cfg)
stopifnot(abs(goobae_layout$left - 0.32) < tol)
stopifnot(abs(goobae_layout$top - 1.68) < tol)
stopifnot(abs(goobae_layout$right - 13.01) < tol)
stopifnot(abs(goobae_layout$bottom - 7.00) < tol)
stopifnot(abs(goobae_layout$width - 12.69) < tol)
stopifnot(abs(goobae_layout$height - 5.32) < tol)
stopifnot(goobae_layout$slots_per_slide == 12L)
stopifnot(goobae_layout$table_nrow == 3L)
stopifnot(abs(goobae_layout$slot_w - 1.0575) < tol)
stopifnot(abs(goobae_layout$category1_header_h - 0.32) < tol)
stopifnot(abs(goobae_layout$category2_header_h - 0.28) < tol)
stopifnot(abs(goobae_layout$plot_top - 2.28) < tol)
stopifnot(abs(goobae_layout$plot_w - 0.9575) < tol)
stopifnot(abs(goobae_layout$plot_h - 4.60) < tol)
goobae_positions <- lapply(seq_len(12L), function(index) {
  goobae_layout_for_index(goobae_layout, index)
})
goobae_plot_right_edge <- max(vapply(goobae_positions, function(pos) pos$plot_left + pos$plot_w, numeric(1)))
goobae_plot_bottom_edge <- max(vapply(goobae_positions, function(pos) pos$plot_top + pos$plot_h, numeric(1)))
stopifnot(goobae_plot_right_edge <= goobae_layout$right + tol)
stopifnot(goobae_plot_bottom_edge <= goobae_layout$bottom + tol)
stopifnot(abs(layout$left - 0.32) < tol)
stopifnot(abs(layout$top - 1.68) < tol)
stopifnot(abs(layout$right - 13.01) < tol)
stopifnot(abs(layout$bottom - 7.00) < tol)
stopifnot(abs(layout$width - 12.69) < tol)
stopifnot(abs(layout$height - 5.32) < tol)
stopifnot(layout$table_nrow == 5L)
stopifnot(abs(layout$cell_w - 3.1725) < tol)
stopifnot(abs(layout$cell_h - 2.50) < tol)
stopifnot(abs(layout$cell_padding - 0.04) < tol)
stopifnot(abs(layout$label_height - 0.25) < tol)
stopifnot(abs(layout$label_plot_gap - 0.03) < tol)
stopifnot(abs(layout$plot_top_inset - 0.03) < tol)
stopifnot(abs(layout$header_row_h - 0.32) < tol)
stopifnot(abs(layout$body_top - 2.00) < tol)
stopifnot(abs(layout$body_h - 5.00) < tol)
stopifnot(abs(layout$label_row_h - 0.28) < tol)
stopifnot(abs(layout$plot_row_h - 2.22) < tol)
stopifnot(abs(layout$plot_w - 3.0925) < tol)
stopifnot(abs(layout$plot_h - 2.15) < tol)

positions <- lapply(seq_len(8L), function(index) {
  detail_layout_for_index(layout, index)
})

cell_right_edge <- max(vapply(positions, function(pos) pos$cell_left + layout$cell_w, numeric(1)))
cell_bottom_edge <- max(vapply(positions, function(pos) pos$cell_top + layout$cell_h, numeric(1)))
stopifnot(abs(cell_right_edge - layout$right) < tol)
stopifnot(abs(cell_bottom_edge - layout$bottom) < tol)

plot_right_edge <- max(vapply(positions, function(pos) pos$plot_left + pos$plot_w, numeric(1)))
plot_bottom_edge <- max(vapply(positions, function(pos) pos$plot_top + pos$plot_h, numeric(1)))
stopifnot(plot_right_edge <= layout$right + tol)
stopifnot(plot_bottom_edge <= layout$bottom + tol)

stopifnot(abs(positions[[1L]]$label_row_top - layout$body_top) < tol)
stopifnot(abs(positions[[1L]]$plot_row_top - (layout$body_top + layout$label_row_h)) < tol)
stopifnot(abs(positions[[1L]]$label_top - (layout$body_top + ((layout$label_row_h - layout$label_height) / 2))) < tol)
stopifnot(abs(positions[[1L]]$plot_top - (positions[[1L]]$plot_row_top + layout$plot_top_inset)) < tol)

stopifnot(build_detail_label_text("ML_MSR_004", "Peri_PB_004", TRUE) == "\u2B24 (ML_MSR_004) Peri_PB_004")
stopifnot(build_detail_label_text("ML_MSR_004", "Peri_PB_004", FALSE) == "\u2B24 Peri_PB_004")
stopifnot(build_detail_label_text("ML_MSR_004", "", TRUE) == "\u2B24 (ML_MSR_004) ML_MSR_004")
stopifnot(format_detail_sigma_text(0.34) == "+0.3sig")
stopifnot(format_detail_sigma_text(-0.66) == "-0.7sig")
stopifnot(format_detail_sigma_text(NA_real_) == "")
stopifnot(build_detail_header_label("Category2: PB", 1L, 1L, 1L, 2L, 10L) == "Category2: PB - MSR 1-2 of 10")
stopifnot(build_detail_header_label("Category2: PB", 2L, 3L, 9L, 10L, 18L) == "Category2: PB - MSR 9-10 of 18 (2/3)")
stopifnot(resolve_detail_marker_color("Up", cfg) == "#D62728")
stopifnot(resolve_detail_marker_color("Down", cfg) == "#2CA02C")
stopifnot(resolve_detail_marker_color("Stable", cfg) == "#8C8C8C")

legend_dt <- data.table::data.table(
  GROUP = c("A", "A", "B", "B", "B"),
  ROOTID = c("WF001", "WF001", "WF002", "WF003", "WF003")
)
legend_groups <- list(ref = "A", tgt = "B")
legend_items <- build_detail_group_legend_items(legend_dt, legend_groups, cfg)
stopifnot(count_detail_group_wafers(legend_dt, "A") == 1L)
stopifnot(count_detail_group_wafers(legend_dt, "B") == 2L)
stopifnot(legend_items[[1L]]$label == "A (REF, 1\uB9E4)")
stopifnot(legend_items[[2L]]$label == "B (TARGET, 2\uB9E4)")
stopifnot(legend_items[[1L]]$color == cfg$radius_ref_color)
stopifnot(legend_items[[2L]]$color == cfg$radius_tgt_color)
stopifnot(estimate_detail_group_legend_width(legend_items, cfg$detail_legend_gap_spaces, 10, 12.69) < 12.69)

cat("PASS: test_ppt_detail_layout.R\n")
