#' @title Finalize Run Outputs
#' @description Save analysis/history artifacts and dispatch optional Spotfire/PPT outputs.
remove_legacy_spotfire_output <- function(
    path = here::here("output", "sigma_score_raw.csv")
) {
    if (!file.exists(path)) {
        return(FALSE)
    }
    removed <- isTRUE(unlink(path, force = TRUE) == 0L) && !file.exists(path)
    if (removed) {
        log_msg(paste0("Removed legacy duplicate: ", path))
    } else {
        log_msg(paste0("[Warning] Could not remove legacy file (file may be locked): ", path))
    }
    removed
}

finalize_run_outputs <- function(
    result_dt,
    calc_res,
    dt,
    wf_counts,
    raw_filename,
    root_filename,
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
    ppt_config_resolved,
    generate_ppt = TRUE,
    generate_spotfire = TRUE
) {
    timestamp_str <- format(Sys.time(), "%y%m%d_%H%M%S")
    generated_at <- Sys.time()
    ppt_generation_enabled <- normalize_ppt_generation_flag(
        generate_ppt,
        default = TRUE
    )
    spotfire_generation_enabled <- normalize_spotfire_generation_flag(
        generate_spotfire,
        default = TRUE
    )
    output_path <- here::here("output", "results.csv")
    atomic_fwrite(result_dt, output_path)
    legacy_spotfire_removed <- remove_legacy_spotfire_output()

    spotfire_bundle <- NULL
    if (spotfire_generation_enabled) {
        spotfire_sigma_dt <- build_spotfire_sigma_table(
            result_dt = result_dt,
            dt = dt,
            final_ref = final_ref,
            final_tgt = final_tgt,
            sigma_threshold = sigma_threshold,
            raw_filename = raw_filename,
            generated_at = generated_at
        )
        spotfire_bundle <- write_spotfire_bundle(
            result_dt = result_dt,
            sigma_dt = spotfire_sigma_dt,
            dt = dt,
            raw_path = here::here("data", raw_filename),
            root_path = here::here("data", root_filename),
            output_dir = here::here("spotfire")
        )
        raw_action <- if (isTRUE(spotfire_bundle$raw_updated)) "updated" else "unchanged"
        log_msg(paste0("Spotfire data bundle: ./spotfire (raw: ", raw_action, ")"))
    } else {
        log_msg(paste0(
            "Spotfire data generation skipped (GENERATE_SPOTFIRE = FALSE). ",
            "Existing Spotfire files, if any, were left unchanged."
        ))
    }

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
        paste0(
            "Generate PPT: ",
            toupper(as.character(ppt_generation_enabled))
        ),
        paste0(
            "Generate Spotfire: ",
            toupper(as.character(spotfire_generation_enabled))
        ),
        metric_param_lines,
        runtime_lines,
        paste0("Execution Time: ", execution_time, " mins"),
        "==========================="
    )
    writeLines(param_content, param_log_path)

    ppt_generated <- FALSE
    latest_ppt_path <- here::here("output", "sigma_summary_latest.pptx")
    if (ppt_generation_enabled) {
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
            archive_ppt_path <- file.path(
                archive_dir,
                paste0("sigma_summary_", timestamp_str, ".pptx")
            )
            ppt_generated <- (
                file.exists(archive_ppt_path) &&
                file.exists(latest_ppt_path)
            )
        }, error = function(e_ppt) {
            log_msg(paste0(
                "[Warning] PPT generation failed: ",
                e_ppt$message
            ))
        })
    } else {
        log_msg(paste0(
            "PPT generation skipped (GENERATE_PPT = FALSE). ",
            "Existing latest PPT, if any, was left unchanged."
        ))
    }

    list(
        output_path = output_path,
        legacy_spotfire_removed = legacy_spotfire_removed,
        spotfire_sigma_path = if (!is.null(spotfire_bundle)) spotfire_bundle$sigma_path else NULL,
        spotfire_generation_enabled = spotfire_generation_enabled,
        spotfire_bundle = spotfire_bundle,
        archive_dir = archive_dir,
        archive_csv_path = archive_csv_path,
        timestamp_str = timestamp_str,
        param_log_path = param_log_path,
        issue_report = issue_report,
        ppt_generation_enabled = ppt_generation_enabled,
        ppt_generated = ppt_generated,
        ppt_path = if (ppt_generated) latest_ppt_path else NULL
    )
}
