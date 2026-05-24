#' @title Generate PPT automation
#' @description Creates PPT summarizing Sigma scores and generating Top 8 scatter plots per Category2.

generate_sigma_ppt <- function(dt, result_dt, archive_dir, timestamp_str, ppt_config = NULL) {
    require(officer)
    require(flextable)
    require(ggplot2)
    require(data.table)

    log_msg("Generating PPT Automation...")

    ppt_defaults <- list(
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
        down_color = "blue"
    )

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

    rows_per_slide <- max(1L, as.integer(ppt_cfg$summary_rows_per_slide))
    grid_ncol <- max(1L, as.integer(ppt_cfg$detail_grid_ncol))
    grid_nrow <- max(1L, as.integer(ppt_cfg$detail_grid_nrow))
    max_detail_slots <- max(1L, grid_ncol * grid_nrow)
    detail_top_n <- max(1L, as.integer(ppt_cfg$detail_top_n))
    detail_top_n <- min(detail_top_n, max_detail_slots)

    # Create new blank regular PPT (16:9 template)
    template_path <- here::here("data", "template_16_9.pptx")
    if (file.exists(template_path)) {
        ppt <- read_pptx(template_path)
    } else {
        ppt <- read_pptx()
    }

    # --------------- 1. Summary Slide ---------------
    # Summary of flagged MSRs
    if ("Category2" %in% names(result_dt) && "Category3" %in% names(result_dt)) {
        flagged_dt <- result_dt[Direction %in% c("Up", "Down")]
        flagged_dt <- flagged_dt[order(-Abs_Sigma_Score)]
        
        if (nrow(flagged_dt) > 0) {
            # Format table data
            sum_disp <- flagged_dt[, .(Cat1=Category1, Cat2=Category2, Cat3=Category3,
                                       MSR=ITEM_NAME, Score=round(Sigma_Score, 2), Dir=Direction)]
            
            num_slides <- ceiling(nrow(sum_disp) / rows_per_slide)
            
            for (i in 1:num_slides) {
                start_row <- (i - 1) * rows_per_slide + 1
                end_row <- min(i * rows_per_slide, nrow(sum_disp))
                sub_sum <- sum_disp[start_row:end_row]
                
                ppt <- add_slide(ppt, layout = "Title and Content", master = "Office Theme")
                ppt <- ph_with(ppt, value = paste0("Flagged Items Summary (", i, "/", num_slides, ")"), location = ph_location_type(type = "title"))
                
                # Apply pretty flextable theme
                ft <- flextable(sub_sum)
                ft <- theme_zebra(ft)
                ft <- flextable::bold(ft, part = "header")
                ft <- autofit(ft)
                ft <- flextable::align(ft, align = "center", part = "all")
                
                # Highlight Up/Down items
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
    # For each category2
    if ("Category2" %in% names(result_dt)) {
        cat2_list <- unique(result_dt[!is.na(Category2), Category2])

        # Position definitions for configurable grid layout
        slide_w <- as.numeric(ppt_cfg$slide_width)
        slide_h <- as.numeric(ppt_cfg$slide_height)
        margin_top <- as.numeric(ppt_cfg$margin_top)
        margin_left <- as.numeric(ppt_cfg$margin_left)
        margin_right <- as.numeric(ppt_cfg$margin_right)
        margin_bottom <- as.numeric(ppt_cfg$margin_bottom)
        
        # Dimensions for grid
        plot_w <- (slide_w - margin_left - margin_right) / grid_ncol
        plot_h <- (slide_h - margin_top - margin_bottom) / grid_nrow

        # Pre-generate temp folder for PNGs
        temp_dir <- tempdir()
        
        for (c2 in cat2_list) {
            # filter and sort
            sub_dt <- result_dt[Category2 == c2]
            sub_dt <- sub_dt[order(-Abs_Sigma_Score)]
            
            # Select top N based on config
            top_msrs <- head(sub_dt$MSR, detail_top_n)
            
            if (length(top_msrs) == 0) next
            
            ppt <- add_slide(ppt, layout = "Title Only", master = "Office Theme")
            ppt <- ph_with(
                ppt,
                value = paste("Category:", c2, "-", paste0("Top ", detail_top_n, " Sigma Delta")),
                location = ph_location_type(type = "title")
            )

            index <- 1
            for (msr in top_msrs) {
                
                # Check if MSR exists in dt
                if (!msr %in% names(dt)) next
                
                # calculate grid position
                row_idx <- floor((index - 1) / grid_ncol)
                col_idx <- (index - 1) %% grid_ncol
                
                p_left <- margin_left + (col_idx * plot_w)
                p_top <- margin_top + (row_idx * plot_h)
                
                # Retrieve pretty name
                msr_name_title <- as.character(msr)
                if ("ITEM_NAME" %in% names(sub_dt)) {
                    msr_name_title <- sub_dt[MSR == msr, ITEM_NAME][1]
                }
                
                # create ggplot scatter plot (pretty design)
                p <- ggplot(dt, aes(x = .data[["GROUP"]], y = .data[[msr]])) +
                    geom_jitter(
                        aes(color = .data[["GROUP"]]),
                        width = as.numeric(ppt_cfg$jitter_width),
                        alpha = as.numeric(ppt_cfg$jitter_alpha),
                        size = as.numeric(ppt_cfg$jitter_size)
                    ) +
                    stat_summary(
                        fun = mean,
                        geom = "point",
                        shape = 21,
                        size = as.numeric(ppt_cfg$mean_point_size),
                        fill = "black",
                        color = "white",
                        stroke = 1
                    ) +
                    labs(title = msr_name_title, x = NULL, y = "Value") +
                    scale_color_brewer(palette = as.character(ppt_cfg$color_palette)) +
                    theme_light(base_size = 11) +
                    theme(plot.title = element_text(size=as.numeric(ppt_cfg$title_size), face="bold", color="#333333", hjust=0.5),
                          axis.text.x = element_text(angle=as.numeric(ppt_cfg$axis_x_angle), hjust=1, face="bold", size=as.numeric(ppt_cfg$axis_text_size)),
                          axis.title.y = element_text(size=as.numeric(ppt_cfg$axis_title_size), color="#555555"),
                          legend.position = "none",
                          panel.grid.major.x = element_blank(),
                          panel.border = element_rect(color = "#CCCCCC", fill = NA))
                
                png_path <- file.path(temp_dir, paste0("plot_", msr, "_", index,".png"))
                ggsave(
                    png_path,
                    plot = p,
                    width = plot_w,
                    height = plot_h,
                    units = "in",
                    dpi = as.numeric(ppt_cfg$plot_dpi)
                )
                
                # add to ppt
                ppt <- ph_with(ppt, external_img(png_path), 
                               location = ph_location(left = p_left, top = p_top, width = plot_w, height = plot_h))
                
                index <- index + 1
            }
        }
    }

    # --------------- 3. Save ---------------
    ppt_name <- paste0("Sigma_Summary_", timestamp_str, ".pptx")
    # Save to archive
    archive_path <- file.path(archive_dir, ppt_name)
    print(ppt, target = archive_path)
    
    # Save to output for easy access
    res_path <- here::here("output", "Sigma_Summary_Latest.pptx")
    print(ppt, target = res_path)

    log_msg(paste0("[PPT File] Saved Latest to: ./output/Sigma_Summary_Latest.pptx"))
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
        generate_sigma_ppt(dt, result_dt, archive_dir, timestamp_str, ppt_config = ppt_config_resolved)
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
