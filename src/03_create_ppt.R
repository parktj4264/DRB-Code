#' @title Generate PPT automation
#' @description Creates PPT summarizing Sigma scores and generating Top 8 scatter plots per Category2.

generate_sigma_ppt <- function(dt, result_dt, archive_dir, timestamp_str) {
    require(officer)
    require(flextable)
    require(ggplot2)
    require(data.table)

    log_msg("Generating PPT Automation...")

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
            
            # Use max 15 rows per slide
            rows_per_slide <- 15
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
                ft <- flextable::color(ft, i = ~ Dir == "Up", j = "Dir", color = "red")
                ft <- flextable::color(ft, i = ~ Dir == "Down", j = "Dir", color = "blue")
                
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

        # Position definitions for a 2x4 grid (assuming standard 16:9 13.33x7.5 inches)
        slide_w <- 13.33
        slide_h <- 7.5
        margin_top <- 1.2
        margin_left <- 0.5
        margin_right <- 0.5
        margin_bottom <- 0.5
        
        # Dimensions for grid
        plot_w <- (slide_w - margin_left - margin_right) / 4
        plot_h <- (slide_h - margin_top - margin_bottom) / 2

        # Pre-generate temp folder for PNGs
        temp_dir <- tempdir()
        
        for (c2 in cat2_list) {
            # filter and sort
            sub_dt <- result_dt[Category2 == c2]
            sub_dt <- sub_dt[order(-Abs_Sigma_Score)]
            
            # Select top 8
            top8_msrs <- head(sub_dt$MSR, 8)
            
            if (length(top8_msrs) == 0) next
            
            ppt <- add_slide(ppt, layout = "Title Only", master = "Office Theme")
            ppt <- ph_with(ppt, value = paste("Category:", c2, "- Top 8 Sigma Delta"), location = ph_location_type(type = "title"))

            index <- 1
            for (msr in top8_msrs) {
                
                # Check if MSR exists in dt
                if (!msr %in% names(dt)) next
                
                # calculate grid position
                row_idx <- floor((index - 1) / 4) # 0 or 1
                col_idx <- (index - 1) %% 4       # 0, 1, 2, 3
                
                p_left <- margin_left + (col_idx * plot_w)
                p_top <- margin_top + (row_idx * plot_h)
                
                # Retrieve pretty name
                msr_name_title <- as.character(msr)
                if ("ITEM_NAME" %in% names(sub_dt)) {
                    msr_name_title <- sub_dt[MSR == msr, ITEM_NAME][1]
                }
                
                # create ggplot scatter plot (pretty design)
                p <- ggplot(dt, aes(x = .data[["GROUP"]], y = .data[[msr]])) +
                    geom_jitter(aes(color = .data[["GROUP"]]), width = 0.2, alpha = 0.6, size = 1.5) +
                    stat_summary(fun = mean, geom = "point", shape = 21, size = 3, fill = "black", color = "white", stroke = 1) +
                    labs(title = msr_name_title, x = NULL, y = "Value") +
                    scale_color_brewer(palette = "Set1") +
                    theme_light(base_size = 11) +
                    theme(plot.title = element_text(size=11, face="bold", color="#333333", hjust=0.5),
                          axis.text.x = element_text(angle=30, hjust=1, face="bold", size=10),
                          axis.title.y = element_text(size=9, color="#555555"),
                          legend.position = "none",
                          panel.grid.major.x = element_blank(),
                          panel.border = element_rect(color = "#CCCCCC", fill = NA))
                
                png_path <- file.path(temp_dir, paste0("plot_", msr, "_", index,".png"))
                ggsave(png_path, plot = p, width = plot_w, height = plot_h, units = "in", dpi = 150)
                
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
