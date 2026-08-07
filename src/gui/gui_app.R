#' @title DRB Local GUI
#' @description Shiny-based option selection, Quick Preview, and existing pipeline launcher.

drb_gui_default_choice <- function(values, preferred) {
    values <- as.character(values)
    if (preferred %in% values) preferred else if (length(values) > 0L) values[[1L]] else character()
}

drb_gui_data_files <- function(data_dir) {
    if (!dir.exists(data_dir)) {
        return(character())
    }
    sort(list.files(data_dir, pattern = "[.]csv$", ignore.case = TRUE, full.names = FALSE))
}

load_drb_gui_ppt_base_config <- function(project_dir) {
    config_path <- file.path(project_dir, "config", "ppt_config.R")
    if (!file.exists(config_path)) {
        return(list())
    }
    config_env <- new.env(parent = baseenv())
    sys.source(config_path, envir = config_env)
    if (!exists("PPT_CONFIG", envir = config_env, inherits = FALSE)) {
        stop("config/ppt_config.R does not define PPT_CONFIG.")
    }
    config_value <- get("PPT_CONFIG", envir = config_env, inherits = FALSE)
    if (!is.list(config_value)) {
        stop("PPT_CONFIG must be a named list.")
    }
    config_value
}

detect_drb_gui_msr_columns <- function(raw_path, data_dir) {
    header_names <- names(read_csv_header(raw_path))
    msrinfo_path <- file.path(data_dir, "msrinfo.csv")
    if (file.exists(msrinfo_path)) {
        msrinfo_header <- names(read_csv_header(msrinfo_path))
        if ("FIELD" %in% msrinfo_header) {
            msr_info <- data.table::fread(msrinfo_path, select = "FIELD", showProgress = FALSE)
            configured <- trimws(as.character(msr_info$FIELD))
            configured <- configured[!is.na(configured) & nzchar(configured)]
            matched <- configured[configured %in% header_names]
            if (length(matched) > 0L) {
                return(unique(matched))
            }
        }
    }

    partid_index <- match("PARTID", header_names)
    if (!is.na(partid_index) && partid_index < length(header_names)) {
        return(header_names[seq.int(partid_index + 1L, length(header_names))])
    }
    character()
}

inspect_drb_gui_inputs <- function(data_dir, raw_filename, root_filename) {
    raw_path <- file.path(data_dir, basename(raw_filename))
    root_path <- file.path(data_dir, basename(root_filename))
    if (!file.exists(raw_path)) stop("Raw file not found: ", raw_path)
    if (!file.exists(root_path)) stop("ROOTID file not found: ", root_path)

    header_names <- names(read_csv_header(raw_path))
    if (!"ROOTID" %in% header_names) {
        stop("Raw file must contain a ROOTID column.")
    }
    root_map <- validate_rootid_map(
        data.table::fread(root_path, showProgress = FALSE),
        path_label = basename(root_path)
    )
    groups <- unique(as.character(root_map$GROUP))
    msr_cols <- detect_drb_gui_msr_columns(raw_path, data_dir)
    if (length(msr_cols) == 0L) {
        stop("No MSR columns were found. Check PARTID or data/msrinfo.csv FIELD values.")
    }

    list(
        raw_path = raw_path,
        root_path = root_path,
        groups = groups,
        msr_cols = msr_cols,
        root_map = root_map,
        raw_columns = header_names
    )
}

guess_drb_gui_groups <- function(groups) {
    groups <- unique(as.character(groups))
    ref_match <- groups[grepl("REF|REFERENCE|BASE|CONTROL", groups, ignore.case = TRUE)]
    tgt_match <- groups[grepl("TGT|TARGET|MUNS|TEST", groups, ignore.case = TRUE)]
    ref <- if (length(ref_match) > 0L) ref_match[[1L]] else if (length(groups) > 0L) groups[[1L]] else character()
    tgt_candidates <- setdiff(if (length(tgt_match) > 0L) tgt_match else groups, ref)
    tgt <- if (length(tgt_candidates) > 0L) tgt_candidates[[1L]] else character()
    list(ref = ref, tgt = tgt)
}

DRB_GUI_DEFAULT_GOOD_CHIP_HOT_RULE <- "HOT < 130"
DRB_GUI_DEFAULT_GOOD_CHIP_COLD_RULE <- "COLD < 130 OR (COLD >= 790 AND COLD < 800)"

normalize_drb_gui_good_chip_expression <- function(expression, variable_name) {
    expression <- trimws(as.character(expression)[1L])
    if (!nzchar(expression)) {
        stop(variable_name, " rule cannot be blank.")
    }
    expression <- gsub("<>", "!=", expression, fixed = TRUE)
    expression <- gsub("(?<![<>=!])=(?!=)", "==", expression, perl = TRUE)
    expression <- gsub("\\bAND\\b", "&", expression, ignore.case = TRUE, perl = TRUE)
    expression <- gsub("\\bOR\\b", "|", expression, ignore.case = TRUE, perl = TRUE)
    expression <- gsub("\\bNOT\\b", "!", expression, ignore.case = TRUE, perl = TRUE)
    expression <- gsub(
        paste0("\\b", variable_name, "\\b"),
        "x",
        expression,
        ignore.case = TRUE,
        perl = TRUE
    )
    expression
}

validate_drb_gui_good_chip_ast <- function(node, label) {
    if (is.numeric(node) || is.logical(node)) {
        return(invisible(TRUE))
    }
    if (is.symbol(node)) {
        symbol_name <- as.character(node)
        if (!symbol_name %in% c("x", "TRUE", "FALSE")) {
            stop(label, " contains an unsupported name: ", symbol_name)
        }
        return(invisible(TRUE))
    }
    if (!is.call(node)) {
        stop(label, " contains an unsupported value.")
    }
    operator <- as.character(node[[1L]])
    allowed_operators <- c("(", "&", "|", "!", "<", "<=", ">", ">=", "==", "!=", "+", "-", "*", "/")
    if (!operator %in% allowed_operators) {
        stop(label, " contains an unsupported operator or function: ", operator)
    }
    if (length(node) > 1L) {
        for (index in seq.int(2L, length(node))) {
            validate_drb_gui_good_chip_ast(node[[index]], label)
        }
    }
    invisible(TRUE)
}

compile_drb_gui_good_chip_rule <- function(expression, variable_name) {
    label <- paste(variable_name, "rule")
    normalized <- normalize_drb_gui_good_chip_expression(expression, variable_name)
    parsed <- tryCatch(
        parse(text = normalized, keep.source = FALSE),
        error = function(e) stop(label, " has invalid syntax: ", conditionMessage(e))
    )
    if (length(parsed) != 1L) {
        stop(label, " must contain exactly one expression.")
    }
    parsed <- parsed[[1L]]
    validate_drb_gui_good_chip_ast(parsed, label)
    if (is.symbol(parsed) && identical(as.character(parsed), "x")) {
        stop(label, " must compare ", variable_name, " with a value.")
    }
    eval(
        bquote(function(x) !is.na(x) & (.(parsed))),
        envir = baseenv()
    )
}

build_drb_gui_good_chip_rules <- function(enabled, cold_rule_text, hot_rule_text) {
    if (!isTRUE(enabled)) {
        return(list(hot = NULL, cold = NULL, hot_text = "Disabled", cold_text = "Disabled"))
    }
    hot_rule_text <- trimws(as.character(hot_rule_text)[1L])
    cold_rule_text <- trimws(as.character(cold_rule_text)[1L])
    list(
        hot = compile_drb_gui_good_chip_rule(hot_rule_text, "HOT"),
        cold = compile_drb_gui_good_chip_rule(cold_rule_text, "COLD"),
        hot_text = hot_rule_text,
        cold_text = cold_rule_text
    )
}

parse_drb_gui_category_scope <- function(level, values_text) {
    level <- trimws(as.character(level)[1L])
    values <- trimws(strsplit(as.character(values_text)[1L], ",", fixed = TRUE)[[1L]])
    values <- unique(values[!is.na(values) & nzchar(values)])
    if (!level %in% paste0("Category", 1:5) || length(values) == 0L) {
        return(NULL)
    }
    stats::setNames(list(values), level)
}

strip_drb_gui_ansi <- function(x) {
    gsub("\033\\[[0-9;]*m", "", as.character(x), perl = TRUE)
}

drb_gui_display_value <- function(x, empty = "None") {
    value <- paste(as.character(x), collapse = ", ")
    if (length(x) == 0L || !nzchar(trimws(value))) empty else value
}

normalize_drb_gui_color <- function(value, label = "Color") {
    value <- trimws(as.character(value)[1L])
    if (!nzchar(value)) {
        stop(label, " cannot be blank.")
    }
    tryCatch(
        grDevices::col2rgb(value),
        error = function(e) stop(label, " is not a valid R color: ", value)
    )
    value
}

drb_gui_hex_color <- function(value, fallback = "#6489FA") {
    rgb <- tryCatch(
        grDevices::col2rgb(value)[, 1L],
        error = function(e) grDevices::col2rgb(fallback)[, 1L]
    )
    sprintf("#%02X%02X%02X", rgb[[1L]], rgb[[2L]], rgb[[3L]])
}

drb_gui_color_input <- function(id, label, value) {
    hex_value <- drb_gui_hex_color(value)
    picker_id <- paste0(id, "_picker")
    shiny::div(
        class = "drb-color-control",
        shiny::tags$label(`for` = id, label),
        shiny::div(
            class = "drb-color-row",
            shiny::tags$input(
                id = picker_id,
                class = "drb-color-picker",
                type = "color",
                value = hex_value,
                oninput = sprintf(
                    "var target=document.getElementById('%s'); target.value=this.value.toUpperCase(); $(target).trigger('change');",
                    id
                )
            ),
            shiny::div(
                class = "drb-color-text",
                shiny::textInput(id, label = NULL, value = hex_value, placeholder = "#RRGGBB")
            )
        )
    )
}

drb_gui_confirmation_row <- function(label, value) {
    shiny::tags$tr(
        shiny::tags$th(label),
        shiny::tags$td(drb_gui_display_value(value))
    )
}

build_drb_gui_confirmation_ui <- function(input) {
    good_chip <- if (isTRUE(input$good_chip_enabled)) {
        paste0(
            "Enabled | Cold: ",
            drb_gui_display_value(input$good_chip_cold_rule, "Rule not set"),
            " | Hot fallback: ",
            drb_gui_display_value(input$good_chip_hot_rule, "Rule not set")
        )
    } else {
        "Disabled"
    }
    trim_setting <- if (isTRUE(input$trim_enabled)) {
        paste0("Enabled (IQR × ", input$trim_iqr, ")")
    } else {
        "Disabled"
    }
    output_types <- c(
        if (isTRUE(input$generate_ppt)) "PowerPoint",
        if (isTRUE(input$generate_spotfire)) "Spotfire data",
        if (isTRUE(input$open_spotfire)) "Open Spotfire DXP"
    )
    category_scope <- if (nzchar(input$category_scope_level)) {
        paste0(input$category_scope_level, ": ", drb_gui_display_value(input$category_scope_values))
    } else {
        "All categories"
    }

    shiny::tagList(
        shiny::tags$p(
            class = "drb-confirm-lead",
            "Review the current settings. The existing DRB pipeline will start after confirmation."
        ),
        shiny::tags$table(
            class = "table table-condensed drb-confirm-table",
            shiny::tags$tbody(
                drb_gui_confirmation_row("Raw / ROOTID", paste(input$raw_filename, input$root_filename, sep = " / ")),
                drb_gui_confirmation_row("REF / TARGET", paste(
                    drb_gui_display_value(input$ref_groups),
                    drb_gui_display_value(input$tgt_groups),
                    sep = " / "
                )),
                drb_gui_confirmation_row("Sigma threshold", input$sigma_threshold),
                drb_gui_confirmation_row("Good-chip filter", good_chip),
                drb_gui_confirmation_row("Outputs", output_types),
                drb_gui_confirmation_row("PPT title", input$slide_title),
                drb_gui_confirmation_row("Affiliation", input$affiliation),
                drb_gui_confirmation_row("Category order", if (nzchar(input$category_order_file)) input$category_order_file else "Automatic"),
                drb_gui_confirmation_row("Detail / Summary", paste(
                    input$detail_group_by,
                    drb_gui_display_value(input$summary_group_by),
                    sep = " / "
                )),
                drb_gui_confirmation_row("Category scope", category_scope),
                drb_gui_confirmation_row("Scatter mean / trim", paste(
                    if (isTRUE(input$show_mean)) {
                        paste0("Mean shown (label size ", input$mean_label_size, ")")
                    } else {
                        "Mean hidden"
                    },
                    trim_setting,
                    sep = " / "
                )),
                drb_gui_confirmation_row(
                    "REF / TARGET colors",
                    paste(input$ref_color, input$tgt_color, sep = " / ")
                ),
                drb_gui_confirmation_row(
                    "WF Map palette",
                    paste(vapply(
                        paste0("wf_map_color_", seq_len(5L)),
                        function(id) drb_gui_display_value(input[[id]], "Not set"),
                        character(1L)
                    ), collapse = " → ")
                ),
                drb_gui_confirmation_row("Plot layout", sprintf(
                    "Rows %.2f:%.2f:%.2f | CDF:WFMAP %.2f:%.2f",
                    input$row_top, input$row_mid, input$row_bottom,
                    input$cdf_ratio, input$wfmap_ratio
                ))
            )
        )
    )
}

build_drb_gui_run_environment <- function(values, log_callback = NULL) {
    run_env <- new.env(parent = .GlobalEnv)
    for (name in names(values)) {
        assign(name, values[[name]], envir = run_env)
    }
    if (is.function(log_callback)) {
        assign(".DRB_LOG_CALLBACK", log_callback, envir = run_env)
    }
    run_env
}

create_drb_gui_app <- function(project_dir = here::here()) {
    project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
    data_dir <- file.path(project_dir, "data")
    ppt_base_config <- load_drb_gui_ppt_base_config(project_dir)
    ppt_resolved_config <- resolve_ppt_config(ppt_base_config)
    initial_row_heights <- as.numeric(ppt_resolved_config$composite_row_heights)
    initial_bottom_split <- as.numeric(ppt_resolved_config$composite_bottom_split)
    initial_show_mean <- TRUE
    initial_mean_label_size <- resolve_ppt_config_numeric(
        ppt_resolved_config,
        "radius_mean_label_size",
        2.3
    )
    initial_trim_enabled <- TRUE
    initial_trim_iqr <- 6
    initial_ref_color <- drb_gui_hex_color(ppt_resolved_config$radius_ref_color)
    initial_tgt_color <- drb_gui_hex_color(ppt_resolved_config$radius_tgt_color)
    initial_wf_percentiles <- suppressWarnings(as.numeric(ppt_resolved_config$wf_map_percentiles))
    initial_wf_colors <- as.character(ppt_resolved_config$wf_map_percentile_colors)
    if (length(initial_wf_percentiles) != 5L || any(!is.finite(initial_wf_percentiles))) {
        initial_wf_percentiles <- c(0, 0.25, 0.50, 0.75, 0.99)
    }
    if (length(initial_wf_colors) != 5L) {
        initial_wf_colors <- c("#1B9E4B", "#4EA3D8", "#FED339", "#F28E2B", "#D62728")
    }
    initial_wf_colors <- vapply(
        seq_len(5L),
        function(index) drb_gui_hex_color(initial_wf_colors[[index]], "#4EA3D8"),
        character(1L)
    )
    wf_color_ids <- paste0("wf_map_color_", seq_len(5L))
    wf_percentile_labels <- paste0("P", round(initial_wf_percentiles * 100))
    csv_files <- drb_gui_data_files(data_dir)
    raw_default <- drb_gui_default_choice(csv_files, "raw.csv")
    root_default <- drb_gui_default_choice(csv_files, "ROOTID.csv")
    category_choices <- paste0("Category", 1:5)

    ui <- shiny::fluidPage(
        shiny::tags$head(
            shiny::tags$title("DRB Analysis Studio"),
            shiny::tags$style(shiny::HTML("\
                :root { --drb-border:#b8c0c8; --drb-border-soft:#d6dbe0; --drb-panel:#f6f7f8;
                    --drb-header:#e5e8eb; --drb-blue:#245d88; --drb-text:#202830; --drb-muted:#66727d; }
                html, body { height:100%; min-height:100%; overflow:hidden; }
                body { margin:0; background:#dfe3e7; color:var(--drb-text);
                    font-family:'Malgun Gothic','Segoe UI',sans-serif; font-size:12px; }
                .container-fluid { padding:0; }
                .drb-appbar { min-height:49px; display:flex; align-items:center; gap:10px; padding:6px 14px;
                    background:#f5f6f7; border-bottom:1px solid #9fa8b1; box-shadow:0 1px 2px rgba(20,31,41,.12); }
                .drb-app-mark { flex:0 0 28px; width:28px; height:28px; display:flex; align-items:center;
                    justify-content:center; color:white; background:#285f88; border:1px solid #174665;
                    border-radius:2px; font-size:16px; font-weight:700; }
                .drb-app-title { min-width:0; }
                .drb-app-title h2 { margin:0; color:#1d2b36; font-size:16px; line-height:1.25; font-weight:700; }
                .drb-app-title p { margin:1px 0 0; color:#6d7882; font-size:10.5px; line-height:1.2; }
                .drb-app-contact { margin-left:auto; color:#65717b; font-size:10px; white-space:nowrap; }
                .drb-app-contact strong { color:#344957; font-weight:700; }
                .drb-app-status { margin-left:auto; display:flex; align-items:center; gap:6px; padding:3px 7px;
                    color:#53616d; background:#e9ecef; border:1px solid #c4cbd1; border-radius:2px;
                    font-size:10px; font-weight:700; letter-spacing:.02em; text-transform:uppercase; }
                .drb-app-contact + .drb-app-status { margin-left:2px; }
                .drb-app-status-dot { width:7px; height:7px; background:#37834f; border:1px solid #246239;
                    border-radius:50%; }
                .drb-layout { height:calc(100vh - 49px); min-height:0; display:flex; align-items:stretch; }
                .drb-sidebar { flex:0 0 400px; width:400px; min-width:0; padding:9px 8px 12px 10px;
                    background:#edf0f2; border-right:1px solid #aeb6bd; }
                .drb-workspace { flex:1 1 auto; min-width:0; height:100%; overflow:hidden;
                    box-sizing:border-box; padding:10px 12px 16px; background:#e3e7ea; }
                .drb-workspace-grid { height:100%; min-height:0; display:grid;
                    grid-template-columns:460px minmax(0,1fr); gap:10px; align-items:stretch; }
                .drb-preview-column { min-width:0; min-height:0; display:flex; flex-direction:column; gap:10px; }
                .drb-card { background:#fafafa; border:1px solid var(--drb-border); border-radius:2px;
                    padding:10px 11px; margin-bottom:8px; box-shadow:none; }
                .drb-card h4 { margin:-10px -11px 9px; padding:6px 8px; color:#25333e;
                    background:var(--drb-header); border-bottom:1px solid var(--drb-border);
                    display:flex; align-items:center; gap:7px; font-size:12.5px; line-height:1.25; font-weight:700; }
                .drb-card-title-row { display:flex; align-items:center; justify-content:space-between;
                    gap:8px; margin:-10px -11px 9px; padding:4px 6px 4px 8px;
                    background:var(--drb-header); border-bottom:1px solid var(--drb-border); }
                .drb-card-title-row h4 { margin:0; padding:0; background:transparent; border:0; }
                .drb-sidebar .drb-card { border-color:#aeb8c0; }
                .drb-sidebar .drb-card > h4, .drb-sidebar .drb-card-title-row {
                    background:#d8e0e6; border-bottom-color:#9daab4; border-left:3px solid #2d6289; }
                .drb-section-number { flex:0 0 21px; width:21px; height:21px; display:inline-flex;
                    align-items:center; justify-content:center; color:white; background:#2d6289;
                    border:1px solid #204b6a; border-radius:2px; font-size:10px; line-height:1; font-weight:700; }
                .drb-section-title { color:#22313c; letter-spacing:.01em; }
                .drb-reset-btn { min-height:23px; padding:2px 8px; color:#4f5d68; background:#f6f7f8;
                    border-color:#adb6bd; border-radius:2px; font-size:10px; font-weight:700; }
                .drb-controls-scroll { height:100%; overflow-y:auto; overflow-x:hidden;
                    padding-right:4px; scrollbar-width:thin; scrollbar-color:#98a3ac transparent; }
                .drb-controls-scroll::-webkit-scrollbar { width:7px; }
                .drb-controls-scroll::-webkit-scrollbar-thumb { background:#98a3ac; border-radius:0; }
                .drb-controls-scroll::-webkit-scrollbar-track { background:transparent; }
                .drb-section-label { margin:10px 0 5px; color:#52606d; font-weight:700; font-size:11px;
                    text-transform:uppercase; letter-spacing:.04em; }
                .drb-preview-card { flex:0 0 auto; min-width:0; margin-bottom:0; }
                .drb-preview { width:100%; max-width:520px; height:auto; min-height:0;
                    aspect-ratio:3.0925 / 2.18; display:flex; align-items:center; justify-content:center;
                    overflow:hidden; margin:0 auto; padding:10px; background:#f1f2f3;
                    border:1px solid #c8ced3; border-radius:1px; }
                .drb-preview .shiny-image-output { width:100%; height:100%; display:flex;
                    align-items:center; justify-content:center; }
                .drb-preview img { width:auto; max-width:100%; max-height:100%; height:auto;
                    object-fit:contain; border:1px solid #c7cdd2; border-radius:0; box-shadow:none; }
                .drb-preview-empty { color:#707c86; font-size:12px; text-align:center; line-height:1.5; }
                .drb-preview-caption { margin-top:5px; color:#65717b; font-size:10px; text-align:center; }
                .drb-summary-card { flex:1 1 auto; min-height:0; display:flex; flex-direction:column;
                    margin-bottom:0; }
                .drb-summary-card > .shiny-html-output { min-height:0; overflow:auto; }
                .drb-summary-list { display:flex; flex-direction:column; }
                .drb-summary-row { display:grid; grid-template-columns:88px minmax(0,1fr); gap:8px;
                    align-items:center; min-height:29px; padding:5px 2px; border-bottom:1px solid #e0e4e7; }
                .drb-summary-row:last-child { border-bottom:0; }
                .drb-summary-label { color:#697681; font-size:10px; font-weight:700; text-transform:uppercase;
                    letter-spacing:.025em; }
                .drb-summary-value { min-width:0; overflow:hidden; color:#263640; font-size:11px;
                    text-overflow:ellipsis; white-space:nowrap; }
                .drb-summary-pill { display:inline-flex; align-items:center; width:max-content; padding:2px 6px;
                    border:1px solid #c6cdd2; border-radius:2px; background:#edf0f2; color:#5a6670;
                    font-size:9.5px; font-weight:700; }
                .drb-summary-pill.ready { color:#2f6b43; background:#eef7f1; border-color:#b8d3c1; }
                .drb-summary-pill.pending { color:#82662b; background:#fff7e5; border-color:#dfcea5; }
                .drb-status { border:1px solid #b7c9d8; border-left:3px solid #2d74b3; background:#edf4f8;
                    padding:6px 8px; margin-bottom:8px; font-size:11px; white-space:normal; }
                .drb-status.error { border-left-color:#c62828; background:#fff1f1; }
                .drb-status.success { border-left-color:#2e7d32; background:#f0f8f0; }
                .drb-inspection-help { margin:-2px 0 7px; color:#697680; font-size:10px; line-height:1.4; }
                .drb-preview-control .btn { width:100%; }
                .drb-preview-control .btn[disabled] { color:#eef2f5; background:#89959e;
                    border-color:#78848d; cursor:not-allowed; opacity:.78; }
                .drb-preview-gate { margin-top:4px; color:#6b7781; font-size:9.5px; text-align:center; }
                .drb-preview-gate.ready { color:#357049; }
                .drb-rule-input input { font-family:Consolas,'Courier New',monospace; font-size:10.5px; }
                .drb-rule-column-note { margin:-9px 0 8px 1px; color:#75818b; font-size:9.5px; line-height:1.25; }
                .drb-rule-column-note code { color:#53616c; background:transparent; padding:0; font-size:inherit; }
                .drb-rule-help { margin-top:-2px; line-height:1.45; }
                .btn { min-height:29px; padding:4px 9px; border-radius:2px; font-size:11px; }
                .btn-default { color:#293843; background:#f5f6f7; border-color:#aeb6bd; }
                .btn-default:hover, .btn-default:focus { color:#17232c; background:#e5e9ec; border-color:#87949e; }
                .btn-primary { background:#2b6691; border-color:#1f5278; }
                .btn-success { background:#34764b; border-color:#285f3b; font-weight:700; }
                details { margin-top:8px; border-top:1px solid #d9dee2; padding-top:6px; }
                details > summary { display:flex; align-items:center; gap:7px; list-style:none;
                    cursor:pointer; color:#354957; font-size:11px; font-weight:700; margin-bottom:0; user-select:none; }
                details[open] > summary { margin-bottom:6px; }
                details > summary::-webkit-details-marker { display:none; }
                details > summary::before { content:'▶'; display:inline-block; color:#607d91;
                    font-size:8px; line-height:1; transition:transform .12s ease; }
                details[open] > summary::before { transform:rotate(90deg); }
                .drb-terminal-card { height:100%; min-height:0; display:flex; flex-direction:column;
                    margin-bottom:0; padding:0; overflow:hidden; border-color:#1c2934; }
                .drb-terminal-head { display:flex; align-items:center; gap:6px; padding:6px 9px;
                    background:#26333d; color:#d8e4ec; font-size:11px; font-weight:700; }
                .drb-terminal-dot { width:8px; height:8px; border-radius:50%; display:inline-block; }
                .drb-terminal-dot.red { background:#ff6b6b; }
                .drb-terminal-dot.yellow { background:#ffd166; }
                .drb-terminal-dot.green { background:#52d273; margin-right:5px; }
                .drb-terminal-body { flex:1 1 auto; min-height:0; margin:0; height:auto; overflow:auto; padding:9px 11px;
                    background:#0f171e; color:#d6e2ea; border:0; border-radius:0;
                    font:10.5px/1.45 Consolas,'Courier New',monospace; white-space:pre-wrap; }
                .drb-confirm-lead { color:#52606d; margin-bottom:8px; }
                .drb-confirm-table { margin-bottom:0; table-layout:fixed; }
                .drb-confirm-table th { width:145px; color:#334e68; background:#f5f7f9; }
                .drb-confirm-table td { word-break:break-word; }
                .drb-group-box { padding:7px 8px 5px; margin-bottom:7px; border-radius:2px;
                    border:1px solid #cbd2d8; background:#f5f7f8; }
                .drb-group-box.ref { border-left:3px solid #6489FA; }
                .drb-group-box.tgt { border-left:3px solid #FA7864; }
                .drb-group-box.ref .control-label { color:#4569cc; }
                .drb-group-box.tgt .control-label { color:#c95645; }
                .drb-group-box .control-label { font-weight:700; }
                .drb-group-title { margin-bottom:4px; font-size:11px; font-weight:700; }
                .drb-group-box.ref .drb-group-title { color:#4569cc; }
                .drb-group-box.tgt .drb-group-title { color:#c95645; }
                .drb-group-add-row { display:flex; align-items:flex-start; gap:5px; }
                .drb-group-picker { flex:1 1 auto; min-width:0; }
                .drb-group-picker .form-group { margin-bottom:5px; }
                .drb-group-add-btn { flex:0 0 31px; width:31px; height:30px; min-height:30px; padding:1px 0;
                    font-size:18px; font-weight:700; line-height:1; color:#244760; background:#f5f8fa;
                    border-color:#cbd6de; }
                .drb-group-selected { display:flex; flex-direction:column; gap:3px; margin:0 0 5px; }
                .drb-group-chip { display:flex; align-items:center; justify-content:space-between; gap:8px;
                    min-height:25px; padding:2px 3px 2px 7px; background:white; border:1px solid #d2d9de;
                    border-radius:1px; font-size:11px; }
                .drb-group-chip-name { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
                .drb-group-remove { flex:0 0 21px; width:21px; height:19px; padding:0; border:0;
                    border-radius:1px; color:#6c7b86; background:#edf1f4; font-size:15px; line-height:17px; }
                .drb-group-remove:hover { color:#a52626; background:#fdecec; }
                .drb-group-empty { padding:3px 1px 5px; color:#82909b; font-size:10px; }
                .drb-group-count { margin:-2px 0 2px; color:#657786; font-size:10px; line-height:1.35; }
                .drb-group-actions { margin-top:2px; }
                .drb-group-actions .btn { width:100%; }
                .drb-group-status { margin:5px 0 1px; color:#52606d; font-size:10px; }
                .drb-color-control > label { color:#52606d; font-size:11px; font-weight:700; }
                .drb-color-row { display:flex; align-items:flex-start; gap:5px; }
                .drb-color-picker { flex:0 0 36px; width:36px; height:30px; padding:2px;
                    border:1px solid #b9c2c9; border-radius:2px; background:white; cursor:pointer; }
                .drb-color-text { flex:1 1 auto; min-width:0; }
                .drb-color-text .form-group { margin-bottom:5px; }
                .drb-color-text input { font-family:Consolas,'Courier New',monospace; font-size:11px; }
                .drb-wf-color-details { margin-top:2px; }
                .drb-wf-palette-preview { margin:4px 0 5px; }
                .drb-wf-palette-track { position:relative; height:18px; }
                .drb-wf-palette-bar { position:absolute; inset:1px 0; border:1px solid #939da5; border-radius:2px; }
                .drb-wf-palette-marker { position:absolute; top:-2px; bottom:-2px; width:1px;
                    background:#26343e; box-shadow:-1px 0 rgba(255,255,255,.75); z-index:1; }
                .drb-wf-palette-scale { position:relative; height:13px; margin-top:1px;
                    color:#687782; font-family:Consolas,'Courier New',monospace; font-size:8.5px; }
                .drb-wf-palette-label { position:absolute; top:0; white-space:nowrap; transform:translateX(-50%); }
                .drb-wf-palette-label.first { transform:none; }
                .drb-wf-palette-label.last { transform:translateX(-100%); }
                .drb-wf-color-grid { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:5px; }
                .drb-wf-color-grid .drb-color-control { min-width:0; }
                .drb-wf-color-grid .drb-color-control > label { position:absolute; width:1px; height:1px;
                    padding:0; margin:-1px; overflow:hidden; clip:rect(0,0,0,0); white-space:nowrap; border:0; }
                .drb-wf-color-grid .drb-color-row { display:block; }
                .drb-wf-color-grid .drb-color-picker { width:100%; height:25px; padding:2px; cursor:pointer; }
                .drb-wf-color-grid .drb-color-text { display:none; }
                .form-group { margin-bottom:7px; }
                .drb-sidebar .shiny-input-container { width:100%; }
                .control-label { margin-bottom:3px; color:#34444f; font-size:11px; font-weight:600; }
                .form-control, .selectize-input { min-height:30px; height:30px; padding:4px 7px;
                    border-color:#b7c0c7; border-radius:2px; box-shadow:inset 0 1px 1px rgba(0,0,0,.035);
                    color:#26343e; font-size:11px; }
                .selectize-input { height:auto; padding:5px 7px; }
                .selectize-dropdown { font-size:11px; }
                .checkbox, .radio { margin-top:5px; margin-bottom:5px; }
                .checkbox label, .radio label { font-size:11px; }
                .help-block { margin-top:3px; margin-bottom:6px; font-size:10px; color:#75818b; }
                .row { margin-left:-4px; margin-right:-4px; }
                .row > [class*='col-'] { padding-left:4px; padding-right:4px; }
                @media (max-width:1200px) {
                    .drb-sidebar { flex-basis:375px; width:375px; }
                }
                @media (max-width:1120px) {
                    .drb-sidebar { flex-basis:350px; width:350px; }
                    .drb-workspace { overflow-y:auto; }
                    .drb-workspace-grid { height:auto; grid-template-columns:1fr; }
                    .drb-preview-column { display:block; }
                    .drb-preview-card { margin-bottom:0; }
                    .drb-summary-card { min-height:180px; margin-top:10px; }
                    .drb-terminal-card { height:auto; }
                    .drb-terminal-body { flex:none; height:300px; }
                }
                @media (max-width:767px) {
                    html, body { height:auto; overflow:auto; }
                    .drb-app-status { display:none; }
                    .drb-layout { display:block; height:auto; }
                    .drb-sidebar { width:auto; padding:8px; border-right:0; border-bottom:1px solid #aeb6bd; }
                    .drb-workspace { height:auto; overflow:visible; padding:8px; }
                    .drb-controls-scroll { height:auto; max-height:none; overflow:visible; position:static; padding-right:0; }
                    .drb-preview { height:auto; min-height:0; max-height:none; }
                }
                @media (max-width:560px) {
                    .drb-app-title p { display:none; }
                    .drb-app-contact { font-size:9px; }
                }
            ")),
            shiny::tags$script(shiny::HTML("
                Shiny.addCustomMessageHandler('drb-terminal-set', function(message) {
                    var terminal = document.getElementById('run_terminal_text');
                    if (!terminal) return;
                    terminal.textContent = message.text || '';
                    terminal.scrollTop = terminal.scrollHeight;
                });
                Shiny.addCustomMessageHandler('drb-color-set', function(message) {
                    ['ref_color', 'tgt_color', 'wf_map_color_1', 'wf_map_color_2',
                     'wf_map_color_3', 'wf_map_color_4', 'wf_map_color_5'].forEach(function(id) {
                        var value = message[id];
                        if (!value) return;
                        var picker = document.getElementById(id + '_picker');
                        if (picker) picker.value = value;
                    });
                });
                $(document).on('click', '.drb-group-remove', function() {
                    Shiny.setInputValue('remove_group_request', {
                        side: this.getAttribute('data-side'),
                        group: this.getAttribute('data-group'),
                        nonce: Date.now()
                    }, {priority: 'event'});
                });
                $(document).on('input change', '#ref_color, #tgt_color, #wf_map_color_1, #wf_map_color_2, #wf_map_color_3, #wf_map_color_4, #wf_map_color_5', function() {
                    var value = (this.value || '').trim();
                    if (!/^#[0-9a-fA-F]{6}$/.test(value)) return;
                    var picker = document.getElementById(this.id + '_picker');
                    if (picker) picker.value = value;
                });
            "))
        ),
        shiny::div(
            class = "drb-appbar",
            shiny::div(class = "drb-app-mark", "D"),
            shiny::div(
                class = "drb-app-title",
                shiny::tags$h2("DRB Analysis Studio"),
                shiny::tags$p("Configure inputs, inspect a representative plot, and run the DRB pipeline.")
            ),
            shiny::div(
                class = "drb-app-contact",
                shiny::tags$span("Support "),
                shiny::tags$strong("t8jun2.park")
            ),
            shiny::div(
                class = "drb-app-status",
                shiny::tags$span(class = "drb-app-status-dot"),
                shiny::tags$span("Local workspace")
            )
        ),
        shiny::div(
            class = "drb-layout",
            shiny::div(
                class = "drb-sidebar",
                shiny::div(
                    class = "drb-controls-scroll",
                shiny::div(
                    class = "drb-card",
                    shiny::tags$h4(
                        shiny::tags$span(class = "drb-section-number", "1"),
                        shiny::tags$span(class = "drb-section-title", "Input & Groups")
                    ),
                    shiny::selectInput("raw_filename", "Raw CSV", choices = csv_files, selected = raw_default),
                    shiny::selectInput("root_filename", "ROOTID CSV", choices = csv_files, selected = root_default),
                    shiny::actionButton("inspect_inputs", "Inspect / Re-inspect inputs", class = "btn-default", width = "100%"),
                    shiny::div(
                        class = "drb-inspection-help",
                        "Input headers are inspected automatically at startup. Preview unlocks after inspection passes."
                    ),
                    shiny::uiOutput("input_status"),
                    shiny::div(
                        class = "drb-group-box ref",
                        shiny::div(class = "drb-group-title", "REF group(s)"),
                        shiny::div(
                            class = "drb-group-add-row",
                            shiny::div(
                                class = "drb-group-picker",
                                shiny::selectizeInput(
                                    "ref_group_candidate", label = NULL,
                                    choices = "", selected = "",
                                    options = list(placeholder = "Search a group to add")
                                )
                            ),
                            shiny::actionButton(
                                "add_ref_group", "+", class = "btn-default drb-group-add-btn",
                                title = "Add selected group to REF"
                            )
                        ),
                        shiny::div(
                            style = "display:none;",
                            shiny::selectizeInput(
                                "ref_groups", label = NULL, choices = character(),
                                selected = NULL, multiple = TRUE
                            )
                        ),
                        shiny::uiOutput("ref_group_selected"),
                        shiny::uiOutput("ref_group_summary")
                    ),
                    shiny::div(
                        class = "drb-group-box tgt",
                        shiny::div(class = "drb-group-title", "TARGET group(s)"),
                        shiny::div(
                            class = "drb-group-add-row",
                            shiny::div(
                                class = "drb-group-picker",
                                shiny::selectizeInput(
                                    "tgt_group_candidate", label = NULL,
                                    choices = "", selected = "",
                                    options = list(placeholder = "Search a group to add")
                                )
                            ),
                            shiny::actionButton(
                                "add_tgt_group", "+", class = "btn-default drb-group-add-btn",
                                title = "Add selected group to TARGET"
                            )
                        ),
                        shiny::div(
                            style = "display:none;",
                            shiny::selectizeInput(
                                "tgt_groups", label = NULL, choices = character(),
                                selected = NULL, multiple = TRUE
                            )
                        ),
                        shiny::uiOutput("tgt_group_selected"),
                        shiny::uiOutput("tgt_group_summary")
                    ),
                    shiny::fluidRow(
                        class = "drb-group-actions",
                        shiny::column(6, shiny::actionButton("auto_assign_groups", "Auto assign")),
                        shiny::column(6, shiny::actionButton("swap_groups", "Swap REF / TARGET"))
                    ),
                    shiny::uiOutput("group_selection_status"),
                    shiny::selectInput(
                        "preview_msr", "Preview MSR", choices = character(),
                        selected = NULL
                    )
                ),
                shiny::div(
                    class = "drb-card",
                    shiny::tags$h4(
                        shiny::tags$span(class = "drb-section-number", "2"),
                        shiny::tags$span(class = "drb-section-title", "PPT Report")
                    ),
                    shiny::textInput("slide_title", "PPT title", value = "[DM] Data Review Board Auto Report"),
                    shiny::textInput("affiliation", "Affiliation / author", value = "Flash PE / 홍길동"),
                    shiny::tags$div(class = "help-block", "Applied to the generated report slides.")
                ),
                shiny::div(
                    class = "drb-card",
                    shiny::div(
                        class = "drb-card-title-row",
                        shiny::tags$h4(
                            shiny::tags$span(class = "drb-section-number", "3"),
                            shiny::tags$span(class = "drb-section-title", "Plot Options")
                        ),
                        shiny::actionButton(
                            "reset_plot_options", "Reset",
                            class = "btn-default btn-sm drb-reset-btn",
                            title = "Restore all Plot Options defaults"
                        )
                    ),
                    shiny::selectInput(
                        "plot_preset", "Layout preset",
                        choices = c(
                            "Current PPT layout" = "ppt_default",
                            "Balanced" = "balanced",
                            "Scatter focus" = "scatter",
                            "CDF focus" = "cdf",
                            "WF Map focus" = "wfmap"
                        ),
                        selected = "ppt_default"
                    ),
                    shiny::checkboxInput(
                        "show_mean", "Show group mean lines and values",
                        value = initial_show_mean
                    ),
                    shiny::conditionalPanel(
                        condition = "input.show_mean",
                        shiny::numericInput(
                            "mean_label_size", "Mean label size",
                            value = initial_mean_label_size,
                            min = 1, max = 6, step = 0.1
                        )
                    ),
                    shiny::checkboxInput(
                        "trim_enabled", "Trim extreme Radius-scatter outliers",
                        value = initial_trim_enabled
                    ),
                    shiny::conditionalPanel(
                        condition = "input.trim_enabled",
                        shiny::numericInput(
                            "trim_iqr", "Trim IQR multiplier",
                            value = initial_trim_iqr, min = 0.5, max = 20, step = 0.5
                        )
                    ),
                    shiny::fluidRow(
                        shiny::column(
                            6,
                            drb_gui_color_input(
                                "ref_color", "REF color",
                                initial_ref_color
                            )
                        ),
                        shiny::column(
                            6,
                            drb_gui_color_input(
                                "tgt_color", "TARGET color",
                                initial_tgt_color
                            )
                        )
                    ),
                    shiny::tags$details(
                        class = "drb-wf-color-details",
                        shiny::tags$summary("WF Map colors"),
                        shiny::tags$div(
                            class = "help-block",
                            "Spotfire-style percentile color scale for Preview and PowerPoint."
                        ),
                        shiny::uiOutput("wf_map_palette_preview"),
                        shiny::div(
                            class = "drb-wf-color-grid",
                            lapply(seq_along(wf_color_ids), function(index) {
                                drb_gui_color_input(
                                    wf_color_ids[[index]],
                                    wf_percentile_labels[[index]],
                                    initial_wf_colors[[index]]
                                )
                            })
                        )
                    ),
                    shiny::tags$details(
                        shiny::tags$summary("Advanced plot sizing"),
                        shiny::numericInput("row_top", "Top Radius scatter ratio", value = initial_row_heights[[1L]], min = 0.4, max = 2.5, step = 0.05),
                        shiny::numericInput("row_mid", "Middle ROOTID average ratio", value = initial_row_heights[[2L]], min = 0.4, max = 2.5, step = 0.05),
                        shiny::numericInput("row_bottom", "Bottom CDF/WF Map ratio", value = initial_row_heights[[3L]], min = 0.4, max = 2.5, step = 0.05),
                        shiny::numericInput("cdf_ratio", "CDF width ratio", value = initial_bottom_split[[1L]], min = 0.4, max = 3, step = 0.05),
                        shiny::numericInput("wfmap_ratio", "WF Map width ratio", value = initial_bottom_split[[2L]], min = 0.4, max = 3, step = 0.05)
                    ),
                    shiny::uiOutput("refresh_preview_control", class = "drb-preview-control")
                ),
                shiny::div(
                    class = "drb-card",
                    shiny::tags$h4(
                        shiny::tags$span(class = "drb-section-number", "4"),
                        shiny::tags$span(class = "drb-section-title", "Full Run")
                    ),
                    shiny::numericInput("sigma_threshold", "Sigma threshold", value = 0.5, min = 0, step = 0.1),
                    shiny::checkboxInput("good_chip_enabled", "Apply Cold -> Hot Good-chip filter", value = TRUE),
                    shiny::conditionalPanel(
                        condition = "input.good_chip_enabled",
                        shiny::div(
                            class = "drb-rule-input",
                            shiny::textInput(
                                "good_chip_cold_rule",
                                "COLD rule (Excel-like)",
                                value = DRB_GUI_DEFAULT_GOOD_CHIP_COLD_RULE,
                                placeholder = "COLD < 130"
                            ),
                            shiny::tags$div(
                                class = "drb-rule-column-note",
                                "Applied to the ",
                                shiny::tags$code("LDS Cold Bin"),
                                " column."
                            ),
                            shiny::textInput(
                                "good_chip_hot_rule",
                                "HOT rule (Excel-like)",
                                value = DRB_GUI_DEFAULT_GOOD_CHIP_HOT_RULE,
                                placeholder = "HOT < 130"
                            ),
                            shiny::tags$div(
                                class = "drb-rule-column-note",
                                "Applied to the ",
                                shiny::tags$code("LDS Hot Bin"),
                                " column."
                            )
                        ),
                        shiny::tags$div(
                            class = "help-block drb-rule-help",
                            "Use HOT/COLD with <, <=, >, >=, =, <>, AND, OR, NOT, and parentheses. ",
                            "Cold is checked first; Hot is used only when Cold is blank."
                        )
                    ),
                    shiny::checkboxInput("generate_ppt", "Generate PowerPoint", value = TRUE),
                    shiny::checkboxInput("generate_spotfire", "Generate Spotfire data", value = TRUE),
                    shiny::checkboxInput("open_spotfire", "Open Spotfire DXP", value = TRUE),
                    shiny::tags$details(
                        shiny::tags$summary("PPT category settings"),
                        shiny::selectInput(
                            "category_order_file", "Category order CSV",
                            choices = c("Automatic" = "", csv_files),
                            selected = if ("cateinfo.csv" %in% csv_files) "cateinfo.csv" else ""
                        ),
                        shiny::selectInput("detail_group_by", "Detail group by", choices = category_choices, selected = "Category2"),
                        shiny::checkboxGroupInput(
                            "summary_group_by", "Summary hierarchy",
                            choices = category_choices,
                            selected = c("Category1", "Category2", "Category3"),
                            inline = TRUE
                        ),
                        shiny::selectInput(
                            "category_scope_level", "Optional Category filter",
                            choices = c("All categories" = "", stats::setNames(category_choices, category_choices))
                        ),
                        shiny::textInput("category_scope_values", "Filter values (comma-separated)", value = "")
                    ),
                    shiny::actionButton("run_analysis", "Run Full Analysis", class = "btn-success", width = "100%")
                )
                )
            ),
            shiny::div(
                class = "drb-workspace",
                shiny::div(
                    class = "drb-workspace-grid",
                    shiny::div(
                        class = "drb-preview-column",
                        shiny::div(
                            class = "drb-card drb-preview-card",
                            shiny::tags$h4("Quick Preview"),
                            shiny::uiOutput("preview_status"),
                            shiny::div(
                                class = "drb-preview",
                                shiny::uiOutput("preview_display")
                            ),
                            shiny::div(class = "drb-preview-caption", shiny::textOutput("preview_summary"))
                        ),
                        shiny::div(
                            class = "drb-card drb-summary-card",
                            shiny::tags$h4("Current Setup"),
                            shiny::uiOutput("workspace_summary")
                        )
                    ),
                    shiny::div(
                        class = "drb-card drb-terminal-card",
                        shiny::div(
                            class = "drb-terminal-head",
                            shiny::tags$span(class = "drb-terminal-dot red"),
                            shiny::tags$span(class = "drb-terminal-dot yellow"),
                            shiny::tags$span(class = "drb-terminal-dot green"),
                            shiny::tags$span("DRB Run Terminal")
                        ),
                        shiny::tags$pre(
                            id = "run_terminal_text",
                            class = "drb-terminal-body",
                            "Ready. Full analysis has not started."
                        )
                    )
                )
            )
        )
    )

    server <- function(input, output, session) {
        current_preview <- shiny::reactiveVal(NULL)
        state <- shiny::reactiveValues(
            inspection = NULL,
            actual_load = NULL,
            actual_cache_key = NULL,
            updating_groups = FALSE,
            input_message = "Checking the selected input files...",
            input_class = "",
            preview_message = "Inspect inputs, choose REF/TARGET and an MSR, then load Preview.",
            preview_class = "",
            run_log = "Ready. Full analysis has not started.",
            last_run = NULL
        )

        get_wf_map_colors <- function(strict = TRUE) {
            vapply(seq_along(wf_color_ids), function(index) {
                value <- input[[wf_color_ids[[index]]]]
                if (length(value) == 0L || !nzchar(trimws(as.character(value)[1L]))) {
                    value <- initial_wf_colors[[index]]
                }
                if (isTRUE(strict)) {
                    normalize_drb_gui_color(value, paste(wf_percentile_labels[[index]], "WF Map color"))
                } else {
                    drb_gui_hex_color(value, initial_wf_colors[[index]])
                }
            }, character(1L))
        }

        output$input_status <- shiny::renderUI({
            shiny::div(class = paste("drb-status", state$input_class), state$input_message)
        })
        output$preview_status <- shiny::renderUI({
            shiny::div(class = paste("drb-status", state$preview_class), state$preview_message)
        })
        output$preview_display <- shiny::renderUI({
            if (is.null(current_preview())) {
                return(shiny::div(
                    class = "drb-preview-empty",
                    shiny::tags$strong("Preview not loaded"),
                    shiny::tags$br(),
                    "Input headers are inspected first; full data is read only when Preview is requested."
                ))
            }
            shiny::imageOutput("quick_preview", width = "100%")
        })

        set_run_log <- function(text) {
            state$run_log <- as.character(text)
            session$sendCustomMessage("drb-terminal-set", list(text = state$run_log))
            invisible(state$run_log)
        }

        append_run_log <- function(line) {
            existing <- strsplit(state$run_log, "\n", fixed = TRUE)[[1L]]
            state$run_log <- paste(utils::tail(c(existing, as.character(line)), 300L), collapse = "\n")
            session$sendCustomMessage("drb-terminal-set", list(text = state$run_log))
            invisible(state$run_log)
        }

        inspection_files_match <- function() {
            !is.null(state$inspection) &&
                identical(basename(state$inspection$raw_path), basename(input$raw_filename)) &&
                identical(basename(state$inspection$root_path), basename(input$root_filename))
        }

        output$refresh_preview_control <- shiny::renderUI({
            inspection_ready <- isTRUE(inspection_files_match())
            button_args <- list(
                inputId = "refresh_preview",
                label = "Load / Refresh Preview",
                class = "btn-primary",
                width = "100%",
                title = if (inspection_ready) {
                    "Render Preview with the inspected inputs."
                } else {
                    "Complete input inspection before loading Preview."
                }
            )
            if (!inspection_ready) {
                button_args$disabled <- "disabled"
                button_args$`aria-disabled` <- "true"
            }
            shiny::tagList(
                do.call(shiny::actionButton, button_args),
                shiny::div(
                    class = paste("drb-preview-gate", if (inspection_ready) "ready" else "locked"),
                    if (inspection_ready) {
                        "Input inspection complete — Preview is available."
                    } else {
                        "Complete input inspection to enable Preview."
                    }
                )
            )
        })

        output$wf_map_palette_preview <- shiny::renderUI({
            colors <- get_wf_map_colors(strict = FALSE)
            stops <- pmax(0, pmin(100, initial_wf_percentiles * 100))
            gradient <- paste0(
                "linear-gradient(90deg, ",
                paste(paste0(colors, " ", format(stops, trim = TRUE), "%"), collapse = ", "),
                ")"
            )
            shiny::div(
                class = "drb-wf-palette-preview",
                shiny::div(
                    class = "drb-wf-palette-track",
                    shiny::div(class = "drb-wf-palette-bar", style = paste0("background:", gradient, ";")),
                    lapply(stops, function(stop) {
                        shiny::tags$span(
                            class = "drb-wf-palette-marker",
                            style = paste0("left:", format(stop, trim = TRUE), "%;")
                        )
                    })
                ),
                shiny::div(
                    class = "drb-wf-palette-scale",
                    lapply(seq_along(wf_percentile_labels), function(index) {
                        edge_class <- if (index == 1L) {
                            "first"
                        } else if (index == length(wf_percentile_labels)) {
                            "last"
                        } else {
                            ""
                        }
                        shiny::tags$span(
                            class = paste("drb-wf-palette-label", edge_class),
                            style = paste0("left:", format(stops[[index]], trim = TRUE), "%;"),
                            wf_percentile_labels[[index]]
                        )
                    })
                )
            )
        })

        output$workspace_summary <- shiny::renderUI({
            inspection_ready <- isTRUE(inspection_files_match())
            ref_groups <- unique(as.character(input$ref_groups))
            ref_groups <- ref_groups[!is.na(ref_groups) & nzchar(ref_groups)]
            tgt_groups <- unique(as.character(input$tgt_groups))
            tgt_groups <- tgt_groups[!is.na(tgt_groups) & nzchar(tgt_groups)]
            comparison <- if (length(ref_groups) > 0L && length(tgt_groups) > 0L) {
                paste(
                    paste(ref_groups, collapse = ", "),
                    paste(tgt_groups, collapse = ", "),
                    sep = " → "
                )
            } else {
                "Select REF and TARGET groups"
            }
            output_types <- c(
                if (isTRUE(input$generate_ppt)) "PowerPoint",
                if (isTRUE(input$generate_spotfire)) "Spotfire data",
                if (isTRUE(input$open_spotfire)) "Open DXP"
            )
            output_label <- if (length(output_types) > 0L) {
                paste(output_types, collapse = " · ")
            } else {
                "No outputs selected"
            }
            good_chip_label <- if (isTRUE(input$good_chip_enabled)) {
                paste0(
                    "Cold: ",
                    drb_gui_display_value(input$good_chip_cold_rule, "Rule not set"),
                    " · Hot: ",
                    drb_gui_display_value(input$good_chip_hot_rule, "Rule not set")
                )
            } else {
                "Disabled"
            }
            sigma_label <- if (length(input$sigma_threshold) > 0L) {
                format(as.numeric(input$sigma_threshold), trim = TRUE)
            } else {
                "—"
            }
            summary_row <- function(label, value) {
                shiny::div(
                    class = "drb-summary-row",
                    shiny::div(class = "drb-summary-label", label),
                    shiny::div(class = "drb-summary-value", value)
                )
            }
            shiny::div(
                class = "drb-summary-list",
                summary_row(
                    "Inspection",
                    shiny::tags$span(
                        class = paste("drb-summary-pill", if (inspection_ready) "ready" else "pending"),
                        if (inspection_ready) "Ready" else "Needs inspection"
                    )
                ),
                summary_row("Comparison", comparison),
                summary_row("Preview MSR", drb_gui_display_value(input$preview_msr, "Not selected")),
                summary_row("Sigma", sigma_label),
                summary_row("Good-chip", good_chip_label),
                summary_row("Outputs", output_label)
            )
        })

        update_group_selectors <- function(ref_selected, tgt_selected) {
            if (is.null(state$inspection)) return(invisible(NULL))
            all_groups <- unique(as.character(state$inspection$groups))
            ref_selected <- intersect(unique(as.character(ref_selected)), all_groups)
            tgt_selected <- setdiff(intersect(unique(as.character(tgt_selected)), all_groups), ref_selected)
            available_groups <- setdiff(all_groups, c(ref_selected, tgt_selected))
            candidate_choices <- c("", stats::setNames(available_groups, available_groups))
            state$updating_groups <- TRUE
            shiny::updateSelectizeInput(
                session, "ref_groups",
                choices = setdiff(all_groups, tgt_selected),
                selected = ref_selected
            )
            shiny::updateSelectizeInput(
                session, "tgt_groups",
                choices = setdiff(all_groups, ref_selected),
                selected = tgt_selected
            )
            shiny::updateSelectizeInput(
                session, "ref_group_candidate",
                choices = candidate_choices,
                selected = ""
            )
            shiny::updateSelectizeInput(
                session, "tgt_group_candidate",
                choices = candidate_choices,
                selected = ""
            )
            session$onFlushed(function() state$updating_groups <- FALSE, once = TRUE)
            invisible(NULL)
        }

        group_selected_ui <- function(groups, side) {
            groups <- unique(as.character(groups))
            groups <- groups[!is.na(groups) & nzchar(groups)]
            if (length(groups) == 0L) {
                return(shiny::div(class = "drb-group-empty", "No group selected"))
            }
            shiny::div(
                class = "drb-group-selected",
                lapply(groups, function(group) {
                    shiny::div(
                        class = "drb-group-chip",
                        shiny::tags$span(class = "drb-group-chip-name", group),
                        shiny::tags$button(
                            type = "button",
                            class = "drb-group-remove",
                            `data-side` = side,
                            `data-group` = group,
                            title = paste("Remove", group),
                            `aria-label` = paste("Remove", group),
                            "\u00d7"
                        )
                    )
                })
            )
        }

        group_summary_ui <- function(groups) {
            groups <- unique(as.character(groups))
            if (is.null(state$inspection) || length(groups) == 0L) {
                return(shiny::div(class = "drb-group-count", "No group selected"))
            }
            if (!is.null(state$actual_load)) {
                counts <- data.table::copy(state$actual_load$wf_counts)[GROUP %in% groups]
                data.table::setnames(counts, "N", "WFs")
                count_label <- "plotted WFs"
            } else {
                counts <- state$inspection$root_map[
                    GROUP %in% groups,
                    .(WFs = data.table::uniqueN(ROOTID)),
                    by = GROUP
                ]
                count_label <- "mapped WFs"
            }
            count_lookup <- stats::setNames(counts$WFs, counts$GROUP)
            detail <- paste(
                sprintf("%s (%d %s)", groups, as.integer(count_lookup[groups]), count_label),
                collapse = " · "
            )
            shiny::div(class = "drb-group-count", detail)
        }

        output$ref_group_selected <- shiny::renderUI(group_selected_ui(input$ref_groups, "ref"))
        output$tgt_group_selected <- shiny::renderUI(group_selected_ui(input$tgt_groups, "tgt"))
        output$ref_group_summary <- shiny::renderUI(group_summary_ui(input$ref_groups))
        output$tgt_group_summary <- shiny::renderUI(group_summary_ui(input$tgt_groups))
        output$group_selection_status <- shiny::renderUI({
            ref_groups <- unique(as.character(input$ref_groups))
            tgt_groups <- unique(as.character(input$tgt_groups))
            overlap <- intersect(ref_groups, tgt_groups)
            if (length(overlap) > 0L) {
                return(shiny::div(
                    class = "drb-group-status text-danger",
                    "REF and TARGET cannot overlap: ", paste(overlap, collapse = ", ")
                ))
            }
            shiny::div(
                class = "drb-group-status",
                sprintf("Selected: REF %d group(s) / TARGET %d group(s)", length(ref_groups), length(tgt_groups))
            )
        })

        perform_input_inspection <- function(show_notification = TRUE) {
            tryCatch({
                inspected <- inspect_drb_gui_inputs(
                    data_dir = data_dir,
                    raw_filename = input$raw_filename,
                    root_filename = input$root_filename
                )
                guessed <- guess_drb_gui_groups(inspected$groups)
                state$inspection <- inspected
                state$actual_load <- NULL
                state$actual_cache_key <- NULL
                current_preview(NULL)
                update_group_selectors(guessed$ref, guessed$tgt)
                shiny::updateSelectInput(
                    session, "preview_msr", choices = inspected$msr_cols,
                    selected = inspected$msr_cols[[1L]]
                )
                state$input_message <- sprintf(
                    "Input ready: %d groups, %d MSRs, %d mapped WFs.",
                    length(inspected$groups), length(inspected$msr_cols),
                    data.table::uniqueN(inspected$root_map$ROOTID)
                )
                state$input_class <- "success"
                state$preview_message <- "Choose groups and an MSR, then click Load / Refresh Preview."
                state$preview_class <- ""
                invisible(inspected)
            }, error = function(e) {
                state$inspection <- NULL
                state$actual_load <- NULL
                state$actual_cache_key <- NULL
                current_preview(NULL)
                state$input_message <- conditionMessage(e)
                state$input_class <- "error"
                state$preview_message <- "Preview is unavailable until the input contract passes."
                state$preview_class <- "error"
                if (isTRUE(show_notification)) {
                    shiny::showNotification(conditionMessage(e), type = "error", duration = 8)
                }
                invisible(NULL)
            })
        }

        shiny::observeEvent(input$inspect_inputs, {
            perform_input_inspection(show_notification = TRUE)
        }, ignoreInit = TRUE)

        shiny::observeEvent(list(input$raw_filename, input$root_filename), {
            if (!is.null(state$inspection) && !inspection_files_match()) {
                state$inspection <- NULL
                state$actual_load <- NULL
                state$actual_cache_key <- NULL
                current_preview(NULL)
                state$input_message <- "Input files changed. Re-inspect the selected files."
                state$input_class <- ""
                state$preview_message <- "Preview cache cleared because the input files changed."
                state$preview_class <- ""
            }
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$ref_groups, {
            if (!isTRUE(state$updating_groups)) {
                update_group_selectors(input$ref_groups, input$tgt_groups)
            }
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$tgt_groups, {
            if (!isTRUE(state$updating_groups)) {
                update_group_selectors(input$ref_groups, input$tgt_groups)
            }
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$add_ref_group, {
            candidate <- trimws(as.character(input$ref_group_candidate)[1L])
            if (!nzchar(candidate)) return(invisible(NULL))
            update_group_selectors(c(input$ref_groups, candidate), input$tgt_groups)
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$add_tgt_group, {
            candidate <- trimws(as.character(input$tgt_group_candidate)[1L])
            if (!nzchar(candidate)) return(invisible(NULL))
            update_group_selectors(input$ref_groups, c(input$tgt_groups, candidate))
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$remove_group_request, {
            request <- input$remove_group_request
            side <- as.character(request$side)[1L]
            group <- as.character(request$group)[1L]
            if (!nzchar(group)) return(invisible(NULL))
            if (identical(side, "ref")) {
                update_group_selectors(setdiff(input$ref_groups, group), input$tgt_groups)
            } else if (identical(side, "tgt")) {
                update_group_selectors(input$ref_groups, setdiff(input$tgt_groups, group))
            }
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$auto_assign_groups, {
            if (is.null(state$inspection)) return(invisible(NULL))
            guessed <- guess_drb_gui_groups(state$inspection$groups)
            update_group_selectors(guessed$ref, guessed$tgt)
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$swap_groups, {
            if (is.null(state$inspection)) return(invisible(NULL))
            update_group_selectors(input$tgt_groups, input$ref_groups)
        }, ignoreInit = TRUE)

        session$onFlushed(function() {
            shiny::isolate(perform_input_inspection(show_notification = FALSE))
        }, once = TRUE)

        shiny::observeEvent(input$plot_preset, {
            preset <- switch(
                input$plot_preset,
                ppt_default = c(initial_row_heights, initial_bottom_split),
                balanced = c(1.00, 1.00, 1.00, 1.25, 1.75),
                scatter = c(1.35, 1.20, 0.75, 1.20, 1.80),
                cdf = c(0.90, 0.90, 1.30, 1.70, 1.30),
                wfmap = c(0.90, 0.90, 1.30, 0.90, 2.10),
                c(initial_row_heights, initial_bottom_split)
            )
            shiny::updateNumericInput(session, "row_top", value = preset[[1L]])
            shiny::updateNumericInput(session, "row_mid", value = preset[[2L]])
            shiny::updateNumericInput(session, "row_bottom", value = preset[[3L]])
            shiny::updateNumericInput(session, "cdf_ratio", value = preset[[4L]])
            shiny::updateNumericInput(session, "wfmap_ratio", value = preset[[5L]])
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$reset_plot_options, {
            shiny::updateSelectInput(session, "plot_preset", selected = "ppt_default")
            shiny::updateCheckboxInput(session, "show_mean", value = initial_show_mean)
            shiny::updateNumericInput(session, "mean_label_size", value = initial_mean_label_size)
            shiny::updateCheckboxInput(session, "trim_enabled", value = initial_trim_enabled)
            shiny::updateNumericInput(session, "trim_iqr", value = initial_trim_iqr)
            shiny::updateNumericInput(session, "row_top", value = initial_row_heights[[1L]])
            shiny::updateNumericInput(session, "row_mid", value = initial_row_heights[[2L]])
            shiny::updateNumericInput(session, "row_bottom", value = initial_row_heights[[3L]])
            shiny::updateNumericInput(session, "cdf_ratio", value = initial_bottom_split[[1L]])
            shiny::updateNumericInput(session, "wfmap_ratio", value = initial_bottom_split[[2L]])
            shiny::updateTextInput(session, "ref_color", value = initial_ref_color)
            shiny::updateTextInput(session, "tgt_color", value = initial_tgt_color)
            for (index in seq_along(wf_color_ids)) {
                shiny::updateTextInput(
                    session,
                    wf_color_ids[[index]],
                    value = initial_wf_colors[[index]]
                )
            }
            session$sendCustomMessage(
                "drb-color-set",
                c(
                    list(ref_color = initial_ref_color, tgt_color = initial_tgt_color),
                    stats::setNames(as.list(initial_wf_colors), wf_color_ids)
                )
            )
            state$preview_message <- "Plot Options reset. Click Load / Refresh Preview to apply the defaults."
            state$preview_class <- ""
            shiny::showNotification("Plot Options restored to defaults.", type = "message", duration = 4)
        }, ignoreInit = TRUE)

        current_plot_config <- shiny::reactive({
            trim_value <- if (isTRUE(input$trim_enabled)) as.numeric(input$trim_iqr) else FALSE
            mean_label_size <- as.numeric(input$mean_label_size)
            if (!is.finite(mean_label_size) || mean_label_size <= 0) {
                stop("Mean label size must be a positive number.")
            }
            ref_color <- normalize_drb_gui_color(input$ref_color, "REF color")
            tgt_color <- normalize_drb_gui_color(input$tgt_color, "TARGET color")
            wf_map_colors <- get_wf_map_colors()
            build_drb_preview_config(
                base_config = ppt_base_config,
                show_mean = input$show_mean,
                mean_label_size = mean_label_size,
                trim_iqr = trim_value,
                row_heights = c(input$row_top, input$row_mid, input$row_bottom),
                bottom_split = c(input$cdf_ratio, input$wfmap_ratio),
                ref_color = ref_color,
                target_color = tgt_color,
                wf_map_percentile_colors = wf_map_colors
            )
        })

        get_preview_payload <- function() {
            if (!inspection_files_match()) {
                stop("Re-inspect the currently selected Raw and ROOTID files before Preview.")
            }
            inspected <- state$inspection
            preview_msr <- trimws(as.character(input$preview_msr)[1L])
            if (!nzchar(preview_msr) || !preview_msr %in% inspected$msr_cols) {
                stop("Select a valid MSR before loading Preview.")
            }
            rules <- build_drb_gui_good_chip_rules(
                input$good_chip_enabled,
                input$good_chip_cold_rule,
                input$good_chip_hot_rule
            )
            raw_info <- file.info(inspected$raw_path)
            root_info <- file.info(inspected$root_path)
            cache_key <- paste(
                normalizePath(inspected$raw_path, winslash = "/"), raw_info$size,
                as.numeric(raw_info$mtime), normalizePath(inspected$root_path, winslash = "/"),
                root_info$size, as.numeric(root_info$mtime), input$good_chip_enabled,
                trimws(as.character(input$good_chip_cold_rule)[1L]),
                trimws(as.character(input$good_chip_hot_rule)[1L]),
                preview_msr,
                sep = "|"
            )

            if (!identical(state$actual_cache_key, cache_key) || is.null(state$actual_load)) {
                state$actual_load <- NULL
                state$actual_cache_key <- NULL
                gc(verbose = FALSE)
                state$actual_load <- shiny::withProgress(
                    message = "Loading lightweight Preview data",
                    detail = "Only the selected MSR and required plot columns are retained.",
                    value = 0.2,
                    {
                        result <- load_and_filter_data(
                            inspected$raw_path,
                            inspected$root_path,
                            good_chip_rule_hot = rules$hot,
                            good_chip_rule_cold = rules$cold,
                            msrinfo_path = file.path(data_dir, "msrinfo.csv"),
                            requested_msr_cols = preview_msr
                        )
                        shiny::incProgress(0.8)
                        result
                    }
                )
                state$actual_cache_key <- cache_key
            }

            list(
                data = state$actual_load$data,
                msr_cols = state$actual_load$msr_cols,
                ref_groups = input$ref_groups,
                tgt_groups = input$tgt_groups,
                wf_counts = state$actual_load$wf_counts
            )
        }

        shiny::observeEvent(input$refresh_preview, {
            result <- tryCatch({
                payload <- get_preview_payload()
                ref_groups <- unique(as.character(input$ref_groups))
                tgt_groups <- unique(as.character(input$tgt_groups))
                if (nrow(payload$data) >= 1000000L) {
                    shiny::showNotification(
                        paste0(
                            "Large Preview input: ",
                            format(nrow(payload$data), big.mark = ","),
                            " filtered rows. Rendering may take several seconds."
                        ),
                        type = "warning",
                        duration = 6
                    )
                }
                png_path <- tempfile(pattern = "drb_quick_preview_", fileext = ".png")
                result <- shiny::withProgress(
                    message = "Rendering Quick Preview",
                    value = 0.15,
                    {
                        rendered <- render_drb_quick_preview(
                            dt = payload$data,
                            msr = input$preview_msr,
                            ref_groups = ref_groups,
                            tgt_groups = tgt_groups,
                            ppt_cfg = current_plot_config(),
                            png_path = png_path
                        )
                        shiny::incProgress(0.85)
                        rendered
                    }
                )
                state$preview_message <- "Selected-MSR Preview rendered and cached for further visual option changes."
                state$preview_class <- "success"
                result
            }, error = function(e) {
                state$preview_message <- conditionMessage(e)
                state$preview_class <- "error"
                shiny::showNotification(conditionMessage(e), type = "error", duration = 8)
                NULL
            })
            if (!is.null(result)) {
                current_preview(result)
            }
        }, ignoreInit = TRUE)

        output$quick_preview <- shiny::renderImage({
            result <- current_preview()
            if (is.null(result)) return(NULL)
            list(src = result$path, contentType = "image/png", alt = "DRB Quick Preview")
        }, deleteFile = FALSE)

        output$preview_summary <- shiny::renderText({
            result <- current_preview()
            if (is.null(result)) return("")
            sprintf(
                "PPT detail slot %.2f × %.2f in @ %d DPI | %s | %s rows | %d WFs | rows %.2f:%.2f:%.2f | CDF:WFMAP %.2f:%.2f",
                result$width_in, result$height_in, result$dpi,
                result$msr, format(result$rows, big.mark = ","), result$wafers,
                result$row_heights[[1L]], result$row_heights[[2L]], result$row_heights[[3L]],
                result$bottom_split[[1L]], result$bottom_split[[2L]]
            )
        })

        shiny::observeEvent(input$run_analysis, {
            if (!inspection_files_match()) {
                shiny::showNotification(
                    "Click Inspect inputs for the currently selected files before Full Run.",
                    type = "error", duration = 7
                )
                return(invisible(NULL))
            }

            shiny::showModal(shiny::modalDialog(
                title = "Confirm Full Analysis",
                build_drb_gui_confirmation_ui(input),
                footer = shiny::tagList(
                    shiny::modalButton("Cancel"),
                    shiny::actionButton(
                        "confirm_run_analysis",
                        "Confirm and Run",
                        class = "btn-success"
                    )
                ),
                size = "l",
                easyClose = FALSE
            ))
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$confirm_run_analysis, {
            shiny::removeModal()

            progress <- shiny::Progress$new(session, min = 0, max = 1)
            on.exit(progress$close(), add = TRUE)
            progress$set(value = 0.02, message = "Starting DRB analysis")
            set_run_log(paste0(
                "[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] GUI | ",
                "Settings confirmed. Starting DRB analysis..."
            ))

            tryCatch({
                inspected <- inspect_drb_gui_inputs(
                    data_dir = data_dir,
                    raw_filename = input$raw_filename,
                    root_filename = input$root_filename
                )
                ref_groups <- unique(as.character(input$ref_groups))
                tgt_groups <- unique(as.character(input$tgt_groups))
                if (length(ref_groups) == 0L || length(tgt_groups) == 0L) {
                    stop("Select at least one REF group and one TARGET group.")
                }
                overlap <- intersect(ref_groups, tgt_groups)
                if (length(overlap) > 0L) {
                    stop("REF and TARGET groups must not overlap: ", paste(overlap, collapse = ", "))
                }
                if (length(input$summary_group_by) == 0L) {
                    stop("Select at least one Summary hierarchy column.")
                }

                rules <- build_drb_gui_good_chip_rules(
                    input$good_chip_enabled,
                    input$good_chip_cold_rule,
                    input$good_chip_hot_rule
                )
                trim_value <- if (isTRUE(input$trim_enabled)) as.numeric(input$trim_iqr) else FALSE
                mean_label_size <- as.numeric(input$mean_label_size)
                if (!is.finite(mean_label_size) || mean_label_size <= 0) {
                    stop("Mean label size must be a positive number.")
                }
                ref_color <- normalize_drb_gui_color(input$ref_color, "REF color")
                tgt_color <- normalize_drb_gui_color(input$tgt_color, "TARGET color")
                wf_map_colors <- get_wf_map_colors()
                category_scope <- parse_drb_gui_category_scope(
                    input$category_scope_level,
                    input$category_scope_values
                )

                log_callback <- function(timestamp, message, line, ...) {
                    clean_line <- strip_drb_gui_ansi(line)
                    append_run_log(clean_line)

                    progress_value <- NULL
                    if (grepl("Step 1:|Inspecting file headers", message)) progress_value <- 0.10
                    if (grepl("Step 2: Reading data", message, fixed = TRUE)) progress_value <- 0.18
                    if (grepl("Step 4: Merging", message, fixed = TRUE)) progress_value <- 0.30
                    if (grepl("Calculat|Metric runtime", message, ignore.case = TRUE)) progress_value <- 0.48
                    if (grepl("Spotfire data bundle", message, fixed = TRUE)) progress_value <- 0.62
                    if (grepl("Initiating PPT Generator", message, fixed = TRUE)) progress_value <- 0.68
                    detail_match <- regexec("([0-9]+)[^0-9]+([0-9]+)", message)
                    detail_parts <- regmatches(message, detail_match)[[1L]]
                    if (grepl("detail", message, ignore.case = TRUE) && length(detail_parts) >= 3L) {
                        done <- as.numeric(detail_parts[[2L]])
                        total <- as.numeric(detail_parts[[3L]])
                        if (is.finite(done) && is.finite(total) && total > 0) {
                            progress_value <- 0.68 + (0.28 * min(done / total, 1))
                        }
                    }
                    if (grepl("Analysis Complete", message, fixed = TRUE)) progress_value <- 1
                    if (!is.null(progress_value)) {
                        progress$set(value = progress_value, detail = strip_drb_gui_ansi(message))
                    }
                    invisible(NULL)
                }

                run_values <- list(
                    RAW_FILENAME = basename(inspected$raw_path),
                    ROOT_FILENAME = basename(inspected$root_path),
                    GROUP_REF_NAME = ref_groups,
                    GROUP_TARGET_NAME = tgt_groups,
                    SIGMA_THRESHOLD = as.numeric(input$sigma_threshold),
                    GOOD_CHIP_RULE_HOT = rules$hot,
                    GOOD_CHIP_RULE_COLD = rules$cold,
                    GENERATE_SPOTFIRE = isTRUE(input$generate_spotfire),
                    OPEN_SPOTFIRE = isTRUE(input$open_spotfire),
                    GENERATE_PPT = isTRUE(input$generate_ppt),
                    PPT_SLIDE_TITLE = as.character(input$slide_title),
                    PPT_AFFILIATION = as.character(input$affiliation),
                    PPT_SCATTER_TRIM_IQR = trim_value,
                    PPT_SCATTER_SHOW_MEAN = isTRUE(input$show_mean),
                    PPT_CATEGORY_SCOPE = category_scope,
                    PPT_CATEGORY_ORDER_FILE = if (nzchar(input$category_order_file)) input$category_order_file else NULL,
                    PPT_DETAIL_GROUP_BY = input$detail_group_by,
                    PPT_SUMMARY_GROUP_BY = input$summary_group_by,
                    PPT_CONFIG = list(
                        composite_row_heights = c(input$row_top, input$row_mid, input$row_bottom),
                        composite_bottom_split = c(input$cdf_ratio, input$wfmap_ratio),
                        radius_mean_label_size = mean_label_size,
                        radius_ref_color = ref_color,
                        radius_tgt_color = tgt_color,
                        cdf_ref_color = ref_color,
                        cdf_tgt_color = tgt_color,
                        wf_map_color_mode = "percentile",
                        wf_map_percentile_colors = wf_map_colors
                    )
                )
                run_env <- build_drb_gui_run_environment(run_values, log_callback)
                old_wd <- getwd()
                on.exit(setwd(old_wd), add = TRUE)
                setwd(project_dir)
                sys.source(file.path(project_dir, "main.R"), envir = run_env)

                if (!exists("output_summary", envir = run_env, inherits = FALSE)) {
                    stop("The pipeline ended without an output summary. Check the Run Log.")
                }
                state$last_run <- get("output_summary", envir = run_env, inherits = FALSE)
                progress$set(value = 1, message = "DRB analysis complete")
                shiny::showNotification("DRB analysis complete.", type = "message", duration = 7)
            }, error = function(e) {
                error_line <- paste0("ERROR: ", conditionMessage(e))
                append_run_log(error_line)
                progress$set(message = "DRB analysis failed", detail = conditionMessage(e))
                shiny::showNotification(conditionMessage(e), type = "error", duration = NULL)
            })
        }, ignoreInit = TRUE)
    }

    shiny::shinyApp(ui = ui, server = server)
}

launch_drb_gui <- function(project_dir = here::here(), launch_browser = TRUE) {
    app <- create_drb_gui_app(project_dir = project_dir)
    shiny::runApp(app, launch.browser = launch_browser, display.mode = "normal")
}
