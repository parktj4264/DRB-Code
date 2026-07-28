#
# @title Generate PPT automation
# @description Creates PPT summarizing Sigma scores and generating selected detail plots by configured category.

source(here::here("src", "bootstrap", "ppt_defaults.R"), local = environment())

ppt_log_warning <- function(message) {
    if (exists("log_msg", mode = "function")) {
        log_msg(message)
    } else {
        warning(message, call. = FALSE)
    }
}

get_ppt_category_columns <- function() {
    paste0("Category", seq_len(5L))
}

normalize_ppt_selection_mode <- function(value, key_name) {
    mode <- tolower(trimws(as.character(value)[1]))
    valid_modes <- c("required_only", "flagged_only", "both")
    if (is.na(mode) || !mode %in% valid_modes) {
        ppt_log_warning(paste0(
            "[Warning] Invalid ", key_name, "='", as.character(value)[1],
            "'. Fallback to both."
        ))
        return("both")
    }
    mode
}

normalize_ppt_category_column <- function(value, default_value = "Category2", key_name = "detail_group_by") {
    category_col <- trimws(as.character(value)[1])
    valid_cols <- get_ppt_category_columns()
    if (is.na(category_col) || !category_col %in% valid_cols) {
        ppt_log_warning(paste0(
            "[Warning] Invalid ", key_name, "='", as.character(value)[1],
            "'. Fallback to ", default_value, "."
        ))
        return(default_value)
    }
    category_col
}

normalize_ppt_summary_category_columns <- function(value) {
    default_cols <- c("Category1", "Category2", "Category3")
    valid_cols <- get_ppt_category_columns()
    cols <- trimws(as.character(value))
    cols <- unique(cols[!is.na(cols) & nzchar(cols)])
    unknown_cols <- setdiff(cols, valid_cols)
    if (length(unknown_cols) > 0L) {
        ppt_log_warning(paste0(
            "[Warning] Invalid summary_category_columns ignored: ",
            paste(unknown_cols, collapse = ", ")
        ))
    }
    cols <- cols[cols %in% valid_cols]
    if (length(cols) == 0L) {
        return(default_cols)
    }
    cols
}

clean_ppt_text_value <- function(x) {
    vals <- trimws(as.character(x))
    vals[is.na(vals)] <- ""
    vals
}

normalize_required_yn <- function(x) {
    vals <- toupper(clean_ppt_text_value(x))
    vals %in% c("Y", "YES", "TRUE", "1")
}

resolve_ppt_config_numeric <- function(ppt_cfg, key, default) {
    value <- suppressWarnings(as.numeric(ppt_cfg[[key]][1]))
    if (!is.finite(value)) {
        return(default)
    }
    value
}

resolve_ppt_config_logical <- function(ppt_cfg, key, default = FALSE) {
    value <- ppt_cfg[[key]][1]
    if (is.logical(value) && !is.na(value)) {
        return(isTRUE(value))
    }

    value_txt <- toupper(trimws(as.character(value)))
    if (is.na(value_txt) || !nzchar(value_txt)) {
        return(isTRUE(default))
    }
    if (value_txt %in% c("TRUE", "T", "YES", "Y", "1")) {
        return(TRUE)
    }
    if (value_txt %in% c("FALSE", "F", "NO", "N", "0")) {
        return(FALSE)
    }
    isTRUE(default)
}

prepare_ppt_result_dt <- function(result_dt) {
    out <- data.table::copy(data.table::as.data.table(result_dt))

    for (category_col in get_ppt_category_columns()) {
        if (!category_col %in% names(out)) {
            out[, (category_col) := NA_character_]
        }
    }
    for (required_col in c("SLIDE_REQUIRED_YN", "SUMMARY_REQUIRED_YN")) {
        if (!required_col %in% names(out)) {
            out[, (required_col) := NA_character_]
        }
    }

    if ("Direction" %in% names(out)) {
        out[, ppt_flagged := Direction %in% c("Up", "Down")]
    } else {
        out[, ppt_flagged := FALSE]
    }
    out[, ppt_slide_required := normalize_required_yn(SLIDE_REQUIRED_YN)]
    out[, ppt_summary_required := normalize_required_yn(SUMMARY_REQUIRED_YN)]

    if ("Abs_Sigma_Score" %in% names(out)) {
        score_sort <- suppressWarnings(as.numeric(out[["Abs_Sigma_Score"]]))
    } else {
        score_sort <- rep(NA_real_, nrow(out))
    }
    score_sort[is.na(score_sort)] <- -Inf
    out[, ppt_abs_score_sort := score_sort]
    out[, ppt_row_order := seq_len(.N)]

    out
}

select_ppt_candidate_dt <- function(result_dt, selection_mode, required_flag_col) {
    required_flag <- as.logical(result_dt[[required_flag_col]])
    flagged <- as.logical(result_dt[["ppt_flagged"]])

    include <- switch(
        selection_mode,
        required_only = required_flag,
        flagged_only = flagged,
        both = required_flag | flagged
    )
    include[is.na(include)] <- FALSE

    selected_dt <- result_dt[include]
    if (nrow(selected_dt) == 0L) {
        return(selected_dt)
    }

    ord <- order(
        -as.integer(selected_dt[[required_flag_col]]),
        -as.integer(selected_dt[["ppt_flagged"]]),
        -selected_dt[["ppt_abs_score_sort"]],
        selected_dt[["ppt_row_order"]]
    )
    selected_dt[ord]
}

get_ppt_score_values <- function(dt, score_col = "Sigma_Score") {
    if (!score_col %in% names(dt)) {
        return(rep(NA_real_, nrow(dt)))
    }
    suppressWarnings(as.numeric(dt[[score_col]]))
}

select_summary_candidate_dt <- function(result_dt, category_cols, sigma_threshold, prepared = FALSE) {
    dt <- if (isTRUE(prepared)) {
        data.table::copy(data.table::as.data.table(result_dt))
    } else {
        prepare_ppt_result_dt(result_dt)
    }
    category_cols <- normalize_ppt_summary_category_columns(category_cols)

    threshold <- suppressWarnings(as.numeric(sigma_threshold)[1])
    if (!is.finite(threshold)) {
        threshold <- Inf
    }

    for (category_col in category_cols) {
        vals <- clean_ppt_text_value(dt[[category_col]])
        vals[!nzchar(vals)] <- "Uncategorized"
        dt[, (category_col) := vals]
    }

    summary_score <- get_ppt_score_values(dt)
    dt[, ppt_summary_abs_score := abs(summary_score)]
    dt[!is.finite(ppt_summary_abs_score), ppt_summary_abs_score := -Inf]

    selected_dt <- dt[
        ,
        {
            candidate_dt <- .SD
            required_dt <- candidate_dt[ppt_summary_required == TRUE]
            if (nrow(required_dt) > 0L) {
                candidate_dt <- required_dt
            }
            candidate_dt <- candidate_dt[order(-ppt_summary_abs_score, MSR)]
            candidate_dt[1L]
        },
        by = category_cols
    ]

    order_cols <- character()
    for (category_index in seq_along(category_cols)) {
        prefix_cols <- category_cols[seq_len(category_index)]
        order_col <- paste0("ppt_summary_category_order_", category_index)
        prefix_order_dt <- unique(dt[, ..prefix_cols])
        prefix_order_dt[, (order_col) := seq_len(.N)]
        selected_dt <- merge(selected_dt, prefix_order_dt, by = prefix_cols, all.x = TRUE, sort = FALSE)
        order_cols <- c(order_cols, order_col)
    }

    selected_dt[, Selected_By := data.table::fcase(
        ppt_summary_required & ppt_summary_abs_score >= threshold, "Required + Sigma",
        ppt_summary_required, "Required",
        ppt_summary_abs_score >= threshold, "Sigma",
        default = "Group Max"
    )]

    data.table::setorderv(selected_dt, c(order_cols, "MSR"), na.last = TRUE)
    selected_dt[, (order_cols) := NULL]
    selected_dt[]
}

get_category_fallback_columns <- function(category_col) {
    valid_cols <- get_ppt_category_columns()
    category_index <- match(category_col, valid_cols)
    rev(valid_cols[seq_len(category_index)])
}

add_detail_group_columns <- function(result_dt, detail_group_by) {
    out <- data.table::copy(result_dt)
    group_cols <- get_category_fallback_columns(detail_group_by)

    group_label <- rep("Uncategorized", nrow(out))
    group_value <- rep("Uncategorized", nrow(out))
    group_level <- rep("Uncategorized", nrow(out))

    for (category_col in group_cols) {
        vals <- clean_ppt_text_value(out[[category_col]])
        fill_index <- group_label == "Uncategorized" & nzchar(vals)
        group_label[fill_index] <- paste0(category_col, ": ", vals[fill_index])
        group_value[fill_index] <- vals[fill_index]
        group_level[fill_index] <- category_col
    }

    out[, ppt_detail_group_label := group_label]
    out[, ppt_detail_group_value := group_value]
    out[, ppt_detail_group_level := group_level]
    out
}

resolve_summary_mean_col <- function(summary_dt, group_names, fallback_index = 1L, exclude_cols = character()) {
    mean_cols <- grep("^Mean_", names(summary_dt), value = TRUE)
    group_names <- clean_ppt_text_value(group_names)
    group_names <- group_names[nzchar(group_names)]
    for (group_name in group_names) {
        candidate_col <- paste0("Mean_", group_name)
        if (candidate_col %in% names(summary_dt)) {
            return(candidate_col)
        }
    }

    fallback_cols <- setdiff(mean_cols, exclude_cols)
    if (length(fallback_cols) >= fallback_index) {
        return(fallback_cols[[fallback_index]])
    }
    if (length(fallback_cols) > 0L) {
        return(fallback_cols[[1L]])
    }
    NA_character_
}

format_summary_number <- function(x, digits = 2L, signed = FALSE) {
    values <- suppressWarnings(as.numeric(x))
    out <- rep("", length(values))
    ok <- is.finite(values)
    fmt <- paste0(if (isTRUE(signed)) "%+." else "%.", as.integer(digits), "f")
    out[ok] <- sprintf(fmt, values[ok])
    out
}

format_summary_sigma_delta <- function(x) {
    vapply(x, format_detail_sigma_text, character(1))
}

format_summary_result_text <- function(direction) {
    direction <- clean_ppt_text_value(direction)
    direction[!direction %in% c("Up", "Down")] <- "Stable"
    paste0("\u2B24 ", direction)
}

build_summary_display_dt <- function(summary_dt, category_cols, ref_group = NULL, target_group = NULL) {
    display_values <- list()
    for (category_col in category_cols) {
        display_col <- paste0("Cat", sub("^Category", "", category_col))
        category_vals <- clean_ppt_text_value(summary_dt[[category_col]])
        category_vals[!nzchar(category_vals)] <- "Uncategorized"
        display_values[[display_col]] <- category_vals
    }

    msr_label <- clean_ppt_text_value(summary_dt[["MSR"]])
    if ("ITEM_NAME" %in% names(summary_dt)) {
        item_label <- clean_ppt_text_value(summary_dt[["ITEM_NAME"]])
        msr_label[nzchar(item_label)] <- item_label[nzchar(item_label)]
    }
    display_values[["Item"]] <- msr_label

    ref_mean_col <- resolve_summary_mean_col(summary_dt, ref_group, fallback_index = 1L)
    tgt_mean_col <- resolve_summary_mean_col(summary_dt, target_group, fallback_index = 1L, exclude_cols = ref_mean_col)
    ref_mean <- if (!is.na(ref_mean_col)) {
        suppressWarnings(as.numeric(summary_dt[[ref_mean_col]]))
    } else {
        rep(NA_real_, nrow(summary_dt))
    }
    tgt_mean <- if (!is.na(tgt_mean_col)) {
        suppressWarnings(as.numeric(summary_dt[[tgt_mean_col]]))
    } else {
        rep(NA_real_, nrow(summary_dt))
    }
    display_values[["REF"]] <- format_summary_number(ref_mean)
    display_values[["TGT"]] <- format_summary_number(tgt_mean)
    display_values[["Delta"]] <- format_summary_number(tgt_mean - ref_mean, signed = TRUE)

    if ("Sigma_Score" %in% names(summary_dt)) {
        sigma_delta <- suppressWarnings(as.numeric(summary_dt[["Sigma_Score"]]))
        display_values[["Sigma Delta"]] <- format_summary_sigma_delta(sigma_delta)
    } else {
        display_values[["Sigma Delta"]] <- rep("", nrow(summary_dt))
    }
    if ("Direction" %in% names(summary_dt)) {
        display_values[["Result"]] <- format_summary_result_text(summary_dt[["Direction"]])
    } else {
        display_values[["Result"]] <- format_summary_result_text(rep("Stable", nrow(summary_dt)))
    }
    display_values[["Note"]] <- rep(" ", nrow(summary_dt))
    display_values[["TREND"]] <- rep(" ", nrow(summary_dt))

    data.table::as.data.table(display_values)
}

build_detail_header_label <- function(group_label, page_index, total_pages, start_index, end_index, total_count) {
    range_text <- if (start_index == end_index) {
        as.character(start_index)
    } else {
        paste0(start_index, "-", end_index)
    }
    page_text <- if (total_pages > 1L) {
        paste0(" (", page_index, "/", total_pages, ")")
    } else {
        ""
    }
    paste0(group_label, " - MSR ", range_text, " of ", total_count, page_text)
}

format_detail_sigma_text <- function(sigma_score) {
    sigma_value <- suppressWarnings(as.numeric(sigma_score)[1])
    if (!is.finite(sigma_value)) {
        return("")
    }
    sprintf("%+.1fsig", sigma_value)
}

add_detail_sigma_box <- function(ppt, sigma_text, location, ppt_cfg) {
    sigma_text <- as.character(sigma_text)[1]
    if (is.na(sigma_text) || !nzchar(sigma_text)) {
        return(ppt)
    }

    box_w <- min(0.62, max(0.35, location$plot_w * 0.25))
    box_h <- 0.18
    box_left <- location$plot_left + location$plot_w - box_w - 0.03
    box_top <- location$plot_top + 0.03

    sigma_value <- officer::fpar(
        officer::ftext(
            sigma_text,
            officer::fp_text(
                color = as.character(ppt_cfg$detail_sigma_color),
                font.size = resolve_ppt_config_numeric(ppt_cfg, "detail_sigma_font_size", 8)
            )
        ),
        fp_p = officer::fp_par(text.align = "right")
    )

    ph_with(
        ppt,
        value = sigma_value,
        location = ph_location(
            left = box_left,
            top = box_top,
            width = box_w,
            height = box_h,
            bg = "transparent"
        )
    )
}

calculate_summary_table_box <- function(ppt_cfg) {
    slide_w <- resolve_ppt_config_numeric(ppt_cfg, "slide_width", 13.33)
    slide_h <- resolve_ppt_config_numeric(ppt_cfg, "slide_height", 7.50)
    left <- max(0, resolve_ppt_config_numeric(ppt_cfg, "summary_table_left", 0.32))
    top <- max(0, resolve_ppt_config_numeric(ppt_cfg, "summary_table_top", 1.18))
    width <- max(0.1, resolve_ppt_config_numeric(ppt_cfg, "summary_table_width", 12.69))
    height <- max(0.1, resolve_ppt_config_numeric(ppt_cfg, "summary_table_height", 5.82))

    width <- min(width, max(0.1, slide_w - left))
    height <- min(height, max(0.1, slide_h - top))

    list(left = left, top = top, width = width, height = height)
}

summary_table_location <- function(ppt_cfg) {
    box <- calculate_summary_table_box(ppt_cfg)
    officer::ph_location(
        left = box$left,
        top = box$top,
        width = box$width,
        height = box$height,
        bg = "transparent"
    )
}

style_summary_flextable <- function(sub_sum, ppt_cfg, sigma_threshold) {
    ft <- flextable::flextable(sub_sum)
    header_labels <- stats::setNames(names(sub_sum), names(sub_sum))
    for (single_col in intersect(c("Item", "Result", "TREND", "Note"), names(header_labels))) {
        header_labels[[single_col]] <- " "
    }
    if ("Sigma Delta" %in% names(header_labels)) {
        header_labels[["Sigma Delta"]] <- "Sigma Delta"
    }
    ft <- flextable::set_header_labels(ft, values = header_labels)

    category_cols <- grep("^Cat[0-9]+$", names(sub_sum), value = TRUE)
    top_header_values <- character()
    top_header_widths <- integer()
    if (length(category_cols) > 0L) {
        top_header_values <- c(top_header_values, "\uAD6C\uBD84")
        top_header_widths <- c(top_header_widths, length(category_cols))
    }
    header_groups <- list(
        Item = list(label = "\uC8FC\uC694 \uD56D\uBAA9", width = 1L),
        Level = list(label = "\uC9C0\uC218\uC218\uC900", width = length(intersect(c("REF", "TGT"), names(sub_sum)))),
        Diff = list(label = "Diff", width = length(intersect(c("Delta", "Sigma Delta"), names(sub_sum)))),
        Result = list(label = "\uBCC0\uB3D9\uACB0\uACFC", width = 1L),
        Note = list(label = "\uBE44\uACE0", width = 1L),
        TREND = list(label = "TREND", width = 1L)
    )
    for (header_group in header_groups) {
        if (header_group$width > 0L) {
            top_header_values <- c(top_header_values, header_group$label)
            top_header_widths <- c(top_header_widths, header_group$width)
        }
    }
    ft <- flextable::add_header_row(ft, values = top_header_values, colwidths = top_header_widths)
    for (single_col in intersect(c("Item", "Result", "TREND", "Note"), names(sub_sum))) {
        ft <- flextable::merge_at(ft, i = 1:2, j = single_col, part = "header")
    }

    if (length(category_cols) > 0L) {
        ft <- flextable::merge_v(ft, j = category_cols)
    }

    body_border <- officer::fp_border(
        color = as.character(ppt_cfg$summary_border_color),
        width = 0.35
    )
    header_border <- officer::fp_border(
        color = as.character(ppt_cfg$summary_header_fill),
        width = 1.2
    )
    group_border <- officer::fp_border(
        color = "#8C8C8C",
        width = 0.8
    )

    ft <- flextable::fontsize(ft, size = resolve_ppt_config_numeric(ppt_cfg, "summary_font_size", 8), part = "all")
    ft <- flextable::font(ft, fontname = "Arial", part = "all")
    ft <- flextable::padding(ft, padding = 1.5, part = "all")
    ft <- flextable::line_spacing(ft, space = 1.1, part = "all")
    ft <- flextable::border_remove(ft)
    ft <- flextable::hline_top(ft, border = header_border, part = "header")
    ft <- flextable::hline_bottom(ft, border = header_border, part = "header")
    ft <- flextable::hline(ft, border = body_border, part = "body")
    ft <- flextable::bg(ft, bg = as.character(ppt_cfg$summary_header_fill), part = "header")
    ft <- flextable::color(ft, color = as.character(ppt_cfg$summary_header_color), part = "header")
    ft <- flextable::bold(ft, part = "header")
    ft <- flextable::align(ft, align = "center", part = "all")
    ft <- flextable::valign(ft, valign = "center", part = "all")
    ft <- flextable::hrule(ft, rule = "exact", part = "all")

    if (length(category_cols) > 0L) {
        ft <- flextable::bg(ft, j = category_cols, bg = as.character(ppt_cfg$summary_category_fill), part = "body")
        ft <- flextable::color(ft, j = category_cols, color = as.character(ppt_cfg$summary_category_color), part = "body")
        ft <- flextable::bold(ft, j = category_cols[1L], bold = TRUE, part = "body")
        ft <- flextable::vline(ft, j = tail(category_cols, 1L), border = body_border, part = "all")
    }

    if ("Item" %in% names(sub_sum)) {
        ft <- flextable::align(ft, j = "Item", align = "left", part = "body")
        ft <- flextable::vline(ft, j = "Item", border = body_border, part = "all")
    }

    if ("TGT" %in% names(sub_sum)) {
        ft <- flextable::vline(ft, j = "TGT", border = body_border, part = "all")
    }

    if ("Result" %in% names(sub_sum)) {
        up_rows <- which(grepl("Up$", sub_sum$Result))
        if (length(up_rows) > 0L) {
            ft <- flextable::color(ft, i = up_rows, j = "Result", color = as.character(ppt_cfg$detail_label_up_color), part = "body")
            ft <- flextable::bold(ft, i = up_rows, j = "Result", bold = TRUE, part = "body")
        }

        down_rows <- which(grepl("Down$", sub_sum$Result))
        if (length(down_rows) > 0L) {
            ft <- flextable::color(ft, i = down_rows, j = "Result", color = as.character(ppt_cfg$detail_label_down_color), part = "body")
            ft <- flextable::bold(ft, i = down_rows, j = "Result", bold = TRUE, part = "body")
        }

        stable_rows <- which(grepl("Stable$", sub_sum$Result))
        if (length(stable_rows) > 0L) {
            ft <- flextable::color(ft, i = stable_rows, j = "Result", color = as.character(ppt_cfg$detail_label_neutral_color), part = "body")
        }

        ft <- flextable::vline(ft, j = "Result", border = group_border, part = "all")
    }

    if ("Note" %in% names(sub_sum)) {
        ft <- flextable::vline(ft, j = "Note", border = group_border, part = "all")
    }

    threshold <- suppressWarnings(as.numeric(sigma_threshold)[1])
    if (is.finite(threshold) && "Sigma Delta" %in% names(sub_sum)) {
        sigma_delta <- suppressWarnings(as.numeric(gsub("sig", "", sub_sum[["Sigma Delta"]], fixed = TRUE)))
        score_rows <- which(abs(sigma_delta) >= threshold)
        if (length(score_rows) > 0L) {
            ft <- flextable::color(ft, i = score_rows, j = "Sigma Delta", color = as.character(ppt_cfg$summary_highlight_color), part = "body")
            ft <- flextable::bold(ft, i = score_rows, j = "Sigma Delta", bold = TRUE, part = "body")
        }
    }

    ft <- flextable::autofit(ft)
    if (length(category_cols) > 0L) {
        ft <- flextable::width(ft, j = category_cols, width = resolve_ppt_config_numeric(ppt_cfg, "summary_category_col_width", 0.55), unit = "in")
    }
    width_map <- list(
        Item = c("summary_item_col_width", 1.70),
        REF = c("summary_value_col_width", 0.55),
        TGT = c("summary_value_col_width", 0.55),
        Delta = c("summary_diff_col_width", 0.65),
        `Sigma Delta` = c("summary_diff_col_width", 0.65),
        Result = c("summary_result_col_width", 0.70),
        TREND = c("summary_trend_col_width", 3.80),
        Note = c("summary_note_col_width", 2.44)
    )
    for (col_name in intersect(names(width_map), names(sub_sum))) {
        width_spec <- width_map[[col_name]]
        ft <- flextable::width(
            ft,
            j = col_name,
            width = resolve_ppt_config_numeric(ppt_cfg, width_spec[[1]], as.numeric(width_spec[[2]])),
            unit = "in"
        )
    }

    if (any(c("TREND", "Note") %in% names(sub_sum))) {
        ft <- flextable::bg(ft, j = intersect(c("TREND", "Note"), names(sub_sum)), bg = "#FFFFFF", part = "body")
        ft <- flextable::align(ft, j = intersect(c("TREND", "Note"), names(sub_sum)), align = "left", part = "body")
    }
    box <- calculate_summary_table_box(ppt_cfg)
    header_h <- 0.23
    body_h <- max(0.18, (box$height - (2 * header_h)) / max(1L, nrow(sub_sum)))
    ft <- flextable::height(ft, i = 1:2, height = header_h, part = "header")
    ft <- flextable::height(ft, i = seq_len(nrow(sub_sum)), height = body_h, part = "body")

    ft
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
                ppt_log_warning(paste0(
                    "[Warning] Unknown PPT_CONFIG keys ignored: ",
                    paste(unknown_keys, collapse = ", ")
                ))
            }
            for (key in intersect(names(ppt_config), names(ppt_defaults))) {
                ppt_cfg[[key]] <- ppt_config[[key]]
            }
        }
    }

    layout_mode <- tolower(trimws(as.character(ppt_cfg$ppt_layout_mode)[1]))
    if (is.na(layout_mode) || !layout_mode %in% c("dev", "template")) {
        layout_mode <- "dev"
    }
    ppt_cfg$ppt_layout_mode <- layout_mode
    if (layout_mode == "template") {
        ppt_cfg$slide_header_mode <- "template_placeholder"
    } else {
        ppt_cfg$slide_header_mode <- "dev_overlay"
    }

    ppt_cfg$detail_group_by <- normalize_ppt_category_column(ppt_cfg$detail_group_by)
    ppt_cfg$detail_msr_selection_mode <- normalize_ppt_selection_mode(
        ppt_cfg$detail_msr_selection_mode,
        "detail_msr_selection_mode"
    )
    ppt_cfg$summary_msr_selection_mode <- normalize_ppt_selection_mode(
        ppt_cfg$summary_msr_selection_mode,
        "summary_msr_selection_mode"
    )
    ppt_cfg$summary_category_columns <- normalize_ppt_summary_category_columns(
        ppt_cfg$summary_category_columns
    )
    ppt_cfg$goobae_slide_enabled <- resolve_ppt_config_logical(
        ppt_cfg,
        "goobae_slide_enabled",
        TRUE
    )

    ppt_cfg
}

resolve_ppt_slide_title <- function(ppt_cfg) {
    default_title <- "[DM] DRB Statistical Auto Report"
    slide_title <- as.character(ppt_cfg$slide_title)[1]
    if (is.na(slide_title) || !nzchar(trimws(slide_title))) {
        return(default_title)
    }
    slide_title
}

normalize_ppt_text_vector <- function(x) {
    vals <- trimws(as.character(x))
    vals <- vals[!is.na(vals) & nzchar(vals)]
    vals
}

format_ppt_context_value <- function(x) {
    vals <- normalize_ppt_text_vector(x)
    if (length(vals) == 0L) {
        return("N/A")
    }
    paste(vals, collapse = ", ")
}

render_ppt_text_template <- function(text, context) {
    out <- as.character(text)
    for (key in names(context)) {
        out <- gsub(
            paste0("{", key, "}"),
            format_ppt_context_value(context[[key]]),
            out,
            fixed = TRUE
        )
    }
    out
}

resolve_ppt_slide_bullets <- function(ppt_cfg, template_key, context = list()) {
    templates <- normalize_ppt_text_vector(ppt_cfg[[template_key]])
    max_bullets <- suppressWarnings(as.integer(ppt_cfg$slide_max_bullets)[1])
    if (!is.finite(max_bullets) || max_bullets < 1L) {
        max_bullets <- 3L
    }
    if (length(templates) > max_bullets) {
        templates <- templates[seq_len(max_bullets)]
    }
    normalize_ppt_text_vector(vapply(
        templates,
        render_ppt_text_template,
        character(1),
        context = context
    ))
}

resolve_ppt_config_string <- function(x, default = "") {
    val <- as.character(x)[1]
    if (is.na(val) || !nzchar(trimws(val))) {
        return(default)
    }
    val
}

resolve_ppt_header_mode <- function(ppt_cfg) {
    mode <- tolower(trimws(resolve_ppt_config_string(ppt_cfg$slide_header_mode, "dev_overlay")))
    if (!mode %in% c("dev_overlay", "template_placeholder")) {
        return("dev_overlay")
    }
    mode
}

resolve_ppt_template_path <- function(ppt_cfg) {
    template_path <- resolve_ppt_config_string(ppt_cfg$ppt_template_path, file.path("data", "template_16_9.pptx"))
    if (grepl("^([A-Za-z]:|/|\\\\\\\\)", template_path)) {
        return(normalizePath(template_path, winslash = "/", mustWork = FALSE))
    }
    normalizePath(here::here(template_path), winslash = "/", mustWork = FALSE)
}

resolve_ppt_placeholder_location <- function(ppt_cfg, kind) {
    if (identical(kind, "title")) {
        label <- resolve_ppt_config_string(ppt_cfg$slide_header_title_placeholder_label, "")
        type <- resolve_ppt_config_string(ppt_cfg$slide_header_title_placeholder_type, "title")
    } else {
        label <- resolve_ppt_config_string(ppt_cfg$slide_header_bullet_placeholder_label, "")
        type <- resolve_ppt_config_string(ppt_cfg$slide_header_bullet_placeholder_type, "")
    }

    if (nzchar(label)) {
        return(ph_location_label(ph_label = label))
    }
    if (!nzchar(type)) {
        stop("No ", kind, " placeholder label/type configured.")
    }
    ph_location_type(type = type)
}

try_ph_with_location <- function(ppt, value, location) {
    tryCatch(
        list(ppt = ph_with(ppt, value = value, location = location), ok = TRUE),
        error = function(e) {
            list(ppt = ppt, ok = FALSE, message = e$message)
        }
    )
}

build_ppt_header_title_value <- function(ppt_cfg) {
    officer::fpar(
        officer::ftext(
            resolve_ppt_slide_title(ppt_cfg),
            officer::fp_text(
                color = as.character(ppt_cfg$slide_header_title_color),
                font.size = as.numeric(ppt_cfg$slide_header_title_font_size),
                bold = TRUE
            )
        ),
        fp_p = officer::fp_par(text.align = "left")
    )
}

build_ppt_header_bullet_value <- function(ppt_cfg, bullets = character()) {
    bullets <- normalize_ppt_text_vector(bullets)
    if (length(bullets) == 0L) {
        return(NULL)
    }

    marker <- as.character(ppt_cfg$slide_bullet_symbol)[1]
    if (is.na(marker) || !nzchar(marker)) {
        marker <- "\u25A0"
    }
    bullet_size <- as.numeric(ppt_cfg$slide_header_bullet_font_size)
    bullet_color <- as.character(ppt_cfg$slide_header_bullet_color)
    bullet_blocks <- lapply(bullets, function(bullet) {
        officer::fpar(
            officer::ftext(
                marker,
                officer::fp_text(color = bullet_color, font.size = bullet_size, bold = TRUE)
            ),
            officer::ftext(
                paste0(" ", bullet),
                officer::fp_text(color = bullet_color, font.size = bullet_size)
            ),
            fp_p = officer::fp_par(text.align = "left")
        )
    })
    do.call(officer::block_list, bullet_blocks)
}

add_ppt_slide_header_title_overlay <- function(ppt, ppt_cfg, title_value = NULL) {
    if (is.null(title_value)) {
        title_value <- build_ppt_header_title_value(ppt_cfg)
    }
    ph_with(
        ppt,
        value = title_value,
        location = ph_location(
            left = as.numeric(ppt_cfg$slide_header_left),
            top = as.numeric(ppt_cfg$slide_header_title_top),
            width = as.numeric(ppt_cfg$slide_header_title_width),
            height = as.numeric(ppt_cfg$slide_header_title_height),
            bg = "transparent"
        )
    )
}

add_ppt_slide_header_bullets_overlay <- function(ppt, ppt_cfg, bullet_value = NULL, bullets = character()) {
    if (is.null(bullet_value)) {
        bullet_value <- build_ppt_header_bullet_value(ppt_cfg, bullets)
    }
    if (is.null(bullet_value)) {
        return(ppt)
    }
    ph_with(
        ppt,
        value = bullet_value,
        location = ph_location(
            left = as.numeric(ppt_cfg$slide_header_left),
            top = as.numeric(ppt_cfg$slide_header_bullet_top),
            width = as.numeric(ppt_cfg$slide_header_bullet_width),
            height = as.numeric(ppt_cfg$slide_header_bullet_height),
            bg = "transparent"
        )
    )
}

add_ppt_slide_header <- function(ppt, ppt_cfg, bullets = character()) {
    title_value <- build_ppt_header_title_value(ppt_cfg)
    template_title_value <- resolve_ppt_slide_title(ppt_cfg)
    bullet_value <- build_ppt_header_bullet_value(ppt_cfg, bullets)
    bullets <- normalize_ppt_text_vector(bullets)

    if (resolve_ppt_header_mode(ppt_cfg) == "template_placeholder") {
        title_location <- tryCatch(
            resolve_ppt_placeholder_location(ppt_cfg, "title"),
            error = function(e) e
        )
        title_res <- if (inherits(title_location, "error")) {
            list(ppt = ppt, ok = FALSE, message = title_location$message)
        } else {
            try_ph_with_location(ppt, value = template_title_value, location = title_location)
        }
        ppt <- title_res$ppt

        bullet_res <- list(ppt = ppt, ok = TRUE)
        if (!is.null(bullet_value)) {
            bullet_location <- tryCatch(
                resolve_ppt_placeholder_location(ppt_cfg, "bullet"),
                error = function(e) e
            )
            bullet_res <- if (inherits(bullet_location, "error")) {
                list(ppt = ppt, ok = FALSE, message = bullet_location$message)
            } else {
                try_ph_with_location(ppt, value = bullet_value, location = bullet_location)
            }
            ppt <- bullet_res$ppt
        }

        if (isTRUE(ppt_cfg$slide_header_placeholder_fallback)) {
            if (!isTRUE(title_res$ok)) {
                ppt <- add_ppt_slide_header_title_overlay(ppt, ppt_cfg, title_value = title_value)
            }
            if (!isTRUE(bullet_res$ok) && !is.null(bullet_value)) {
                ppt <- add_ppt_slide_header_bullets_overlay(ppt, ppt_cfg, bullet_value = bullet_value)
            }
        }
        return(ppt)
    }

    ppt <- add_ppt_slide_header_title_overlay(ppt, ppt_cfg, title_value = title_value)
    add_ppt_slide_header_bullets_overlay(ppt, ppt_cfg, bullet_value = bullet_value, bullets = bullets)
}

add_ppt_summary_slide_header <- function(ppt, ppt_cfg, bullets = character()) {
    summary_cfg <- ppt_cfg
    summary_cfg$slide_header_bullet_top <- resolve_ppt_config_numeric(
        ppt_cfg,
        "summary_header_bullet_top",
        0.76
    )
    summary_cfg$slide_header_bullet_height <- resolve_ppt_config_numeric(
        ppt_cfg,
        "summary_header_bullet_height",
        0.24
    )
    summary_cfg$slide_header_bullet_font_size <- resolve_ppt_config_numeric(
        ppt_cfg,
        "summary_header_bullet_font_size",
        9.5
    )
    add_ppt_slide_header(ppt, summary_cfg, bullets = bullets)
}

calculate_detail_plot_layout <- function(ppt_cfg, grid_ncol, grid_nrow) {
    grid_ncol <- max(1L, as.integer(grid_ncol))
    grid_nrow <- max(1L, as.integer(grid_nrow))

    slide_w <- as.numeric(ppt_cfg$slide_width)
    slide_h <- as.numeric(ppt_cfg$slide_height)
    margin_top <- as.numeric(ppt_cfg$margin_top)
    margin_left <- as.numeric(ppt_cfg$margin_left)
    margin_right <- as.numeric(ppt_cfg$margin_right)
    margin_bottom <- as.numeric(ppt_cfg$margin_bottom)
    cell_padding <- as.numeric(ppt_cfg$detail_cell_padding)
    label_height <- as.numeric(ppt_cfg$detail_label_height)
    label_plot_gap <- as.numeric(ppt_cfg$detail_label_plot_gap)
    plot_top_inset <- as.numeric(ppt_cfg$detail_plot_top_inset)

    if (length(cell_padding) == 0 || !is.finite(cell_padding) || cell_padding < 0) {
        cell_padding <- 0
    }
    if (length(label_height) == 0 || !is.finite(label_height) || label_height < 0) {
        label_height <- 0
    }
    if (length(label_plot_gap) == 0 || !is.finite(label_plot_gap) || label_plot_gap < 0) {
        label_plot_gap <- 0
    }
    if (length(plot_top_inset) == 0 || !is.finite(plot_top_inset) || plot_top_inset < 0) {
        plot_top_inset <- 0
    }

    content_w <- slide_w - margin_left - margin_right
    content_h <- slide_h - margin_top - margin_bottom
    cell_w <- content_w / grid_ncol
    plot_w <- cell_w - (2 * cell_padding)
    header_row_h <- label_height + cell_padding + label_plot_gap
    label_row_h <- label_height + label_plot_gap
    body_top <- margin_top + header_row_h
    body_h <- content_h - header_row_h
    cell_h <- body_h / grid_nrow
    plot_row_h <- cell_h - label_row_h
    plot_h <- plot_row_h - cell_padding - plot_top_inset

    layout_vals <- c(
        slide_w, slide_h, margin_top, margin_left, margin_right, margin_bottom,
        content_w, content_h, cell_w, cell_h, plot_w, plot_h, cell_padding,
        label_height, label_plot_gap, header_row_h, body_top, body_h, label_row_h,
        plot_row_h, plot_top_inset
    )
    if (any(!is.finite(layout_vals)) || content_w <= 0 || content_h <= 0 || cell_w <= 0 || cell_h <= 0 || plot_w <= 0 || plot_h <= 0 || header_row_h <= 0 || body_h <= 0 || label_row_h <= 0 || plot_row_h <= 0) {
        stop("Invalid detail plot layout. Check PPT_CONFIG slide size, margins, grid, label, padding, and plot settings.")
    }

    list(
        grid_ncol = grid_ncol,
        grid_nrow = grid_nrow,
        table_nrow = (grid_nrow * 2L) + 1L,
        left = margin_left,
        top = margin_top,
        right = slide_w - margin_right,
        bottom = slide_h - margin_bottom,
        width = content_w,
        height = content_h,
        cell_w = cell_w,
        cell_h = cell_h,
        cell_padding = cell_padding,
        label_height = label_height,
        label_plot_gap = label_plot_gap,
        plot_top_inset = plot_top_inset,
        header_row_h = header_row_h,
        body_top = body_top,
        body_h = body_h,
        label_row_h = label_row_h,
        plot_row_h = plot_row_h,
        plot_w = plot_w,
        plot_h = plot_h
    )
}

detail_layout_for_index <- function(detail_layout, index) {
    row_idx <- floor((index - 1L) / detail_layout$grid_ncol)
    col_idx <- (index - 1L) %% detail_layout$grid_ncol
    cell_left <- detail_layout$left + (col_idx * detail_layout$cell_w)
    cell_top <- detail_layout$body_top + (row_idx * detail_layout$cell_h)
    label_row_top <- cell_top
    plot_row_top <- label_row_top + detail_layout$label_row_h
    plot_left <- cell_left + detail_layout$cell_padding
    label_top <- label_row_top + ((detail_layout$label_row_h - detail_layout$label_height) / 2)
    list(
        cell_left = cell_left,
        cell_top = cell_top,
        label_row_top = label_row_top,
        plot_row_top = plot_row_top,
        label_left = plot_left,
        label_top = label_top,
        label_w = detail_layout$plot_w,
        label_h = detail_layout$label_height,
        plot_left = plot_left,
        plot_top = plot_row_top + detail_layout$plot_top_inset,
        plot_w = detail_layout$plot_w,
        plot_h = detail_layout$plot_h
    )
}

build_detail_label_text <- function(msr, item_name = NULL, show_field = TRUE) {
    field <- as.character(msr)[1]
    if (is.na(field) || !nzchar(field)) {
        field <- ""
    }

    item <- as.character(item_name)[1]
    if (is.na(item) || !nzchar(item)) {
        item <- field
    }

    marker <- "\u2B24"
    show_field_val <- isTRUE(show_field)
    if (show_field_val && nzchar(field)) {
        paste0(marker, " (", field, ") ", item)
    } else {
        paste0(marker, " ", item)
    }
}

resolve_detail_marker_color <- function(direction, ppt_cfg) {
    direction_val <- tolower(trimws(as.character(direction)[1]))
    if (is.na(direction_val)) {
        direction_val <- ""
    }

    if (direction_val == "up") {
        return(as.character(ppt_cfg$detail_label_up_color))
    }
    if (direction_val == "down") {
        return(as.character(ppt_cfg$detail_label_down_color))
    }
    as.character(ppt_cfg$detail_label_neutral_color)
}

add_detail_grid_table <- function(ppt, detail_layout, ppt_cfg, header_label = NULL) {
    table_data <- as.data.frame(
        matrix(" ", nrow = detail_layout$table_nrow, ncol = detail_layout$grid_ncol),
        stringsAsFactors = FALSE
    )
    names(table_data) <- paste0("C", seq_len(detail_layout$grid_ncol))
    if (!is.null(header_label) && nzchar(as.character(header_label)[1])) {
        table_data[1L, 1L] <- as.character(header_label)[1]
    }
    header_rows <- 1L
    label_rows <- seq.int(2L, detail_layout$table_nrow, by = 2L)
    plot_rows <- seq.int(3L, detail_layout$table_nrow, by = 2L)

    grid_border <- officer::fp_border(
        color = as.character(ppt_cfg$detail_table_border_color),
        width = as.numeric(ppt_cfg$detail_table_border_width)
    )

    ft <- flextable::flextable(table_data)
    ft <- flextable::delete_part(ft, part = "header")
    ft <- flextable::merge_at(ft, i = header_rows, j = seq_len(detail_layout$grid_ncol), part = "body")
    ft <- flextable::border_remove(ft)
    ft <- flextable::border(ft, border = grid_border, part = "body")
    ft <- flextable::padding(ft, padding = 0, part = "body")
    ft <- flextable::fontsize(ft, size = 8, part = "body")
    ft <- flextable::line_spacing(ft, space = 0.1, part = "body")
    ft <- flextable::bg(
        ft,
        i = header_rows,
        bg = as.character(ppt_cfg$detail_header_row_fill),
        part = "body"
    )
    ft <- flextable::fontsize(
        ft,
        i = header_rows,
        size = as.numeric(ppt_cfg$detail_header_font_size),
        part = "body"
    )
    ft <- flextable::color(
        ft,
        i = header_rows,
        color = as.character(ppt_cfg$detail_label_text_color),
        part = "body"
    )
    ft <- flextable::bold(ft, i = header_rows, bold = TRUE, part = "body")
    ft <- flextable::align(ft, i = header_rows, align = "center", part = "body")
    ft <- flextable::valign(ft, i = header_rows, valign = "center", part = "body")
    ft <- flextable::line_spacing(ft, i = header_rows, space = 1, part = "body")
    ft <- flextable::bg(
        ft,
        i = label_rows,
        bg = as.character(ppt_cfg$detail_label_row_fill),
        part = "body"
    )
    ft <- flextable::width(ft, width = detail_layout$cell_w, unit = "in")
    ft <- flextable::height(ft, i = header_rows, height = detail_layout$header_row_h, part = "body", unit = "in")
    ft <- flextable::height(ft, i = label_rows, height = detail_layout$label_row_h, part = "body", unit = "in")
    ft <- flextable::height(ft, i = plot_rows, height = detail_layout$plot_row_h, part = "body", unit = "in")

    ph_with(
        ppt,
        value = ft,
        location = ph_location(
            left = detail_layout$left,
            top = detail_layout$top,
            width = detail_layout$width,
            height = detail_layout$height
        )
    )
}

add_detail_label <- function(ppt, label, direction, location, ppt_cfg) {
    marker <- "\u2B24"
    label_body <- label
    if (startsWith(label_body, marker)) {
        label_body <- trimws(substr(label_body, nchar(marker) + 1L, nchar(label_body)))
    }

    label_text <- officer::fpar(
        officer::ftext(
            marker,
            officer::fp_text(
                color = resolve_detail_marker_color(direction, ppt_cfg),
                font.size = as.numeric(ppt_cfg$detail_label_font_size),
                bold = TRUE
            )
        ),
        officer::ftext(
            paste0(" ", label_body),
            officer::fp_text(
                color = as.character(ppt_cfg$detail_label_text_color),
                font.size = as.numeric(ppt_cfg$detail_label_font_size)
            )
        ),
        fp_p = officer::fp_par(text.align = "center")
    )

    ph_with(
        ppt,
        value = label_text,
        location = ph_location(
            left = location$label_left,
            top = location$label_top,
            width = location$label_w,
            height = location$label_h,
            bg = "transparent"
        )
    )
}

count_detail_group_wafers <- function(dt, groups) {
    if (!all(c("GROUP", "ROOTID") %in% names(dt))) {
        return(NA_integer_)
    }
    group_vals <- normalize_group_vector(groups)
    if (length(group_vals) == 0L) {
        return(NA_integer_)
    }
    dt_i <- data.table::as.data.table(dt)
    as.integer(data.table::uniqueN(dt_i[GROUP %in% group_vals, ROOTID]))
}

format_detail_group_legend_label <- function(groups, role, wafer_count) {
    group_label <- format_ppt_context_value(groups)
    role_label <- toupper(as.character(role)[1])
    count_label <- if (is.na(wafer_count)) {
        "N/A"
    } else {
        paste0(wafer_count, "\uB9E4")
    }
    paste0(group_label, " (", role_label, ", ", count_label, ")")
}

build_detail_group_legend_items <- function(dt, plot_groups, ppt_cfg) {
    list(
        list(
            label = format_detail_group_legend_label(
                plot_groups$ref,
                "REF",
                count_detail_group_wafers(dt, plot_groups$ref)
            ),
            color = as.character(ppt_cfg$radius_ref_color)
        ),
        list(
            label = format_detail_group_legend_label(
                plot_groups$tgt,
                "TARGET",
                count_detail_group_wafers(dt, plot_groups$tgt)
            ),
            color = as.character(ppt_cfg$radius_tgt_color)
        )
    )
}

estimate_detail_group_legend_width <- function(items, gap_text, font_size, max_width) {
    item_text <- vapply(items, function(item) paste0("\u25CF ", item$label), character(1))
    full_text <- paste(item_text, collapse = gap_text)
    char_count <- nchar(full_text, type = "width", allowNA = FALSE, keepNA = FALSE)
    estimated_width <- 0.25 + (char_count * font_size * 0.0075)
    min(max_width, max(1.20, estimated_width))
}

add_detail_group_legend <- function(ppt, detail_layout, dt, plot_groups, ppt_cfg) {
    if (!isTRUE(ppt_cfg$detail_legend_show)) {
        return(ppt)
    }

    items <- build_detail_group_legend_items(dt, plot_groups, ppt_cfg)
    marker <- "\u25CF"
    gap_text <- as.character(ppt_cfg$detail_legend_gap_spaces)[1]
    if (is.na(gap_text)) {
        gap_text <- "    "
    }
    font_size <- as.numeric(ppt_cfg$detail_legend_font_size)
    if (!is.finite(font_size)) {
        font_size <- 10
    }
    legend_width <- estimate_detail_group_legend_width(items, gap_text, font_size, detail_layout$width)
    legend_left <- detail_layout$left + ((detail_layout$width - legend_width) / 2)
    legend_runs <- list()

    for (i in seq_along(items)) {
        item <- items[[i]]
        if (i > 1L) {
            legend_runs <- c(
                legend_runs,
                list(officer::ftext(gap_text, officer::fp_text(color = "#333333", font.size = font_size)))
            )
        }
        legend_runs <- c(
            legend_runs,
            list(officer::ftext(
                paste0(marker, " ", item$label),
                officer::fp_text(color = item$color, font.size = font_size, bold = TRUE)
            ))
        )
    }

    legend_text <- do.call(
        officer::fpar,
        c(legend_runs, list(fp_p = officer::fp_par(text.align = "center")))
    )

    ph_with(
        ppt,
        value = legend_text,
        location = ph_location(
            left = legend_left,
            top = detail_layout$bottom + as.numeric(ppt_cfg$detail_legend_top_offset),
            width = legend_width,
            height = as.numeric(ppt_cfg$detail_legend_height),
            bg = "transparent"
        )
    )
}

get_goobae_columns <- function() {
    c("GOOBAE_Category1", "GOOBAE_Category2", "GOOBAE_NAME", "GOOBAE_ORDER")
}

select_goobae_candidate_dt <- function(result_dt, prepared = FALSE) {
    dt <- if (isTRUE(prepared)) {
        data.table::copy(data.table::as.data.table(result_dt))
    } else {
        prepare_ppt_result_dt(result_dt)
    }
    required_cols <- c("MSR", get_goobae_columns())
    missing_cols <- setdiff(required_cols, names(dt))
    if (length(missing_cols) > 0L) {
        return(dt[0])
    }

    for (goobae_col in get_goobae_columns()) {
        dt[, (goobae_col) := clean_ppt_text_value(get(goobae_col))]
    }
    dt[, goobae_order := suppressWarnings(as.numeric(GOOBAE_ORDER))]

    include <- nzchar(clean_ppt_text_value(dt$MSR)) &
        nzchar(dt$GOOBAE_Category1) &
        nzchar(dt$GOOBAE_Category2) &
        nzchar(dt$GOOBAE_NAME) &
        is.finite(dt$goobae_order)

    out <- dt[include]
    if (nrow(out) == 0L) {
        return(out)
    }

    group_order_dt <- out[
        ,
        .(goobae_group_order = min(ppt_row_order, na.rm = TRUE)),
        by = .(GOOBAE_Category1, GOOBAE_Category2)
    ]
    out <- merge(
        out,
        group_order_dt,
        by = c("GOOBAE_Category1", "GOOBAE_Category2"),
        all.x = TRUE,
        sort = FALSE
    )
    data.table::setorderv(out, c("goobae_group_order", "goobae_order", "MSR"), na.last = TRUE)
    out[]
}

build_goobae_group_index <- function(goobae_dt) {
    if (nrow(goobae_dt) == 0L) {
        return(data.table::data.table(
            GOOBAE_Category1 = character(),
            GOOBAE_Category2 = character(),
            goobae_group_order = numeric(),
            goobae_group_index = integer()
        ))
    }

    group_dt <- unique(goobae_dt[, .(GOOBAE_Category1, GOOBAE_Category2, goobae_group_order)])
    data.table::setorderv(group_dt, c("goobae_group_order", "GOOBAE_Category1", "GOOBAE_Category2"))
    group_dt[, goobae_group_index := seq_len(.N)]
    group_dt[]
}

split_goobae_group_pages <- function(goobae_group_dt, slots_per_slide) {
    slots <- max(1L, as.integer(slots_per_slide))
    if (nrow(goobae_group_dt) == 0L) {
        return(list())
    }
    split(
        goobae_group_dt,
        ceiling(seq_len(nrow(goobae_group_dt)) / slots)
    )
}

calculate_goobae_plot_layout <- function(ppt_cfg, slots_per_slide = NULL) {
    slots <- if (is.null(slots_per_slide)) {
        suppressWarnings(as.integer(ppt_cfg$goobae_slots_per_slide)[1])
    } else {
        suppressWarnings(as.integer(slots_per_slide)[1])
    }
    if (!is.finite(slots) || slots < 1L) {
        slots <- 12L
    }

    slide_w <- resolve_ppt_config_numeric(ppt_cfg, "slide_width", 13.33)
    slide_h <- resolve_ppt_config_numeric(ppt_cfg, "slide_height", 7.50)
    margin_top <- resolve_ppt_config_numeric(ppt_cfg, "margin_top", 1.68)
    margin_left <- resolve_ppt_config_numeric(ppt_cfg, "margin_left", 0.32)
    margin_right <- resolve_ppt_config_numeric(ppt_cfg, "margin_right", 0.32)
    margin_bottom <- resolve_ppt_config_numeric(ppt_cfg, "margin_bottom", 0.50)
    cat1_h <- resolve_ppt_config_numeric(ppt_cfg, "goobae_category1_header_height", 0.32)
    cat2_h <- resolve_ppt_config_numeric(ppt_cfg, "goobae_category2_header_height", 0.28)
    pad_x <- max(0, resolve_ppt_config_numeric(ppt_cfg, "goobae_plot_padding_x", 0.05))
    pad_y <- max(0, resolve_ppt_config_numeric(ppt_cfg, "goobae_plot_padding_y", 0.06))

    content_w <- slide_w - margin_left - margin_right
    content_h <- slide_h - margin_top - margin_bottom
    slot_w <- content_w / slots
    plot_row_h <- content_h - cat1_h - cat2_h
    plot_w <- slot_w - (2 * pad_x)
    plot_h <- plot_row_h - (2 * pad_y)

    layout_vals <- c(
        slide_w, slide_h, margin_top, margin_left, margin_right, margin_bottom,
        content_w, content_h, slot_w, cat1_h, cat2_h, plot_row_h, plot_w, plot_h
    )
    if (any(!is.finite(layout_vals)) || content_w <= 0 || content_h <= 0 ||
        slot_w <= 0 || cat1_h <= 0 || cat2_h <= 0 || plot_row_h <= 0 ||
        plot_w <= 0 || plot_h <= 0) {
        stop("Invalid GOOBAE plot layout. Check PPT_CONFIG slide size, margins, headers, slots, and padding.")
    }

    list(
        slots_per_slide = slots,
        table_nrow = 3L,
        left = margin_left,
        top = margin_top,
        right = slide_w - margin_right,
        bottom = slide_h - margin_bottom,
        width = content_w,
        height = content_h,
        slot_w = slot_w,
        category1_header_h = cat1_h,
        category2_header_h = cat2_h,
        plot_row_h = plot_row_h,
        plot_padding_x = pad_x,
        plot_padding_y = pad_y,
        plot_top = margin_top + cat1_h + cat2_h,
        plot_w = plot_w,
        plot_h = plot_h
    )
}

goobae_layout_for_index <- function(goobae_layout, index) {
    slot_idx <- as.integer(index) - 1L
    slot_left <- goobae_layout$left + (slot_idx * goobae_layout$slot_w)
    list(
        slot_left = slot_left,
        slot_top = goobae_layout$top,
        slot_w = goobae_layout$slot_w,
        slot_h = goobae_layout$height,
        plot_left = slot_left + goobae_layout$plot_padding_x,
        plot_top = goobae_layout$plot_top + goobae_layout$plot_padding_y,
        plot_w = goobae_layout$plot_w,
        plot_h = goobae_layout$plot_h
    )
}

add_goobae_grid_table <- function(ppt, goobae_layout, page_groups, ppt_cfg) {
    slot_count <- goobae_layout$slots_per_slide
    cat1_values <- rep(" ", slot_count)
    cat2_values <- rep(" ", slot_count)
    if (nrow(page_groups) > 0L) {
        fill_count <- min(nrow(page_groups), slot_count)
        cat1_values[seq_len(fill_count)] <- clean_ppt_text_value(page_groups$GOOBAE_Category1[seq_len(fill_count)])
        cat2_values[seq_len(fill_count)] <- clean_ppt_text_value(page_groups$GOOBAE_Category2[seq_len(fill_count)])
    }
    cat1_values[!nzchar(cat1_values)] <- " "
    cat2_values[!nzchar(cat2_values)] <- " "

    table_data <- as.data.frame(
        rbind(cat1_values, cat2_values, rep(" ", slot_count)),
        stringsAsFactors = FALSE
    )
    names(table_data) <- paste0("C", seq_len(slot_count))

    grid_border <- officer::fp_border(
        color = as.character(ppt_cfg$detail_table_border_color),
        width = as.numeric(ppt_cfg$detail_table_border_width)
    )

    ft <- flextable::flextable(table_data)
    ft <- flextable::delete_part(ft, part = "header")

    run_lengths <- rle(cat1_values)
    run_end <- cumsum(run_lengths$lengths)
    run_start <- run_end - run_lengths$lengths + 1L
    for (run_idx in seq_along(run_lengths$lengths)) {
        if (run_lengths$lengths[[run_idx]] > 1L) {
            ft <- flextable::merge_at(
                ft,
                i = 1L,
                j = run_start[[run_idx]]:run_end[[run_idx]],
                part = "body"
            )
        }
    }

    ft <- flextable::border_remove(ft)
    ft <- flextable::border(ft, border = grid_border, part = "body")
    ft <- flextable::padding(ft, padding = 0, part = "body")
    ft <- flextable::font(ft, fontname = "Arial", part = "body")
    ft <- flextable::fontsize(
        ft,
        size = resolve_ppt_config_numeric(ppt_cfg, "goobae_header_font_size", 8.5),
        part = "body"
    )
    ft <- flextable::line_spacing(ft, space = 0.1, part = "body")
    ft <- flextable::align(ft, align = "center", part = "body")
    ft <- flextable::valign(ft, valign = "center", part = "body")
    ft <- flextable::align(ft, i = 1:2, align = "center", part = "body")
    ft <- flextable::valign(ft, i = 1:2, valign = "center", part = "body")
    ft <- flextable::bg(ft, i = 1L, bg = as.character(ppt_cfg$detail_header_row_fill), part = "body")
    ft <- flextable::bg(ft, i = 2L, bg = as.character(ppt_cfg$detail_label_row_fill), part = "body")
    ft <- flextable::color(ft, i = 1:2, color = as.character(ppt_cfg$detail_label_text_color), part = "body")
    ft <- flextable::bold(ft, i = 1L, bold = TRUE, part = "body")
    ft <- flextable::fontsize(ft, i = 3L, size = 4, part = "body")
    ft <- flextable::width(ft, width = goobae_layout$slot_w, unit = "in")
    ft <- flextable::height(ft, i = 1L, height = goobae_layout$category1_header_h, part = "body", unit = "in")
    ft <- flextable::height(ft, i = 2L, height = goobae_layout$category2_header_h, part = "body", unit = "in")
    ft <- flextable::height(ft, i = 3L, height = goobae_layout$plot_row_h, part = "body", unit = "in")

    ph_with(
        ppt,
        value = ft,
        location = ph_location(
            left = goobae_layout$left,
            top = goobae_layout$top,
            width = goobae_layout$width,
            height = goobae_layout$height
        )
    )
}

get_goobae_group_rows <- function(goobae_dt, group_row) {
    out <- goobae_dt[
        GOOBAE_Category1 == group_row$GOOBAE_Category1[[1]] &
            GOOBAE_Category2 == group_row$GOOBAE_Category2[[1]]
    ]
    data.table::setorderv(out, c("goobae_order", "MSR"), na.last = TRUE)
    out[]
}

get_goobae_y_label_dt <- function(goobae_dt, page_groups) {
    if (nrow(page_groups) == 0L) {
        return(data.table::data.table(GOOBAE_NAME = character(), goobae_order = numeric()))
    }
    label_dt <- get_goobae_group_rows(goobae_dt, page_groups[1L])
    unique(label_dt[, .(GOOBAE_NAME, goobae_order)])[order(goobae_order)]
}

get_goobae_y_limits <- function(label_dt) {
    orders <- suppressWarnings(as.numeric(label_dt$goobae_order))
    orders <- orders[is.finite(orders)]
    if (length(orders) == 0L) {
        return(c(0.5, 1.5))
    }
    c(min(orders) - 0.5, max(orders) + 0.5)
}

get_goobae_y_label_max_count <- function(plot_height_in, ppt_cfg) {
    min_gap <- resolve_ppt_config_numeric(ppt_cfg, "goobae_y_label_min_gap", 0.18)
    if (!is.finite(min_gap) || min_gap <= 0) {
        min_gap <- 0.18
    }

    plot_height <- suppressWarnings(as.numeric(plot_height_in))
    if (!is.finite(plot_height) || plot_height <= 0) {
        plot_height <- 4.6
    }

    max(2L, as.integer(floor(plot_height / min_gap) + 1L))
}

select_goobae_visible_y_label_dt <- function(label_dt, plot_height_in, ppt_cfg) {
    if (nrow(label_dt) == 0L) {
        return(label_dt)
    }

    max_count <- get_goobae_y_label_max_count(plot_height_in, ppt_cfg)
    if (nrow(label_dt) <= max_count) {
        return(label_dt)
    }

    keep_idx <- unique(as.integer(round(seq(1, nrow(label_dt), length.out = max_count))))
    keep_idx <- sort(unique(pmax(1L, pmin(nrow(label_dt), keep_idx))))
    label_dt[keep_idx]
}

build_goobae_y_label_strip_plot <- function(label_dt, y_limits, ppt_cfg) {
    label_plot_dt <- data.table::copy(label_dt)
    label_plot_dt[, goobae_order := suppressWarnings(as.numeric(goobae_order))]
    label_plot_dt <- label_plot_dt[is.finite(goobae_order)]
    if (nrow(label_plot_dt) == 0L) {
        return(NULL)
    }
    label_plot_dt[, label_x := 1]

    font_size <- resolve_ppt_config_numeric(ppt_cfg, "goobae_y_label_font_size", 4.0)
    axis_text_size <- resolve_ppt_config_numeric(ppt_cfg, "goobae_axis_text_size", 4.8)
    label_breaks <- sort(unique(label_plot_dt$goobae_order))

    ggplot2::ggplot(
        label_plot_dt,
        ggplot2::aes(x = label_x, y = goobae_order, label = GOOBAE_NAME)
    ) +
        ggplot2::geom_text(
            hjust = 1,
            vjust = 0.5,
            size = font_size / ggplot2::.pt,
            color = as.character(ppt_cfg$detail_label_text_color)
        ) +
        ggplot2::scale_x_continuous(
            limits = c(0, 1),
            breaks = 0.5,
            labels = "0.0",
            expand = c(0, 0)
        ) +
        ggplot2::scale_y_continuous(
            limits = y_limits,
            breaks = label_breaks,
            expand = c(0, 0)
        ) +
        ggplot2::labs(x = NULL, y = NULL) +
        ggplot2::theme_light(base_size = 7) +
        ggplot2::theme(
            axis.text.x = ggplot2::element_text(size = axis_text_size, color = "transparent"),
            axis.ticks.x = ggplot2::element_line(color = "transparent"),
            axis.text.y = ggplot2::element_blank(),
            axis.ticks.y = ggplot2::element_blank(),
            axis.title = ggplot2::element_blank(),
            panel.grid = ggplot2::element_blank(),
            panel.border = ggplot2::element_blank(),
            panel.background = ggplot2::element_rect(fill = "transparent", color = NA),
            plot.background = ggplot2::element_rect(fill = "transparent", color = NA),
            plot.margin = ggplot2::margin(t = 1, r = 0, b = 1, l = 0)
        )
}

add_goobae_y_label_strip <- function(
    ppt,
    goobae_layout,
    label_dt,
    ppt_cfg,
    y_limits,
    temp_dir = tempdir()
) {
    if (nrow(label_dt) == 0L) {
        return(ppt)
    }

    label_width <- resolve_ppt_config_numeric(ppt_cfg, "goobae_y_label_width", 0.34)
    label_gap <- resolve_ppt_config_numeric(ppt_cfg, "goobae_y_label_gap", 0.02)
    label_left <- max(0.01, goobae_layout$left - label_gap - label_width)
    first_plot_left <- goobae_layout$left + goobae_layout$plot_padding_x
    label_width <- max(0.05, min(label_width, first_plot_left - label_gap - label_left))
    y_min <- min(y_limits)
    y_max <- max(y_limits)

    if (y_max <= y_min) {
        return(ppt)
    }

    label_plot <- build_goobae_y_label_strip_plot(label_dt, y_limits, ppt_cfg)
    if (is.null(label_plot)) {
        return(ppt)
    }

    label_png <- tempfile("goobae_y_label_strip_", tmpdir = temp_dir, fileext = ".png")
    ggplot2::ggsave(
        filename = label_png,
        plot = label_plot,
        width = label_width,
        height = goobae_layout$plot_h,
        units = "in",
        dpi = as.numeric(ppt_cfg$plot_dpi),
        bg = "transparent"
    )

    ph_with(
        ppt,
        external_img(label_png),
        location = ph_location(
            left = label_left,
            top = goobae_layout$plot_top + goobae_layout$plot_padding_y,
            width = label_width,
            height = goobae_layout$plot_h
        )
    )
}

mean_finite_value <- function(x) {
    values <- suppressWarnings(as.numeric(x))
    values <- values[is.finite(values)]
    if (length(values) == 0L) {
        return(NA_real_)
    }
    mean(values)
}

build_goobae_plot_data <- function(dt, group_rows, ref_groups, tgt_groups) {
    if (nrow(group_rows) == 0L) {
        return(data.table::data.table(
            Side = character(),
            value = numeric(),
            GOOBAE_NAME = character(),
            goobae_order = numeric()
        ))
    }

    raw_dt <- data.table::as.data.table(dt)
    has_group <- "GROUP" %in% names(raw_dt)
    ref_row_idx <- integer()
    tgt_row_idx <- integer()
    if (has_group) {
        group_values <- raw_dt[["GROUP"]]
        ref_row_idx <- which(group_values %in% ref_groups)
        tgt_row_idx <- which(group_values %in% tgt_groups)
    }
    rows <- vector("list", nrow(group_rows))

    for (i in seq_len(nrow(group_rows))) {
        msr <- as.character(group_rows$MSR[i])
        ref_mean <- NA_real_
        tgt_mean <- NA_real_
        if (has_group && msr %in% names(raw_dt)) {
            msr_values <- raw_dt[[msr]]
            ref_mean <- mean_finite_value(msr_values[ref_row_idx])
            tgt_mean <- mean_finite_value(msr_values[tgt_row_idx])
        }

        rows[[i]] <- data.table::data.table(
            Side = c("REF", "TARGET"),
            value = c(ref_mean, tgt_mean),
            GOOBAE_NAME = as.character(group_rows$GOOBAE_NAME[i]),
            goobae_order = as.numeric(group_rows$goobae_order[i])
        )
    }

    out <- data.table::rbindlist(rows, fill = TRUE)
    out[, Side := factor(Side, levels = c("REF", "TARGET"))]
    out[]
}

build_goobae_trend_plot <- function(plot_dt, y_limits, ppt_cfg, y_breaks = NULL) {
    finite_dt <- plot_dt[is.finite(value) & is.finite(goobae_order)]
    if (nrow(finite_dt) == 0L) {
        return(build_placeholder_plot(
            "GOOBAE",
            "No finite REF/TARGET values"
        ))
    }

    data.table::setorderv(finite_dt, c("Side", "goobae_order"))
    color_values <- c(
        REF = as.character(ppt_cfg$radius_ref_color),
        TARGET = as.character(ppt_cfg$radius_tgt_color)
    )
    x_breaks <- pretty(finite_dt$value, n = 3)
    x_breaks <- x_breaks[is.finite(x_breaks)]
    if (length(x_breaks) == 0L) {
        x_breaks <- NULL
    }
    if (is.null(y_breaks)) {
        y_breaks <- sort(unique(plot_dt$goobae_order[is.finite(plot_dt$goobae_order)]))
    } else {
        y_breaks <- suppressWarnings(as.numeric(y_breaks))
        y_breaks <- sort(unique(y_breaks[is.finite(y_breaks)]))
    }

    show_points <- resolve_ppt_config_logical(ppt_cfg, "goobae_point_enabled", FALSE)
    plot <- ggplot2::ggplot(
        finite_dt,
        ggplot2::aes(x = value, y = goobae_order, color = Side, group = Side)
    ) +
        ggplot2::geom_path(linewidth = resolve_ppt_config_numeric(ppt_cfg, "goobae_line_size", 0.70), na.rm = TRUE)
    if (show_points) {
        plot <- plot +
            ggplot2::geom_point(size = resolve_ppt_config_numeric(ppt_cfg, "goobae_point_size", 1.2), na.rm = TRUE)
    }

    plot +
        ggplot2::scale_color_manual(values = color_values, guide = "none") +
        ggplot2::scale_y_continuous(
            limits = y_limits,
            breaks = y_breaks,
            expand = c(0, 0)
        ) +
        ggplot2::scale_x_continuous(breaks = x_breaks) +
        ggplot2::labs(x = NULL, y = NULL) +
        ggplot2::theme_light(base_size = 7) +
        ggplot2::theme(
            axis.text.x = ggplot2::element_text(
                size = resolve_ppt_config_numeric(ppt_cfg, "goobae_axis_text_size", 4.8),
                color = "#555555"
            ),
            axis.text.y = ggplot2::element_blank(),
            axis.ticks.y = ggplot2::element_blank(),
            axis.title = ggplot2::element_blank(),
            panel.grid.major.y = ggplot2::element_line(color = "#EDEDED", linewidth = 0.15),
            panel.grid.major.x = ggplot2::element_line(color = "#F5F5F5", linewidth = 0.15),
            panel.grid.minor = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(color = "#CFCFCF", fill = NA, linewidth = 0.25),
            plot.margin = ggplot2::margin(t = 1, r = 1, b = 1, l = 1)
        )
}

save_goobae_plot_png <- function(plot, png_path, width_in, height_in, dpi) {
    ggplot2::ggsave(
        png_path,
        plot = plot,
        width = width_in,
        height = height_in,
        units = "in",
        dpi = dpi
    )
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

with_alpha <- function(color, alpha) {
    alpha_val <- suppressWarnings(as.numeric(alpha)[1])
    if (!is.finite(alpha_val)) {
        alpha_val <- 1
    }
    alpha_val <- min(max(alpha_val, 0), 1)
    grDevices::adjustcolor(as.character(color)[1], alpha.f = alpha_val)
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

    side_fill_values <- c(
        REF = with_alpha(ppt_cfg$radius_ref_color, ppt_cfg$radius_scatter_alpha),
        TARGET = with_alpha(ppt_cfg$radius_tgt_color, ppt_cfg$radius_scatter_alpha)
    )

    p <- ggplot2::ggplot(side_dt, ggplot2::aes(x = Radius, y = value, fill = Side)) +
        ggplot2::geom_point(
            shape = 21,
            color = with_alpha(
                ppt_cfg$radius_scatter_border_color,
                ppt_cfg$radius_scatter_border_alpha
            ),
            size = as.numeric(ppt_cfg$radius_scatter_size),
            stroke = as.numeric(ppt_cfg$radius_scatter_border_width)
        ) +
        ggplot2::labs(title = NULL, x = NULL, y = NULL) +
        ggplot2::facet_grid(. ~ Side, scales = "free_x", space = "free_x") +
        ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.04, 0.04))) +
        ggplot2::scale_fill_manual(values = side_fill_values, guide = "none")

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

    y_expand_mult <- suppressWarnings(as.numeric(ppt_cfg$rootid_avg_y_expand_mult)[1])
    if (!is.finite(y_expand_mult) || y_expand_mult < 0) {
        y_expand_mult <- 0.16
    }

    p <- ggplot2::ggplot(avg_dt, ggplot2::aes(x = axis_label, y = good_avg, fill = GROUP)) +
        ggplot2::geom_point(
            shape = 21,
            size = as.numeric(ppt_cfg$rootid_avg_point_size),
            color = with_alpha(
                ppt_cfg$rootid_avg_point_border_color,
                ppt_cfg$rootid_avg_point_border_alpha
            ),
            stroke = as.numeric(ppt_cfg$rootid_avg_point_border_width)
        ) +
        ggplot2::scale_x_discrete(drop = FALSE, expand = ggplot2::expansion(add = 0.8)) +
        ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(y_expand_mult, y_expand_mult))) +
        ggplot2::labs(title = NULL, x = NULL, y = NULL) +
        ggplot2::scale_fill_manual(values = group_color_values, guide = "none")

    apply_compact_panel_theme(p, show_title = FALSE, show_x_text = FALSE, keep_y_text = TRUE) +
        ggplot2::theme(
            panel.border = ggplot2::element_rect(color = "#CFCFCF", fill = NA, linewidth = 0.25),
            axis.text.y = ggplot2::element_text(size = as.numeric(ppt_cfg$rootid_avg_axis_text_size)),
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
    sigma_threshold = NULL,
    ppt_config = NULL
) {
    require(officer)
    require(flextable)
    require(ggplot2)
    require(data.table)

    log_msg("Generating PPT Automation...")
    ppt_cfg <- resolve_ppt_config(ppt_config = ppt_config)
    result_dt <- prepare_ppt_result_dt(result_dt)

    rows_per_slide <- max(1L, as.integer(ppt_cfg$summary_rows_per_slide))
    grid_ncol <- max(1L, as.integer(ppt_cfg$detail_grid_ncol))
    grid_nrow <- max(1L, as.integer(ppt_cfg$detail_grid_nrow))
    max_detail_slots <- max(1L, grid_ncol * grid_nrow)
    detail_slide_capacity <- max_detail_slots
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

    common_bullet_context <- list(
        ref = plot_groups$ref,
        target = plot_groups$tgt,
        sigma_threshold = sigma_threshold,
        detail_top_n = detail_slide_capacity,
        detail_slide_capacity = detail_slide_capacity,
        summary_category_columns = paste(ppt_cfg$summary_category_columns, collapse = " > "),
        generated_at = timestamp_str
    )

    template_path <- resolve_ppt_template_path(ppt_cfg)
    if (file.exists(template_path)) {
        ppt <- read_pptx(template_path)
    } else {
        ppt <- read_pptx()
    }
    ppt_master <- resolve_ppt_config_string(ppt_cfg$ppt_master, "Office Theme")
    summary_slide_layout <- resolve_ppt_config_string(ppt_cfg$summary_slide_layout, "Title and Content")
    detail_slide_layout <- resolve_ppt_config_string(ppt_cfg$detail_slide_layout, "Title Only")
    goobae_slide_layout <- resolve_ppt_config_string(ppt_cfg$goobae_slide_layout, detail_slide_layout)
    temp_dir <- tempfile("drb_ppt_assets_")
    if (!dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)) {
        stop("Could not create PPT temporary asset directory: ", temp_dir)
    }
    on.exit(unlink(temp_dir, recursive = TRUE, force = TRUE), add = TRUE)

    # --------------- 1. Summary Slide ---------------
    summary_dt <- select_summary_candidate_dt(
        result_dt,
        ppt_cfg$summary_category_columns,
        sigma_threshold,
        prepared = TRUE
    )

    if (nrow(summary_dt) > 0) {
        sum_disp <- build_summary_display_dt(
            summary_dt,
            ppt_cfg$summary_category_columns,
            ref_group = plot_groups$ref,
            target_group = plot_groups$tgt
        )
        num_slides <- ceiling(nrow(sum_disp) / rows_per_slide)

        for (i in seq_len(num_slides)) {
            start_row <- (i - 1L) * rows_per_slide + 1L
            end_row <- min(i * rows_per_slide, nrow(sum_disp))
            sub_sum <- sum_disp[start_row:end_row]

            ppt <- add_slide(ppt, layout = summary_slide_layout, master = ppt_master)
            ppt <- add_ppt_summary_slide_header(
                ppt,
                ppt_cfg,
                bullets = resolve_ppt_slide_bullets(
                    ppt_cfg,
                    "summary_slide_bullets",
                    c(
                        common_bullet_context,
                        list(
                            summary_page = i,
                            summary_total_pages = num_slides,
                            flagged_count = sum(result_dt$ppt_flagged),
                            selected_count = nrow(summary_dt)
                        )
                    )
                )
            )

            ft <- style_summary_flextable(sub_sum, ppt_cfg, sigma_threshold)

            ppt <- ph_with(ppt, value = ft, location = summary_table_location(ppt_cfg))
        }
    } else {
        ppt <- add_slide(ppt, layout = summary_slide_layout, master = ppt_master)
        ppt <- add_ppt_summary_slide_header(
            ppt,
            ppt_cfg,
            bullets = resolve_ppt_slide_bullets(
                ppt_cfg,
                "summary_slide_bullets",
                c(
                    common_bullet_context,
                    list(
                        summary_page = 1L,
                        summary_total_pages = 1L,
                        flagged_count = sum(result_dt$ppt_flagged),
                        selected_count = 0L
                    )
                )
            )
        )
        ppt <- ph_with(ppt, value = "No summary MSR selected by PPT_CONFIG.", location = summary_table_location(ppt_cfg))
    }

    # --------------- 2. GOOBAE Slides ---------------
    if (isTRUE(ppt_cfg$goobae_slide_enabled)) {
        goobae_dt <- select_goobae_candidate_dt(result_dt, prepared = TRUE)
        goobae_group_dt <- build_goobae_group_index(goobae_dt)

        if (nrow(goobae_group_dt) > 0L) {
            goobae_layout <- calculate_goobae_plot_layout(ppt_cfg)
            goobae_pages <- split_goobae_group_pages(
                goobae_group_dt,
                goobae_layout$slots_per_slide
            )
            goobae_total_pages <- length(goobae_pages)

            for (goobae_page_index in seq_along(goobae_pages)) {
                page_groups <- data.table::as.data.table(goobae_pages[[goobae_page_index]])
                page_start <- min(page_groups$goobae_group_index)
                page_end <- max(page_groups$goobae_group_index)

                log_msg(paste0(
                    "Generating GOOBAE slide (",
                    goobae_page_index,
                    "/",
                    goobae_total_pages,
                    ")"
                ))

                goobae_slide_bullets <- resolve_ppt_slide_bullets(
                    ppt_cfg,
                    "goobae_slide_bullets",
                    c(
                        common_bullet_context,
                        list(
                            goobae_page = goobae_page_index,
                            goobae_total_pages = goobae_total_pages,
                            goobae_group_count = nrow(goobae_group_dt),
                            goobae_selected_start = page_start,
                            goobae_selected_end = page_end
                        )
                    )
                )

                ppt <- add_slide(ppt, layout = goobae_slide_layout, master = ppt_master)
                if (resolve_ppt_header_mode(ppt_cfg) != "template_placeholder") {
                    ppt <- add_ppt_slide_header(
                        ppt,
                        ppt_cfg,
                        bullets = goobae_slide_bullets
                    )
                }

                ppt <- add_goobae_grid_table(
                    ppt = ppt,
                    goobae_layout = goobae_layout,
                    page_groups = page_groups,
                    ppt_cfg = ppt_cfg
                )

                label_dt <- get_goobae_y_label_dt(goobae_dt, page_groups)
                y_limits <- get_goobae_y_limits(label_dt)
                visible_label_dt <- select_goobae_visible_y_label_dt(
                    label_dt = label_dt,
                    plot_height_in = goobae_layout$plot_h,
                    ppt_cfg = ppt_cfg
                )
                ppt <- add_goobae_y_label_strip(
                    ppt = ppt,
                    goobae_layout = goobae_layout,
                    label_dt = visible_label_dt,
                    ppt_cfg = ppt_cfg,
                    y_limits = y_limits,
                    temp_dir = temp_dir
                )

                for (slot_index in seq_len(nrow(page_groups))) {
                    if (slot_index > goobae_layout$slots_per_slide) {
                        break
                    }
                    group_row <- page_groups[slot_index]
                    group_rows <- get_goobae_group_rows(goobae_dt, group_row)
                    plot_dt <- build_goobae_plot_data(
                        dt = dt,
                        group_rows = group_rows,
                        ref_groups = plot_groups$ref,
                        tgt_groups = plot_groups$tgt
                    )
                    goobae_plot <- build_goobae_trend_plot(
                        plot_dt = plot_dt,
                        y_limits = y_limits,
                        ppt_cfg = ppt_cfg,
                        y_breaks = visible_label_dt$goobae_order
                    )

                    safe_group <- sanitize_file_token(paste(
                        group_row$GOOBAE_Category1,
                        group_row$GOOBAE_Category2,
                        sep = "_"
                    ))
                    png_path <- file.path(
                        temp_dir,
                        paste0("goobae_", safe_group, "_", goobae_page_index, "_", slot_index, ".png")
                    )
                    slot_location <- goobae_layout_for_index(goobae_layout, slot_index)
                    save_goobae_plot_png(
                        plot = goobae_plot,
                        png_path = png_path,
                        width_in = slot_location$plot_w,
                        height_in = slot_location$plot_h,
                        dpi = as.numeric(ppt_cfg$plot_dpi)
                    )

                    ppt <- ph_with(
                        ppt,
                        external_img(png_path),
                        location = ph_location(
                            left = slot_location$plot_left,
                            top = slot_location$plot_top,
                            width = slot_location$plot_w,
                            height = slot_location$plot_h
                        )
                    )
                }

                ppt <- add_detail_group_legend(
                    ppt = ppt,
                    detail_layout = goobae_layout,
                    dt = dt,
                    plot_groups = plot_groups,
                    ppt_cfg = ppt_cfg
                )

                if (resolve_ppt_header_mode(ppt_cfg) == "template_placeholder") {
                    ppt <- add_ppt_slide_header(
                        ppt,
                        ppt_cfg,
                        bullets = goobae_slide_bullets
                    )
                }
            }
        } else {
            log_msg("No GOOBAE groups selected by GOOBAE metadata.")
        }
    }

    # --------------- 3. Detail Slides ---------------
    detail_dt <- select_ppt_candidate_dt(
        result_dt,
        ppt_cfg$detail_msr_selection_mode,
        "ppt_slide_required"
    )
    if (nrow(detail_dt) > 0L) {
        detail_dt <- add_detail_group_columns(detail_dt, ppt_cfg$detail_group_by)
        detail_group_list <- unique(detail_dt$ppt_detail_group_label)

        detail_layout <- calculate_detail_plot_layout(ppt_cfg, grid_ncol, grid_nrow)
        plot_w <- detail_layout$plot_w
        plot_h <- detail_layout$plot_h

        for (detail_group in detail_group_list) {
            sub_dt <- detail_dt[ppt_detail_group_label == detail_group]
            total_group_msrs <- nrow(sub_dt)
            total_pages <- ceiling(total_group_msrs / max_detail_slots)

            for (page_index in seq_len(total_pages)) {
                start_index <- (page_index - 1L) * max_detail_slots + 1L
                end_index <- min(page_index * max_detail_slots, total_group_msrs)
                page_dt <- sub_dt[start_index:end_index]
                page_msrs <- page_dt$MSR
                page_msrs <- page_msrs[!is.na(page_msrs)]
                page_row_index <- match(page_msrs, page_dt$MSR)

                if (length(page_msrs) == 0L) {
                    next
                }

                log_msg(paste0(
                    "Generating detail slide for ",
                    ppt_cfg$detail_group_by,
                    ": ",
                    detail_group,
                    " (",
                    page_index,
                    "/",
                    total_pages,
                    ")"
                ))

                ppt <- add_slide(ppt, layout = detail_slide_layout, master = ppt_master)
                detail_header_label <- build_detail_header_label(
                    group_label = detail_group,
                    page_index = page_index,
                    total_pages = total_pages,
                    start_index = start_index,
                    end_index = end_index,
                    total_count = total_group_msrs
                )
                detail_slide_bullets <- resolve_ppt_slide_bullets(
                    ppt_cfg,
                    "detail_slide_bullets",
                    c(
                        common_bullet_context,
                        list(
                            category = detail_group,
                            category_msr_count = total_group_msrs,
                            detail_page = page_index,
                            detail_total_pages = total_pages,
                            detail_selected_start = start_index,
                            detail_selected_end = end_index
                        )
                    )
                )
                if (resolve_ppt_header_mode(ppt_cfg) != "template_placeholder") {
                    ppt <- add_ppt_slide_header(
                        ppt,
                        ppt_cfg,
                        bullets = detail_slide_bullets
                    )
                }
                ppt <- add_detail_grid_table(ppt, detail_layout, ppt_cfg, header_label = detail_header_label)

                index <- 1L
                for (page_position in seq_along(page_msrs)) {
                    msr <- page_msrs[[page_position]]
                    if (index > max_detail_slots) {
                        break
                    }
                    if (!msr %in% names(dt)) {
                        log_msg(paste0("[Warning] MSR column not found in raw dt; skipped: ", msr))
                        next
                    }

                    slot_location <- detail_layout_for_index(detail_layout, index)

                    msr_name_title <- as.character(msr)
                    msr_direction <- "Stable"
                    metadata_row <- page_row_index[[page_position]]
                    if ("ITEM_NAME" %in% names(page_dt)) {
                        item_name_i <- page_dt[["ITEM_NAME"]][metadata_row]
                        if (!is.na(item_name_i) && nzchar(as.character(item_name_i))) {
                            msr_name_title <- as.character(item_name_i)
                        }
                    }
                    if ("Direction" %in% names(page_dt)) {
                        direction_i <- page_dt[["Direction"]][metadata_row]
                        if (!is.na(direction_i) && nzchar(as.character(direction_i))) {
                            msr_direction <- as.character(direction_i)
                        }
                    }
                    msr_sigma_text <- ""
                    if ("Sigma_Score" %in% names(page_dt)) {
                        sigma_i <- page_dt[["Sigma_Score"]][metadata_row]
                        msr_sigma_text <- format_detail_sigma_text(sigma_i)
                    }

                    msr_label <- build_detail_label_text(
                        msr = msr,
                        item_name = msr_name_title,
                        show_field = ppt_cfg$detail_label_show_field
                    )
                    ppt <- add_detail_label(
                        ppt = ppt,
                        label = msr_label,
                        direction = msr_direction,
                        location = slot_location,
                        ppt_cfg = ppt_cfg
                    )

                    safe_msr <- sanitize_file_token(msr)
                    png_path <- file.path(temp_dir, paste0("plot_", safe_msr, "_", page_index, "_", index, ".png"))

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
                            title_text = NULL,
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
                        location = ph_location(
                            left = slot_location$plot_left,
                            top = slot_location$plot_top,
                            width = plot_w,
                            height = plot_h
                        )
                    )
                    ppt <- add_detail_sigma_box(
                        ppt = ppt,
                        sigma_text = msr_sigma_text,
                        location = slot_location,
                        ppt_cfg = ppt_cfg
                    )

                    index <- index + 1L
                }

                ppt <- add_detail_group_legend(
                    ppt = ppt,
                    detail_layout = detail_layout,
                    dt = dt,
                    plot_groups = plot_groups,
                    ppt_cfg = ppt_cfg
                )

                if (resolve_ppt_header_mode(ppt_cfg) == "template_placeholder") {
                    ppt <- add_ppt_slide_header(
                        ppt,
                        ppt_cfg,
                        bullets = detail_slide_bullets
                    )
                }
            }
        }
    } else {
        log_msg("No detail MSR selected by PPT_CONFIG.")
    }

    # --------------- 4. Save ---------------
    ppt_name <- paste0("sigma_summary_", timestamp_str, ".pptx")
    archive_path <- file.path(archive_dir, ppt_name)
    print(ppt, target = archive_path)

    res_path <- here::here("output", "sigma_summary_latest.pptx")
    print(ppt, target = res_path)

    log_msg("[PPT File] Saved Latest to: ./output/sigma_summary_latest.pptx")
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
            sigma_threshold = sigma_threshold,
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
