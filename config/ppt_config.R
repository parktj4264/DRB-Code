# PPT generation configuration
# Priority: run.R override > PPT_CONFIG > default

PPT_CONFIG <- list(
  # =========================
  # Frequently Edited
  # =========================
  summary_rows_per_slide = 15L,
  ppt_font_family = "Malgun Gothic",
  detail_top_n = 8L,                      # legacy; detail page size now uses grid_ncol * grid_nrow
  detail_group_by = "Category2",            # "Category1"..."Category5"
  detail_msr_selection_mode = "both",       # "required_only", "flagged_only", or "both"
  summary_msr_selection_mode = "both",      # legacy; redesigned summary ignores this mode
  summary_category_columns = c("Category1", "Category2", "Category3"), # summary grouping/display hierarchy
  summary_font_size = 8,
  summary_header_fill = "#4D4D4D",
  summary_header_color = "#FFFFFF",
  summary_border_color = "#CCCCCC",
  summary_highlight_fill = "#FFEBEE",
  summary_highlight_color = "#C62828",
  summary_category_fill = "#F2F2F2",
  summary_category_color = "#243B53",
  summary_reason_fill = "#F7F7F7",
  summary_reason_color = "#333333",
  summary_header_bullet_top = 0.76,
  summary_header_bullet_height = 0.24,
  summary_header_bullet_font_size = 9.5,
  summary_msr_col_width = 2.6,
  summary_selected_by_col_width = 0.9,
  summary_category_col_width = 0.55,
  summary_item_col_width = 1.70,
  summary_value_col_width = 0.55,
  summary_diff_col_width = 0.65,
  summary_result_col_width = 0.70,
  summary_trend_col_width = 3.80,
  summary_note_col_width = 2.44,
  summary_table_left = 0.32,
  summary_table_top = 1.18,
  summary_table_width = 12.69,
  summary_table_height = 5.82,
  goobae_slide_enabled = TRUE,
  goobae_slide_layout = "Title Only",
  goobae_slide_bullets = c(
    "GOOBAE: WL trend by REF/TARGET",
    "REF: {ref} / TARGET: {target}",
    "Showing GOOBAE {goobae_selected_start}-{goobae_selected_end} of {goobae_group_count}"
  ),
  goobae_slots_per_slide = 12L,
  goobae_category1_header_height = 0.32,
  goobae_category2_header_height = 0.28,
  goobae_plot_padding_x = 0.05,
  goobae_plot_padding_y = 0.06,
  goobae_y_label_width = 0.34,
  goobae_y_label_gap = 0.02,
  goobae_y_label_font_size = 4.0,
  goobae_y_label_font_face = "bold",
  goobae_y_label_dpi = 600L,
  goobae_y_label_min_gap = 0.18,
  goobae_header_font_size = 8.5,
  goobae_axis_text_size = 4.8,
  goobae_point_enabled = FALSE,
  goobae_point_size = 1.2,
  goobae_line_size = 0.70,
  detail_grid_ncol = 4L,
  detail_grid_nrow = 2L,
  detail_plot_mode = "composite_v1", # "composite_v1" or "legacy_scatter"
  detail_progress_log_every = 0L,    # 0: slide-start logs only; N>0: also log every N completed MSRs
  up_color = "red",
  down_color = "blue",

  # =========================
  # Plot Look
  # =========================
  color_palette = "Set1",
  jitter_width = 0.2,
  jitter_alpha = 0.6,
  jitter_size = 1.5,
  mean_point_size = 3,
  title_size = 11,
  axis_x_angle = 30,
  axis_text_size = 10,
  axis_title_size = 9,
  plot_dpi = 150,
  composite_row_heights = c(0.95, 0.65, 1.40), # top / mid / bottom; WFMAP gets the remaining height
  composite_bottom_split = c(1.15, 1.85),      # larger CDF; two square WFMAP panels fit with minimal center gap
  radius_scatter_alpha = 0.70,
  radius_scatter_size = 1.1,
  radius_scatter_max_points_per_side = 2000L, # deterministic visual thinning; statistics still use all rows
  radius_scatter_border_color = "#666666",
  radius_scatter_border_alpha = 0.45,
  radius_scatter_border_width = 0.05,
  radius_ref_color = "#6489FA",
  radius_tgt_color = "#FA7864",
  rootid_avg_point_size = 2.2,
  rootid_avg_point_border_color = "#666666",
  rootid_avg_point_border_alpha = 0.80,
  rootid_avg_point_border_width = 0.30,
  rootid_avg_line_alpha = 0.45,
  rootid_avg_y_expand_mult = 0.16,
  rootid_avg_axis_x_angle = 70,
  rootid_avg_axis_text_size = 6,
  rootid_avg_title_size = 8,
  cdf_ref_color = "#6489FA",
  cdf_tgt_color = "#FA7864",
  cdf_line_size = 0.8,
  cdf_title_size = 8,
  cdf_max_points_per_side = 1000L,            # exact-rank knots for faster small-panel rendering
  wf_map_point_size = 3.2,
  wf_map_stroke = 0.2,
  wf_map_stroke_color = "#666666",
  wf_map_color_mode = "percentile", # "percentile" or "legacy_gradient"
  wf_map_percentiles = c(0, 0.25, 0.50, 0.75, 0.99),
  wf_map_percentile_colors = c("#1B9E4B", "#4EA3D8", "#fed339", "#F28E2B", "#D62728"),
  wf_map_low_color = "#2166AC",
  wf_map_mid_color = "#F7F7F7",
  wf_map_high_color = "#B2182B",
  wf_map_midpoint = NA_real_,
  wf_map_coordinate_mode = "wafer_grid", # normalize origin/scale/gaps per wafer; "physical" preserves raw distances
  wf_map_panel_arrangement = "auto",      # choose horizontal/vertical REF-TARGET layout for the largest maps
  wf_map_force_square_display = TRUE,     # keep wafer-grid maps square across data/device/ggplot2 environments
  wf_map_show_axes = FALSE,               # compact panels use all available area for the wafer
  wf_map_missing_fill = NA_character_,        # missing cells stay transparent
  wf_map_constant_fill = "#4EA3D8",
  wf_map_outline_color = NA_character_,       # no gray chip grid
  wf_map_value_cache_max_cells = 5000000L,    # cap transient cache size on very large company data
  wf_map_title_size = 6,
  wf_map_strip_text_size = 3.8,
  wf_map_strip_text_color = "#666666",
  wf_map_panel_spacing_pt = 0,
  wf_map_axis_text_size = 4.5,
  wf_map_axis_tick_linewidth = 0.15,

  # =========================
  # Layout
  # =========================
  slide_width = 13.33,
  slide_height = 7.5,
  margin_top = 1.68,
  margin_left = 0.32,
  margin_right = 0.32,
  margin_bottom = 0.50,
  detail_plot_gap = 0.08,
  detail_label_show_field = TRUE,
  detail_label_height = 0.25,
  detail_cell_padding = 0.04,
  detail_label_plot_gap = 0.03,
  detail_plot_top_inset = 0.03,
  detail_label_font_size = 9,
  detail_header_font_size = 10,
  detail_label_up_color = "#D62728",
  detail_label_down_color = "#2CA02C",
  detail_label_neutral_color = "#8C8C8C",
  detail_label_text_color = "#333333",
  detail_header_row_fill = "#E0E0E0",
  detail_label_row_fill = "#F2F2F2",
  detail_table_border_color = "#D9D9D9",
  detail_table_border_width = 0.5,
  detail_sigma_font_size = 8,
  detail_sigma_color = "#808080"
)
