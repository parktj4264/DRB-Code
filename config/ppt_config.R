# PPT generation configuration
# Priority: run.R override > PPT_CONFIG > default

PPT_CONFIG <- list(
  # =========================
  # Frequently Edited
  # =========================
  summary_rows_per_slide = 15L,
  detail_top_n = 8L,
  detail_grid_ncol = 4L,
  detail_grid_nrow = 2L,
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

  # =========================
  # Layout
  # =========================
  slide_width = 13.33,
  slide_height = 7.5,
  margin_top = 1.2,
  margin_left = 0.5,
  margin_right = 0.5,
  margin_bottom = 0.5
)
