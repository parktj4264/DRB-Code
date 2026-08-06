#' @title DRB GUI Quick Preview
#' @description Shared composite-plot preview helpers.

build_drb_preview_config <- function(
    show_mean = NULL,
    mean_label_size = NULL,
    radius_scatter_max_points_per_side = 2000L,
    trim_iqr = NULL,
    row_heights = NULL,
    bottom_split = NULL,
    ref_color = NULL,
    target_color = NULL,
    dpi = NULL,
    base_config = NULL
) {
    if (is.null(base_config)) {
        base_config <- list()
    }
    if (!is.list(base_config)) {
        stop("base_config must be a named list or NULL.")
    }
    overrides <- list()
    if (!is.null(show_mean)) overrides$radius_scatter_show_mean <- isTRUE(show_mean)
    if (!is.null(mean_label_size)) overrides$radius_mean_label_size <- as.numeric(mean_label_size)[1L]
    if (!is.null(radius_scatter_max_points_per_side)) {
        overrides$radius_scatter_max_points_per_side <- as.integer(radius_scatter_max_points_per_side)[1L]
    }
    if (!is.null(trim_iqr)) overrides$radius_scatter_trim_iqr <- trim_iqr
    if (!is.null(row_heights)) overrides$composite_row_heights <- as.numeric(row_heights)
    if (!is.null(bottom_split)) overrides$composite_bottom_split <- as.numeric(bottom_split)
    if (!is.null(ref_color)) {
        overrides$radius_ref_color <- as.character(ref_color)[1L]
        overrides$cdf_ref_color <- as.character(ref_color)[1L]
    }
    if (!is.null(target_color)) {
        overrides$radius_tgt_color <- as.character(target_color)[1L]
        overrides$cdf_tgt_color <- as.character(target_color)[1L]
    }
    if (!is.null(dpi)) {
        overrides$plot_dpi <- as.integer(dpi)
    }
    for (name in names(overrides)) {
        base_config[[name]] <- overrides[[name]]
    }
    resolve_ppt_config(base_config)
}

render_drb_quick_preview <- function(
    dt,
    msr,
    ref_groups,
    tgt_groups,
    ppt_cfg,
    png_path,
    width_in = NULL,
    height_in = NULL
) {
    dt <- data.table::as.data.table(dt)
    msr <- trimws(as.character(msr)[1L])
    ref_groups <- unique(trimws(as.character(ref_groups)))
    tgt_groups <- unique(trimws(as.character(tgt_groups)))
    ref_groups <- ref_groups[!is.na(ref_groups) & nzchar(ref_groups)]
    tgt_groups <- tgt_groups[!is.na(tgt_groups) & nzchar(tgt_groups)]

    if (!nzchar(msr) || !msr %in% names(dt)) {
        stop("Preview MSR was not found in the selected data: ", msr)
    }
    if (length(ref_groups) == 0L || length(tgt_groups) == 0L) {
        stop("Select at least one REF group and one TARGET group for Preview.")
    }
    overlap <- intersect(ref_groups, tgt_groups)
    if (length(overlap) > 0L) {
        stop("REF and TARGET groups must not overlap: ", paste(overlap, collapse = ", "))
    }

    selected_groups <- unique(c(ref_groups, tgt_groups))
    plot_columns <- intersect(
        unique(c("GROUP", "LOTID", "ROOTID", "Radius", "X", "Y", msr)),
        names(dt)
    )
    plot_dt <- dt[GROUP %in% selected_groups, ..plot_columns]
    missing_groups <- setdiff(selected_groups, unique(as.character(plot_dt$GROUP)))
    if (length(missing_groups) > 0L) {
        stop("Preview data does not contain group(s): ", paste(missing_groups, collapse = ", "))
    }

    if (is.null(width_in) || is.null(height_in)) {
        detail_layout <- calculate_detail_plot_layout(
            ppt_cfg,
            grid_ncol = as.integer(ppt_cfg$detail_grid_ncol),
            grid_nrow = as.integer(ppt_cfg$detail_grid_nrow)
        )
        width_in <- detail_layout$plot_w
        height_in <- detail_layout$plot_h
    }
    width_in <- as.numeric(width_in)[1L]
    height_in <- as.numeric(height_in)[1L]
    if (!is.finite(width_in) || width_in <= 0 || !is.finite(height_in) || height_in <= 0) {
        stop("Preview plot dimensions must be positive finite numbers.")
    }

    png_path <- normalizePath(png_path, winslash = "/", mustWork = FALSE)
    if (!dir.exists(dirname(png_path))) {
        dir.create(dirname(png_path), recursive = TRUE, showWarnings = FALSE)
    }

    generate_composite_plot_png(
        dt = plot_dt,
        msr = msr,
        msr_title = msr,
        ref_groups = ref_groups,
        tgt_groups = tgt_groups,
        png_path = png_path,
        width_in = width_in,
        height_in = height_in,
        dpi = as.integer(ppt_cfg$plot_dpi),
        ppt_cfg = ppt_cfg
    )

    list(
        path = png_path,
        msr = msr,
        rows = nrow(plot_dt),
        wafers = data.table::uniqueN(plot_dt$ROOTID),
        groups = selected_groups,
        width_in = width_in,
        height_in = height_in,
        dpi = as.integer(ppt_cfg$plot_dpi),
        row_heights = as.numeric(ppt_cfg$composite_row_heights),
        bottom_split = as.numeric(ppt_cfg$composite_bottom_split),
        show_mean = isTRUE(ppt_cfg$radius_scatter_show_mean),
        trim_iqr = ppt_cfg$radius_scatter_trim_iqr
    )
}
