# PPT generation configuration
# Priority: run.R override > PPT_CONFIG > default

PPT_CONFIG <- list(
  # =========================
  # Frequently Edited
  # =========================
  summary_rows_per_slide = 15L,
  detail_top_n = 8L,                      # legacy; detail page size now uses grid_ncol * grid_nrow
  detail_group_by = "Category2",            # "Category1"..."Category5"
  detail_msr_selection_mode = "both",       # "required_only", "flagged_only", or "both"
  summary_msr_selection_mode = "both",      # "required_only", "flagged_only", or "both"
  summary_category_columns = c("Category1", "Category2", "Category3"),
  detail_grid_ncol = 4L,
  detail_grid_nrow = 2L,
  detail_plot_mode = "composite_v1", # "composite_v1" or "legacy_scatter"
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
  composite_row_heights = c(1.1, 0.75, 1.15), # top / mid / bottom
  composite_bottom_split = c(1, 2),         # bottom-left(CDF) / bottom-right(WF MAP)
  radius_scatter_alpha = 0.70,
  radius_scatter_size = 1.1,
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
  detail_label_font_size = 9,
  detail_header_font_size = 10,
  detail_label_up_color = "#D62728",
  detail_label_down_color = "#2CA02C",
  detail_label_neutral_color = "#8C8C8C",
  detail_label_text_color = "#333333",
  detail_header_row_fill = "#E0E0E0",
  detail_label_row_fill = "#F2F2F2",
  detail_table_border_color = "#D9D9D9",
  detail_table_border_width = 0.5
)
