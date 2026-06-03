#
# @title Generate PPT automation
# @description Creates PPT summarizing Sigma scores and generating detail plots per Category2.

build_ppt_defaults <- function() {
    list(
        summary_rows_per_slide = 15L,
        detail_top_n = 8L,
        detail_grid_ncol = 4L,
        detail_grid_nrow = 2L,
        slide_width = 13.33,
        slide_height = 7.5,
        margin_top = 1.2,
        margin_left = 0.5,
        margin_right = 0.5,
        margin_bottom = 0.5,
        jitter_width = 0.2,
        jitter_alpha = 0.6,
        jitter_size = 1.5,
        mean_point_size = 3,
        title_size = 11,
        axis_x_angle = 30,
        axis_text_size = 10,
        axis_title_size = 9,
        plot_dpi = 150,
        color_palette = "Set1",
        up_color = "red",
        down_color = "blue",
        detail_plot_mode = "composite_v1",
        composite_row_heights = c(1.1, 0.75, 1.15),
        composite_bottom_split = c(1, 2),
        radius_scatter_alpha = 0.55,
        radius_scatter_size = 0.8,
        radius_ref_color = "#2d74b3",
        radius_tgt_color = "#de2d26",
        rootid_avg_point_size = 2.2,
        rootid_avg_line_alpha = 0.45,
        rootid_avg_axis_x_angle = 70,
        rootid_avg_axis_text_size = 6,
        rootid_avg_title_size = 8,
        cdf_ref_color = "#2d74b3",
        cdf_tgt_color = "#de2d26",
        cdf_line_size = 0.8,
        cdf_title_size = 8,
        wf_map_point_size = 3.2,
        wf_map_stroke = 0.2,
        wf_map_stroke_color = "#666666",
        wf_map_color_mode = "percentile",
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
        wf_map_axis_tick_linewidth = 0.15
    )
}

resolve_ppt_config <- function(ppt_config = NULL) {
    ppt_defaults <- build_ppt_defaults()
    ppt_cfg <- ppt_defaults

    if (!is.null(ppt_config)) {
        if (!is.list(ppt_config)) {
            stop("ppt_config must be a named list or NULL.")
        }
        if (length(ppt_config) > 0) {
            unknown_keys <- setdiff(names(ppt_config), names(ppt_defaults))
            if (length(unknown_keys) > 0) {
                log_msg(paste0(
                    "[Warning] Unknown PPT_CONFIG keys ignored: ",
                    paste(unknown_keys, collapse = ", ")
                ))
            }
            for (key in intersect(names(ppt_config), names(ppt_defaults))) {
                ppt_cfg[[key]] <- ppt_config[[key]]
            }
        }
    }

    ppt_cfg
}

sanitize_file_token <- function(x) {
    gsub("[^A-Za-z0-9_\\-]+", "_", as.character(x))
}

normalize_ratio_vector <- function(x, expected_len, default_vals) {
    vals <- suppressWarnings(as.numeric(x))
    if (length(vals) != expected_len || any(!is.finite(vals)) || any(vals <= 0)) {
        vals <- default_vals
    }
    vals / sum(vals)
}

normalize_group_vector <- function(x) {
    if (is.null(x) || length(x) == 0) {
        return(character())
    }
    out <- as.character(x)
    out <- out[!is.na(out) & nzchar(out)]
    unique(out)
}

resolve_plot_groups <- function(dt, final_ref = NULL, final_tgt = NULL) {
    if (!"GROUP" %in% names(dt)) {
        return(list(ref = character(), tgt = character()))
    }

    available_groups <- sort(unique(as.character(dt$GROUP)))
    ref_groups <- intersect(normalize_group_vector(final_ref), available_groups)
    tgt_groups <- intersect(normalize_group_vector(final_tgt), available_groups)

    if (length(ref_groups) == 0 && length(available_groups) > 0) {
        ref_groups <- available_groups[1]
    }

    if (length(tgt_groups) == 0) {
        remaining <- setdiff(available_groups, ref_groups)
        if (length(remaining) > 0) {
            tgt_groups <- remaining[1]
        }
    }

    list(ref = unique(ref_groups), tgt = unique(tgt_groups))
}

build_placeholder_plot <- function(title_text, body_text) {
    ggplot2::ggplot() +
        ggplot2::theme_void() +
        ggplot2::labs(title = title_text, subtitle = body_text) +
        ggplot2::theme(
            plot.title = ggplot2::element_text(size = 9, face = "bold", hjust = 0.5, color = "#555555"),
            plot.subtitle = ggplot2::element_text(size = 8, hjust = 0.5, color = "#777777")
        )
}

apply_compact_panel_theme <- function(p, show_title = TRUE, show_x_text = FALSE, keep_y_text = TRUE) {
    p + ggplot2::theme_light(base_size = 9) +
        ggplot2::theme(
            plot.title = if (show_title) {
                ggplot2::element_text(size = 6, face = "bold", hjust = 0.5)
            } else {
                ggplot2::element_blank()
            },
            axis.title.x = ggplot2::element_blank(),
            axis.title.y = ggplot2::element_blank(),
            axis.text.x = if (show_x_text) {
                ggplot2::element_text(size = 6)
            } else {
                ggplot2::element_blank()
            },
            axis.ticks.x = if (show_x_text) {
                ggplot2::element_line()
            } else {
                ggplot2::element_blank()
            },
            axis.text.y = if (keep_y_text) {
                ggplot2::element_text(size = 6)
            } else {
                ggplot2::element_blank()
            },
            axis.ticks.y = if (keep_y_text) {
                ggplot2::element_line(linewidth = 0.2)
            } else {
                ggplot2::element_blank()
            },
            legend.position = "none",
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major.x = ggplot2::element_blank()
        )
}

warn_missing_panel_columns <- function(panel_name, msr, missing_cols) {
    log_msg(paste0(
        "[Warning] ",
        panel_name,
        " panel skipped for MSR='",
        as.character(msr),
        "' (missing columns: ",
        paste(missing_cols, collapse = ", "),
        ")"
    ))
}

build_radius_scatter_combined_plot <- function(dt, msr, ref_groups, tgt_groups, ppt_cfg) {
    required_cols <- c("GROUP", "Radius", msr)
    missing_cols <- setdiff(required_cols, names(dt))
    if (length(missing_cols) > 0) {
        warn_missing_panel_columns("Top Radius Scatter", msr, missing_cols)
        return(build_placeholder_plot(
            "Top Radius Scatter",
            paste("Missing:", paste(missing_cols, collapse = ", "))
        ))
    }

    side_dt <- dt[GROUP %in% c(ref_groups, tgt_groups), .(GROUP, Radius, value = get(msr))]
    side_dt <- side_dt[is.finite(Radius) & is.finite(value)]
    side_dt[, Side := ifelse(GROUP %in% ref_groups, "REF", "TARGET")]
    side_dt[, Side := factor(Side, levels = c("REF", "TARGET"))]

    if (nrow(side_dt) == 0) {
        return(build_placeholder_plot(
            "Top Radius Scatter",
            "No finite Radius/MSR values"
        ))
    }
    if (data.table::uniqueN(side_dt$Side) < 2) {
        return(build_placeholder_plot(
            "Top Radius Scatter",
            "Insufficient data for REF/TARGET"
        ))
    }

    p <- ggplot2::ggplot(side_dt, ggplot2::aes(x = Radius, y = value, color = Side)) +
        ggplot2::geom_point(
            alpha = as.numeric(ppt_cfg$radius_scatter_alpha),
            size = as.numeric(ppt_cfg$radius_scatter_size)
        ) +
        ggplot2::labs(title = NULL, x = NULL, y = NULL) +
        ggplot2::facet_grid(. ~ Side, scales = "free_x", space = "free_x") +
        ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.04, 0.04))) +
        ggplot2::scale_color_manual(values = c(
            REF = as.character(ppt_cfg$radius_ref_color),
            TARGET = as.character(ppt_cfg$radius_tgt_color)
        ), guide = "none")

    # GROUP > Radius semantics: x domain repeats by side via shared-y faceting.
    apply_compact_panel_theme(p, show_title = FALSE, show_x_text = FALSE, keep_y_text = TRUE) +
        ggplot2::theme(
            strip.text = ggplot2::element_blank(),
            strip.background = ggplot2::element_blank(),
            panel.spacing.x = grid::unit(0, "pt"),
            panel.border = ggplot2::element_rect(color = "#CFCFCF", fill = NA, linewidth = 0.25)
        )
}

build_rootid_avg_combined_plot <- function(dt, msr, ref_groups, tgt_groups, ppt_cfg) {
    required_cols <- c("GROUP", "LOTID", "ROOTID", msr)
    missing_cols <- setdiff(required_cols, names(dt))
    if (length(missing_cols) > 0) {
        warn_missing_panel_columns("Mid ROOTID Avg", msr, missing_cols)
        return(build_placeholder_plot(
            "Mid ROOTID Avg",
            paste("Missing:", paste(missing_cols, collapse = ", "))
        ))
    }

    side_dt <- dt[GROUP %in% c(ref_groups, tgt_groups), .(GROUP, LOTID, ROOTID, value = get(msr))]
    side_dt <- side_dt[is.finite(value)]

    if (nrow(side_dt) == 0) {
        return(build_placeholder_plot(
            "Mid ROOTID Avg",
            "No finite MSR values"
        ))
    }
    if (data.table::uniqueN(side_dt$GROUP) < 2) {
        return(build_placeholder_plot(
            "Mid ROOTID Avg",
            "Insufficient data for REF/TARGET"
        ))
    }

    avg_dt <- side_dt[
        ,
        .(good_avg = mean(value, na.rm = TRUE)),
        by = .(GROUP, LOTID, ROOTID)
    ]
    avg_dt <- avg_dt[is.finite(good_avg)]

    if (nrow(avg_dt) == 0) {
        return(build_placeholder_plot(
            "Mid ROOTID Avg",
            "No finite averages"
        ))
    }

    group_order <- unique(c(as.character(ref_groups), as.character(tgt_groups)))
    avg_dt[, GROUP := factor(as.character(GROUP), levels = group_order)]
    data.table::setorderv(avg_dt, c("GROUP", "LOTID", "ROOTID"))
    avg_dt[, axis_label := paste(as.character(GROUP), LOTID, ROOTID, sep = " > ")]
    avg_dt[, axis_label := factor(axis_label, levels = unique(axis_label))]

    group_levels <- levels(avg_dt$GROUP)
    group_color_values <- stats::setNames(
        vapply(group_levels, function(g) {
            if (g %in% ref_groups) {
                as.character(ppt_cfg$radius_ref_color)
            } else {
                as.character(ppt_cfg$radius_tgt_color)
            }
        }, character(1)),
        group_levels
    )

    p <- ggplot2::ggplot(avg_dt, ggplot2::aes(x = axis_label, y = good_avg, color = GROUP)) +
        ggplot2::geom_point(size = as.numeric(ppt_cfg$rootid_avg_point_size)) +
        ggplot2::scale_x_discrete(drop = FALSE, expand = ggplot2::expansion(add = 0.8)) +
        ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.08, 0.08))) +
        ggplot2::labs(title = NULL, x = NULL, y = NULL) +
        ggplot2::scale_color_manual(values = group_color_values, guide = "none")

    apply_compact_panel_theme(p, show_title = FALSE, show_x_text = FALSE, keep_y_text = TRUE) +
        ggplot2::theme(
            panel.border = ggplot2::element_rect(color = "#CFCFCF", fill = NA, linewidth = 0.25),
            axis.text.y = ggplot2::element_text(size = 5.5),
            axis.title.y = ggplot2::element_blank()
        )
}

build_cdf_plot <- function(dt, msr, ref_groups, tgt_groups, ppt_cfg) {
    required_cols <- c("GROUP", msr)
    missing_cols <- setdiff(required_cols, names(dt))
    if (length(missing_cols) > 0) {
        warn_missing_panel_columns("Bottom CDF", msr, missing_cols)
        return(build_placeholder_plot(
            "CDF (REF vs TARGET)",
            paste("Missing:", paste(missing_cols, collapse = ", "))
        ))
    }

    side_dt <- dt[GROUP %in% c(ref_groups, tgt_groups), .(GROUP, value = get(msr))]
    side_dt <- side_dt[is.finite(value)]
    side_dt[, Side := ifelse(GROUP %in% ref_groups, "REF", "TARGET")]
    side_dt[, Side := factor(Side, levels = c("REF", "TARGET"))]

    if (nrow(side_dt) == 0 || data.table::uniqueN(side_dt$Side) < 2) {
        return(build_placeholder_plot(
            "CDF (REF vs TARGET)",
            "Insufficient finite data for both sides"
        ))
    }

    cdf_ref_col <- as.character(if (!is.null(ppt_cfg$radius_ref_color)) ppt_cfg$radius_ref_color else ppt_cfg$cdf_ref_color)
    cdf_tgt_col <- as.character(if (!is.null(ppt_cfg$radius_tgt_color)) ppt_cfg$radius_tgt_color else ppt_cfg$cdf_tgt_color)

    p <- ggplot2::ggplot(side_dt, ggplot2::aes(x = value, color = Side)) +
        ggplot2::stat_ecdf(linewidth = as.numeric(ppt_cfg$cdf_line_size)) +
        ggplot2::scale_color_manual(values = c(
            REF = cdf_ref_col,
            TARGET = cdf_tgt_col
        )) +
        ggplot2::labs(title = NULL, x = NULL, y = NULL)

    apply_compact_panel_theme(p, show_title = FALSE, show_x_text = FALSE, keep_y_text = TRUE)
}

build_wf_map_plot <- function(dt, msr, ref_groups, tgt_groups, ppt_cfg) {
    required_cols <- c("GROUP", "X", "Y", msr)
    missing_cols <- setdiff(required_cols, names(dt))
    if (length(missing_cols) > 0) {
        warn_missing_panel_columns("Bottom WF MAP", msr, missing_cols)
        return(build_placeholder_plot(
            "WF MAP (Chip Avg)",
            paste("Missing:", paste(missing_cols, collapse = ", "))
        ))
    }

    map_dt <- dt[GROUP %in% c(ref_groups, tgt_groups), .(GROUP, X, Y, value = get(msr))]
    map_dt <- map_dt[is.finite(X) & is.finite(Y) & is.finite(value)]
    map_dt[, Side := ifelse(GROUP %in% ref_groups, "REF", "TARGET")]
    map_dt <- map_dt[
        ,
        .(chip_avg = mean(value, na.rm = TRUE)),
        by = .(Side, X, Y)
    ]
    map_dt <- map_dt[is.finite(chip_avg)]
    map_dt[, Side := factor(Side, levels = c("REF", "TARGET"))]

    if (nrow(map_dt) == 0) {
        return(build_placeholder_plot(
            "WF MAP (Chip Avg)",
            "No finite X/Y/MSR data"
        ))
    }

    midpoint <- as.numeric(ppt_cfg$wf_map_midpoint)
    if (!is.finite(midpoint)) {
        midpoint <- stats::median(map_dt$chip_avg, na.rm = TRUE)
    }

    map_dt[, color_value := chip_avg]
    fill_scale <- ggplot2::scale_fill_gradient2(
        low = as.character(ppt_cfg$wf_map_low_color),
        mid = as.character(ppt_cfg$wf_map_mid_color),
        high = as.character(ppt_cfg$wf_map_high_color),
        midpoint = midpoint
    )

    color_mode <- tolower(as.character(ppt_cfg$wf_map_color_mode)[1])
    if (identical(color_mode, "percentile")) {
        probs <- suppressWarnings(as.numeric(ppt_cfg$wf_map_percentiles))
        colors <- as.character(ppt_cfg$wf_map_percentile_colors)

        if (length(probs) == length(colors) && length(probs) >= 2L && all(is.finite(probs))) {
            if (max(probs) > 1) {
                probs <- probs / 100
            }
            valid_probs <- probs >= 0 & probs <= 1
            probs <- probs[valid_probs]
            colors <- colors[valid_probs]

            if (length(probs) >= 2L) {
                order_idx <- order(probs)
                probs <- probs[order_idx]
                colors <- colors[order_idx]

                breaks <- stats::quantile(
                    map_dt$chip_avg,
                    probs = probs,
                    na.rm = TRUE,
                    names = FALSE,
                    type = 7
                )
                valid_breaks <- is.finite(breaks)
                breaks <- breaks[valid_breaks]
                colors <- colors[valid_breaks]

                unique_breaks <- !duplicated(breaks)
                breaks <- breaks[unique_breaks]
                colors <- colors[unique_breaks]

                if (length(breaks) >= 2L && diff(range(breaks)) > 0) {
                    lower_limit <- min(breaks)
                    upper_limit <- max(breaks)
                    scale_values <- (breaks - lower_limit) / (upper_limit - lower_limit)
                    map_dt[, color_value := pmin(pmax(chip_avg, lower_limit), upper_limit)]
                    fill_scale <- ggplot2::scale_fill_gradientn(
                        colors = colors,
                        values = scale_values,
                        limits = c(lower_limit, upper_limit)
                    )
                }
            }
        }
    }

    get_axis_step <- function(v) {
        v_num <- suppressWarnings(as.numeric(v))
        v_num <- v_num[is.finite(v_num)]
        if (length(v_num) < 2L) {
            return(1)
        }
        diffs <- diff(sort(unique(v_num)))
        diffs <- diffs[is.finite(diffs) & diffs > 0]
        if (length(diffs) == 0L) {
            return(1)
        }
        stats::median(diffs)
    }

    step_x <- get_axis_step(map_dt$X)
    step_y <- get_axis_step(map_dt$Y)

    ggplot2::ggplot(map_dt, ggplot2::aes(x = X, y = Y, fill = color_value)) +
        ggplot2::geom_tile(
            width = step_x,
            height = step_y,
            color = NA
        ) +
        fill_scale +
        ggplot2::scale_x_continuous(expand = ggplot2::expansion(add = step_x / 2)) +
        ggplot2::scale_y_reverse(expand = ggplot2::expansion(add = step_y / 2)) +
        ggplot2::coord_equal(expand = FALSE) +
        ggplot2::facet_wrap(~Side, nrow = 1, drop = FALSE) +
        ggplot2::labs(title = NULL, x = NULL, y = NULL, fill = NULL) +
        ggplot2::theme_light(base_size = 8) +
        ggplot2::theme(
            plot.title = ggplot2::element_blank(),
            strip.text = ggplot2::element_text(
                size = as.numeric(ppt_cfg$wf_map_strip_text_size),
                face = "plain",
                color = as.character(ppt_cfg$wf_map_strip_text_color)
            ),
            strip.background = ggplot2::element_blank(),
            axis.text.x = ggplot2::element_text(size = as.numeric(ppt_cfg$wf_map_axis_text_size), color = "#666666"),
            axis.ticks.x = ggplot2::element_line(linewidth = as.numeric(ppt_cfg$wf_map_axis_tick_linewidth), color = "#999999"),
            axis.text.y = ggplot2::element_text(size = as.numeric(ppt_cfg$wf_map_axis_text_size), color = "#666666"),
            axis.ticks.y = ggplot2::element_line(linewidth = as.numeric(ppt_cfg$wf_map_axis_tick_linewidth), color = "#999999"),
            axis.title = ggplot2::element_blank(),
            legend.position = "none",
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major = ggplot2::element_blank(),
            panel.spacing.x = grid::unit(as.numeric(ppt_cfg$wf_map_panel_spacing_pt), "pt"),
            panel.border = ggplot2::element_rect(color = "#CFCFCF", fill = NA, linewidth = 0.25),
            plot.margin = ggplot2::margin(t = 1, r = 1, b = 1, l = 1)
        )
}

build_legacy_scatter_plot <- function(dt, msr, title_text, ppt_cfg) {
    ggplot2::ggplot(dt, ggplot2::aes(x = GROUP, y = .data[[msr]])) +
        ggplot2::geom_jitter(
            ggplot2::aes(color = GROUP),
            width = as.numeric(ppt_cfg$jitter_width),
            alpha = as.numeric(ppt_cfg$jitter_alpha),
            size = as.numeric(ppt_cfg$jitter_size)
        ) +
        ggplot2::stat_summary(
            fun = mean,
            geom = "point",
            shape = 21,
            size = as.numeric(ppt_cfg$mean_point_size),
            fill = "black",
            color = "white",
            stroke = 1
        ) +
        ggplot2::labs(title = title_text, x = NULL, y = "Value") +
        ggplot2::scale_color_brewer(palette = as.character(ppt_cfg$color_palette)) +
        ggplot2::theme_light(base_size = 11) +
        ggplot2::theme(
            plot.title = ggplot2::element_text(size = as.numeric(ppt_cfg$title_size), face = "bold", color = "#333333", hjust = 0.5),
            axis.text.x = ggplot2::element_text(angle = as.numeric(ppt_cfg$axis_x_angle), hjust = 1, face = "bold", size = as.numeric(ppt_cfg$axis_text_size)),
            axis.title.y = ggplot2::element_text(size = as.numeric(ppt_cfg$axis_title_size), color = "#555555"),
            legend.position = "none",
            panel.grid.major.x = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(color = "#CCCCCC", fill = NA)
        )
}

save_composite_plot_png <- function(
    plot_top,
    plot_mid,
    plot_cdf,
    plot_map,
    png_path,
    width_in,
    height_in,
    dpi,
    row_heights,
    bottom_split
) {
    rh <- normalize_ratio_vector(row_heights, expected_len = 3, default_vals = c(1, 1, 1))
    bs <- normalize_ratio_vector(bottom_split, expected_len = 2, default_vals = c(1, 1))

    grDevices::png(
        filename = png_path,
        width = width_in,
        height = height_in,
        units = "in",
        res = dpi
    )
    on.exit(grDevices::dev.off(), add = TRUE)

    grid::grid.newpage()
    grid::pushViewport(grid::viewport(
        layout = grid::grid.layout(
            nrow = 3,
            ncol = 1,
            heights = grid::unit(rh, "null")
        )
    ))

    print(plot_top, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))

    print(plot_mid, vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1))

    grid::pushViewport(grid::viewport(
        layout.pos.row = 3,
        layout.pos.col = 1,
        layout = grid::grid.layout(1, 2, widths = grid::unit(bs, "null"))
    ))
    print(plot_cdf, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
    print(plot_map, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 2))
    grid::upViewport(2)
}

generate_composite_plot_png <- function(
    dt,
    msr,
    msr_title,
    ref_groups,
    tgt_groups,
    png_path,
    width_in,
    height_in,
    dpi,
    ppt_cfg
) {
    top_plot <- build_radius_scatter_combined_plot(dt, msr, ref_groups, tgt_groups, ppt_cfg)
    mid_plot <- build_rootid_avg_combined_plot(dt, msr, ref_groups, tgt_groups, ppt_cfg)
    cdf_plot <- build_cdf_plot(dt, msr, ref_groups, tgt_groups, ppt_cfg)
    map_plot <- build_wf_map_plot(dt, msr, ref_groups, tgt_groups, ppt_cfg)

    top_plot <- top_plot + ggplot2::labs(caption = NULL)

    save_composite_plot_png(
        plot_top = top_plot,
        plot_mid = mid_plot,
        plot_cdf = cdf_plot,
        plot_map = map_plot,
        png_path = png_path,
        width_in = width_in,
        height_in = height_in,
        dpi = dpi,
        row_heights = ppt_cfg$composite_row_heights,
        bottom_split = ppt_cfg$composite_bottom_split
    )
}

generate_sigma_ppt <- function(
    dt,
    result_dt,
    archive_dir,
    timestamp_str,
    final_ref = NULL,
    final_tgt = NULL,
    ppt_config = NULL
) {
    require(officer)
    require(flextable)
    require(ggplot2)
    require(data.table)

    log_msg("Generating PPT Automation...")
    ppt_cfg <- resolve_ppt_config(ppt_config = ppt_config)

    rows_per_slide <- max(1L, as.integer(ppt_cfg$summary_rows_per_slide))
    grid_ncol <- max(1L, as.integer(ppt_cfg$detail_grid_ncol))
    grid_nrow <- max(1L, as.integer(ppt_cfg$detail_grid_nrow))
    max_detail_slots <- max(1L, grid_ncol * grid_nrow)
    detail_top_n <- max(1L, as.integer(ppt_cfg$detail_top_n))
    detail_top_n <- min(detail_top_n, max_detail_slots)
    detail_plot_mode <- tolower(as.character(ppt_cfg$detail_plot_mode))
    if (!detail_plot_mode %in% c("composite_v1", "legacy_scatter")) {
        log_msg(paste0("[Warning] Unknown detail_plot_mode='", detail_plot_mode, "'. Fallback to composite_v1."))
        detail_plot_mode <- "composite_v1"
    }

    plot_groups <- resolve_plot_groups(dt, final_ref = final_ref, final_tgt = final_tgt)
    if (length(plot_groups$ref) == 0 || length(plot_groups$tgt) == 0) {
        log_msg("[Warning] Could not resolve both REF/TARGET groups for detail composite. Falling back to legacy scatter mode.")
        detail_plot_mode <- "legacy_scatter"
    }

    template_path <- here::here("data", "template_16_9.pptx")
    if (file.exists(template_path)) {
        ppt <- read_pptx(template_path)
    } else {
        ppt <- read_pptx()
    }

    # --------------- 1. Summary Slide ---------------
    if ("Category2" %in% names(result_dt) && "Category3" %in% names(result_dt)) {
        flagged_dt <- result_dt[Direction %in% c("Up", "Down")]
        flagged_dt <- flagged_dt[order(-Abs_Sigma_Score)]

        if (nrow(flagged_dt) > 0) {
            sum_disp <- flagged_dt[
                ,
                .(
                    Cat1 = Category1,
                    Cat2 = Category2,
                    Cat3 = Category3,
                    MSR = ITEM_NAME,
                    Score = round(Sigma_Score, 2),
                    Dir = Direction
                )
            ]

            num_slides <- ceiling(nrow(sum_disp) / rows_per_slide)

            for (i in seq_len(num_slides)) {
                start_row <- (i - 1L) * rows_per_slide + 1L
                end_row <- min(i * rows_per_slide, nrow(sum_disp))
                sub_sum <- sum_disp[start_row:end_row]

                ppt <- add_slide(ppt, layout = "Title and Content", master = "Office Theme")
                ppt <- ph_with(
                    ppt,
                    value = paste0("Flagged Items Summary (", i, "/", num_slides, ")"),
                    location = ph_location_type(type = "title")
                )

                ft <- flextable(sub_sum)
                ft <- theme_zebra(ft)
                ft <- flextable::bold(ft, part = "header")
                ft <- autofit(ft)
                ft <- flextable::align(ft, align = "center", part = "all")
                ft <- flextable::color(ft, i = ~ Dir == "Up", j = "Dir", color = as.character(ppt_cfg$up_color))
                ft <- flextable::color(ft, i = ~ Dir == "Down", j = "Dir", color = as.character(ppt_cfg$down_color))

                ppt <- ph_with(ppt, value = ft, location = ph_location_type(type = "body"))
            }
        } else {
            ppt <- add_slide(ppt, layout = "Title and Content", master = "Office Theme")
            ppt <- ph_with(ppt, value = "Sigma Score Summary", location = ph_location_type(type = "title"))
            ppt <- ph_with(ppt, value = "All perfectly stable. 0 items flagged.", location = ph_location_type(type = "body"))
        }
    } else {
        ppt <- add_slide(ppt, layout = "Title and Content", master = "Office Theme")
        ppt <- ph_with(ppt, value = "Sigma Score Summary By Category", location = ph_location_type(type = "title"))
        ppt <- ph_with(ppt, value = "No Category information found.", location = ph_location_type(type = "body"))
    }

    # --------------- 2. Detail Slides ---------------
    if ("Category2" %in% names(result_dt)) {
        cat2_list <- unique(result_dt[!is.na(Category2), Category2])

        slide_w <- as.numeric(ppt_cfg$slide_width)
        slide_h <- as.numeric(ppt_cfg$slide_height)
        margin_top <- as.numeric(ppt_cfg$margin_top)
        margin_left <- as.numeric(ppt_cfg$margin_left)
        margin_right <- as.numeric(ppt_cfg$margin_right)
        margin_bottom <- as.numeric(ppt_cfg$margin_bottom)
        plot_w <- (slide_w - margin_left - margin_right) / grid_ncol
        plot_h <- (slide_h - margin_top - margin_bottom) / grid_nrow

        temp_dir <- tempdir()

        for (c2 in cat2_list) {
            sub_dt <- result_dt[Category2 == c2]
            sub_dt <- sub_dt[order(-Abs_Sigma_Score)]
            top_msrs <- head(sub_dt$MSR, detail_top_n)
            top_msrs <- top_msrs[!is.na(top_msrs)]

            if (length(top_msrs) == 0) {
                next
            }

            ppt <- add_slide(ppt, layout = "Title Only", master = "Office Theme")
            ppt <- ph_with(
                ppt,
                value = paste("Category:", c2, "-", paste0("Top ", detail_top_n, " Sigma Delta")),
                location = ph_location_type(type = "title")
            )

            index <- 1L
            for (msr in top_msrs) {
                if (index > max_detail_slots) {
                    break
                }
                if (!msr %in% names(dt)) {
                    log_msg(paste0("[Warning] MSR column not found in raw dt; skipped: ", msr))
                    next
                }

                row_idx <- floor((index - 1L) / grid_ncol)
                col_idx <- (index - 1L) %% grid_ncol
                p_left <- margin_left + (col_idx * plot_w)
                p_top <- margin_top + (row_idx * plot_h)

                msr_name_title <- as.character(msr)
                if ("ITEM_NAME" %in% names(sub_dt)) {
                    item_name_i <- sub_dt[MSR == msr, ITEM_NAME][1]
                    if (!is.na(item_name_i) && nzchar(as.character(item_name_i))) {
                        msr_name_title <- as.character(item_name_i)
                    }
                }

                safe_msr <- sanitize_file_token(msr)
                png_path <- file.path(temp_dir, paste0("plot_", safe_msr, "_", index, ".png"))

                if (detail_plot_mode == "composite_v1") {
                    generate_composite_plot_png(
                        dt = dt,
                        msr = msr,
                        msr_title = msr_name_title,
                        ref_groups = plot_groups$ref,
                        tgt_groups = plot_groups$tgt,
                        png_path = png_path,
                        width_in = plot_w,
                        height_in = plot_h,
                        dpi = as.numeric(ppt_cfg$plot_dpi),
                        ppt_cfg = ppt_cfg
                    )
                } else {
                    legacy_plot <- build_legacy_scatter_plot(
                        dt = dt,
                        msr = msr,
                        title_text = msr_name_title,
                        ppt_cfg = ppt_cfg
                    )
                    ggplot2::ggsave(
                        png_path,
                        plot = legacy_plot,
                        width = plot_w,
                        height = plot_h,
                        units = "in",
                        dpi = as.numeric(ppt_cfg$plot_dpi)
                    )
                }

                ppt <- ph_with(
                    ppt,
                    external_img(png_path),
                    location = ph_location(left = p_left, top = p_top, width = plot_w, height = plot_h)
                )

                index <- index + 1L
            }
        }
    }

    # --------------- 3. Save ---------------
    ppt_name <- paste0("Sigma_Summary_", timestamp_str, ".pptx")
    archive_path <- file.path(archive_dir, ppt_name)
    print(ppt, target = archive_path)

    res_path <- here::here("output", "Sigma_Summary_Latest.pptx")
    print(ppt, target = res_path)

    log_msg("[PPT File] Saved Latest to: ./output/Sigma_Summary_Latest.pptx")
}

#' @title Finalize Outputs and Generate PPT
#' @description Save CSV artifacts, write runtime logs, and generate PPT summary.
finalize_outputs_and_generate_ppt <- function(
    result_dt,
    calc_res,
    dt,
    wf_counts,
    raw_filename,
    start_time,
    sigma_threshold,
    na_policy,
    final_ref,
    final_tgt,
    general_config_file_info,
    ppt_config_file_info,
    metric_params_file_info,
    metric_param_summary,
    metric_runtime_summary,
    metric_params_run,
    good_chip_rule_hot,
    good_chip_rule_cold,
    good_chip_limit_hot,
    good_chip_limit_cold,
    ppt_config_resolved
) {
    output_path <- here::here("output", "results.csv")
    data.table::fwrite(result_dt, output_path)

    timestamp_str <- format(Sys.time(), "%y%m%d_%H%M%S")
    archive_dir <- here::here("output", paste0("results_", timestamp_str))
    if (!dir.exists(archive_dir)) dir.create(archive_dir, recursive = TRUE)

    raw_base <- tools::file_path_sans_ext(raw_filename)
    archive_csv_name <- paste0("sigma_score_", raw_base, "_", timestamp_str, ".csv")
    archive_csv_path <- file.path(archive_dir, archive_csv_name)
    data.table::fwrite(result_dt, archive_csv_path)

    issue_report <- write_metric_issue_reports(calc_res$metric_issues, archive_dir, timestamp_str)
    log_msg(paste0("Metric issue report (Latest):  ./output/", basename(issue_report$latest_path)))
    log_msg(paste0("Metric issue report (History): ./output/", basename(archive_dir), "/", basename(issue_report$archive_path)))

    execution_time <- round(difftime(Sys.time(), start_time, units = "mins"), 2)
    wf_str <- paste(paste0("[", wf_counts$GROUP, ": ", wf_counts$N, " wfs]"), collapse = ", ")

    rule_hot_str <- if (is.function(good_chip_rule_hot)) {
        paste(deparse(body(good_chip_rule_hot)), collapse = " ")
    } else {
        "NULL"
    }
    rule_cold_str <- if (is.function(good_chip_rule_cold)) {
        paste(deparse(body(good_chip_rule_cold)), collapse = " ")
    } else {
        "NULL"
    }
    legacy_hot_str <- if (!is.null(good_chip_limit_hot)) {
        as.character(good_chip_limit_hot)
    } else {
        "NULL"
    }
    legacy_cold_str <- if (!is.null(good_chip_limit_cold)) {
        as.character(good_chip_limit_cold)
    } else {
        "NULL"
    }

    general_cfg_path_str <- if (isTRUE(general_config_file_info$loaded)) {
        as.character(general_config_file_info$path)
    } else if (!is.null(general_config_file_info$path)) {
        paste0("not found (", general_config_file_info$path, ")")
    } else {
        "(disabled)"
    }
    ppt_cfg_path_str <- if (isTRUE(ppt_config_file_info$loaded)) {
        as.character(ppt_config_file_info$path)
    } else if (!is.null(ppt_config_file_info$path)) {
        paste0("not found (", ppt_config_file_info$path, ")")
    } else {
        "(disabled)"
    }

    metric_param_lines <- build_metric_param_log_lines(
        metric_param_summary = metric_param_summary,
        metric_params_file_info = metric_params_file_info,
        run_params = metric_params_run
    )

    param_log_path <- file.path(archive_dir, paste0("parameters_", timestamp_str, ".txt"))
    runtime_lines <- "Metric Runtime Summary: (no metric runtime data)"
    if (!is.null(metric_runtime_summary) && nrow(metric_runtime_summary) > 0) {
        runtime_lines <- c(
            "Metric Runtime Summary:",
            vapply(seq_len(nrow(metric_runtime_summary)), function(i) {
                metric_name <- as.character(metric_runtime_summary$metric_name[i])
                elapsed_sec <- as.numeric(metric_runtime_summary$elapsed_sec[i])
                pair_count <- as.integer(metric_runtime_summary$pair_count[i])
                sprintf("  - %s: %.3f sec (pairs=%d)", metric_name, elapsed_sec, pair_count)
            }, character(1)),
            sprintf("Metric Runtime Total: %.3f sec", sum(metric_runtime_summary$elapsed_sec))
        )
    }

    param_content <- c(
        "=== Analysis Parameters ===",
        paste0("Date: ", timestamp_str),
        paste0("Raw File: ", raw_filename),
        paste0("Good Chip Rule (Hot): ", rule_hot_str),
        paste0("Good Chip Rule (Cold): ", rule_cold_str),
        paste0("Legacy Good Chip Limit (Hot): ", legacy_hot_str, " (used only when rule is NULL)"),
        paste0("Legacy Good Chip Limit (Cold): ", legacy_cold_str, " (used only when rule is NULL)"),
        paste0("NA Policy: ", na_policy),
        paste0("Sigma Threshold: ", sigma_threshold),
        paste0("Ref Group: ", paste(final_ref, collapse = ", ")),
        paste0("Target Group: ", paste(final_tgt, collapse = ", ")),
        paste0("WF Counts: ", wf_str),
        paste0("General Config: ", general_cfg_path_str),
        paste0("PPT Config: ", ppt_cfg_path_str),
        metric_param_lines,
        runtime_lines,
        paste0("Execution Time: ", execution_time, " mins"),
        "==========================="
    )
    writeLines(param_content, param_log_path)

    log_msg("Initiating PPT Generator...")
    tryCatch({
        generate_sigma_ppt(
            dt = dt,
            result_dt = result_dt,
            archive_dir = archive_dir,
            timestamp_str = timestamp_str,
            final_ref = final_ref,
            final_tgt = final_tgt,
            ppt_config = ppt_config_resolved
        )
    }, error = function(e_ppt) {
        log_msg(paste0("[Warning] PPT generation failed: ", e_ppt$message))
    })

    list(
        output_path = output_path,
        archive_dir = archive_dir,
        archive_csv_path = archive_csv_path,
        timestamp_str = timestamp_str,
        param_log_path = param_log_path,
        issue_report = issue_report
    )
}
