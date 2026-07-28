# E2E test: run main pipeline and validate core metric columns in output schema
source("src/bootstrap/libs.R")

RAW_FILENAME <- "raw.csv"
ROOT_FILENAME <- "ROOTID.csv"
GOOD_CHIP_LIMIT <- 130
SIGMA_THRESHOLD <- 1
GROUP_REF_NAME <- NULL
GROUP_TARGET_NAME <- NULL

output_path <- here::here("output", "results.csv")
spotfire_path <- here::here("output", "sigma_score_raw.csv")
ppt_path <- here::here("output", "sigma_summary_latest.pptx")
issues_latest_path <- here::here("output", "metric_issues_latest.csv")
latest_paths <- c(output_path, spotfire_path, ppt_path, issues_latest_path)
existing_latest <- file.exists(latest_paths)
backup_dir <- tempfile("drb_e2e_output_backup_")
stopifnot(dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE))
if (any(existing_latest)) {
  backup_ok <- file.copy(
    latest_paths[existing_latest],
    backup_dir,
    overwrite = TRUE,
    copy.date = TRUE
  )
  stopifnot(all(backup_ok))
}
archive_dirs_before <- normalizePath(
  Sys.glob(here::here("output", "results_*")),
  winslash = "/",
  mustWork = FALSE
)
archive_dir_created <- NULL

tryCatch({
  unlink(latest_paths, force = TRUE)
  stopifnot(!any(file.exists(latest_paths)))

  ppt_temp_before <- Sys.glob(file.path(tempdir(), "drb_ppt_assets_*"))
  source(here::here("main.R"), local = environment())

  stopifnot(exists("output_summary", inherits = FALSE))
  archive_dir_created <- normalizePath(
    output_summary$archive_dir,
    winslash = "/",
    mustWork = FALSE
  )
  stopifnot(file.exists(output_path))

  result_dt <- data.table::fread(output_path)
  required_cols <- c(
    "Sigma_Score", "Abs_Sigma_Score", "Direction",
    "metric_one_sigma", "abs_metric_one_sigma"
  )

  missing_cols <- setdiff(required_cols, names(result_dt))
  stopifnot(length(missing_cols) == 0)
  stopifnot(nrow(result_dt) > 0)
  stopifnot(!("Glass_Flag" %in% names(result_dt)))

  stopifnot(file.exists(spotfire_path))
  spotfire_dt <- data.table::fread(spotfire_path)
  stopifnot(identical(names(spotfire_dt), get_spotfire_sigma_columns()))
  stopifnot(nrow(spotfire_dt) == nrow(result_dt))
  stopifnot(all(spotfire_dt$is_selected_pair))
  expected_sigma <- result_dt$Sigma_Score[match(spotfire_dt$MSR, result_dt$MSR)]
  stopifnot(all(abs(spotfire_dt$sigma_score - expected_sigma) < 1e-12))
  stopifnot(all(spotfire_dt$raw_file == RAW_FILENAME))

  stopifnot(file.exists(ppt_path))
  archive_ppt <- list.files(
    output_summary$archive_dir,
    pattern = "^sigma_summary_[0-9_]+\\.pptx$",
    full.names = TRUE
  )
  stopifnot(length(archive_ppt) == 1L)
  ppt_temp_after <- Sys.glob(file.path(tempdir(), "drb_ppt_assets_*"))
  stopifnot(length(setdiff(ppt_temp_after, ppt_temp_before)) == 0L)

  ppt_text <- officer::pptx_summary(officer::read_pptx(ppt_path))
  summary_text <- ppt_text[ppt_text$slide_id == 1, "text"]
  stopifnot(!any(summary_text == "\u25A0 comment"))
  stopifnot(any(grepl("TREND: plot \uC218\uB3D9 \uBD80\uCC29", summary_text, fixed = TRUE)))
  expected_summary_headers <- c(
    "\uAD6C\uBD84",
    "\uC8FC\uC694 \uD56D\uBAA9",
    "\uC9C0\uC218\uC218\uC900",
    "Diff",
    "\uBCC0\uB3D9\uACB0\uACFC",
    "TREND",
    "\uBE44\uACE0"
  )
  stopifnot(all(vapply(
    expected_summary_headers,
    function(header) any(grepl(header, summary_text, fixed = TRUE)),
    logical(1)
  )))

  ppt_xml_dir <- tempfile("drb_ppt_xml_")
  stopifnot(dir.create(ppt_xml_dir, recursive = TRUE, showWarnings = FALSE))
  ppt_entries <- utils::unzip(ppt_path, list = TRUE)$Name
  slide_xml_entries <- ppt_entries[grepl("^ppt/slides/slide[0-9]+\\.xml$", ppt_entries)]
  utils::unzip(ppt_path, files = slide_xml_entries, exdir = ppt_xml_dir)
  slide_xml <- paste(vapply(
    file.path(ppt_xml_dir, slide_xml_entries),
    function(path) paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = ""),
    character(1)
  ), collapse = "")
  stopifnot(grepl('typeface="Malgun Gothic"', slide_xml, fixed = TRUE))
  stopifnot(!grepl('<a:spcPct val="10000"', slide_xml, fixed = TRUE))
  unlink(ppt_xml_dir, recursive = TRUE, force = TRUE)

  stopifnot(file.exists(issues_latest_path))
  issues_dt <- data.table::fread(issues_latest_path)
  issue_cols <- c("metric_name", "issue_type", "pair_id", "message", "count")
  stopifnot(all(issue_cols %in% names(issues_dt)))
}, finally = {
  unlink(latest_paths, force = TRUE)
  if (any(existing_latest)) {
    restore_ok <- file.copy(
      file.path(backup_dir, basename(latest_paths[existing_latest])),
      latest_paths[existing_latest],
      overwrite = TRUE,
      copy.date = TRUE
    )
    if (!all(restore_ok)) {
      stop("Failed to restore pre-test latest output artifacts.")
    }
  }
  if (!is.null(archive_dir_created) &&
      !archive_dir_created %in% archive_dirs_before &&
      dir.exists(archive_dir_created)) {
    unlink(archive_dir_created, recursive = TRUE, force = TRUE)
  }
  unlink(backup_dir, recursive = TRUE, force = TRUE)
})

cat("PASS: test_e2e_output_schema.R\n")

