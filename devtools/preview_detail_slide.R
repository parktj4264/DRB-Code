#' @title Preview One PPT Detail Slide
#' @description Fast helper for iterating detail-slide layout without running main.R.
#'
#' Usage:
#'   Rscript devtools/preview_detail_slide.R
#'   Rscript devtools/preview_detail_slide.R --category=PB
#'   Rscript devtools/preview_detail_slide.R --category=PB --png=output/.preview_chat/detail_pb.png
#'
#' Notes:
#' - Reads output/results.csv from the latest completed pipeline run.
#' - Loads raw/root data only; it does not recalculate metrics.
#' - Builds one detail slide using the same PPT layout helpers as src/03_create_ppt.R.

get_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]
  if (length(file_arg) == 0L) {
    return(NULL)
  }
  sub("^--file=", "", file_arg[[1]])
}

script_path <- get_script_path()
if (!is.null(script_path)) {
  repo_root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
  setwd(repo_root)
}

get_cli_arg <- function(name, default = NULL) {
  args <- commandArgs(trailingOnly = TRUE)
  eq_prefix <- paste0("--", name, "=")
  eq_match <- args[startsWith(args, eq_prefix)]
  if (length(eq_match) > 0L) {
    return(sub(eq_prefix, "", eq_match[[1]], fixed = TRUE))
  }

  flag <- paste0("--", name)
  flag_idx <- match(flag, args)
  if (!is.na(flag_idx) && flag_idx < length(args)) {
    return(args[[flag_idx + 1L]])
  }

  default
}

split_group_arg <- function(x) {
  if (is.null(x) || !nzchar(x)) {
    return(NULL)
  }
  out <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  out[nzchar(out)]
}

load_run_user_parameters <- function(file_path = "run.R", target_env = parent.frame()) {
  if (!file.exists(file_path)) {
    return(invisible(FALSE))
  }

  run_lines <- readLines(file_path, warn = FALSE)
  start_idx <- grep("User Parameters", run_lines, fixed = TRUE)
  end_idx <- grep("Execution", run_lines, fixed = TRUE)

  if (length(start_idx) > 0L && length(end_idx) > 0L && start_idx[[1]] < end_idx[[1]]) {
    block_lines <- run_lines[(start_idx[[1]] + 1L):(end_idx[[1]] - 1L)]
  } else {
    names_pattern <- "^\\s*(RAW_FILENAME|ROOT_FILENAME|SIGMA_THRESHOLD|GROUP_REF_NAME|GROUP_TARGET_NAME|METRIC_PARAMS|METRIC_PARAMS_FILE|GENERAL_CONFIG|GENERAL_CONFIG_FILE|PPT_CONFIG|PPT_CONFIG_FILE)\\s*<-"
    block_lines <- run_lines[grepl(names_pattern, run_lines)]
  }

  block_text <- paste(block_lines, collapse = "\n")
  if (nzchar(trimws(block_text))) {
    eval(parse(text = block_text), envir = target_env)
  }

  invisible(TRUE)
}

export_first_slide_png <- function(pptx_path, png_path) {
  if (.Platform$OS.type != "windows") {
    return(FALSE)
  }

  ps_quote <- function(x) {
    paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
  }

  pptx_path_win <- normalizePath(pptx_path, winslash = "\\", mustWork = TRUE)
  png_path_win <- normalizePath(png_path, winslash = "\\", mustWork = FALSE)
  ps <- paste0(
    "$pptPath = Resolve-Path ", ps_quote(pptx_path_win), "\n",
    "$outPath = ", ps_quote(png_path_win), "\n",
    "$pp = New-Object -ComObject PowerPoint.Application; ",
    "$pres = $pp.Presentations.Open($pptPath.Path, $false, $true, $false); ",
    "$pres.Slides.Item(1).Export($outPath, 'PNG', 1920, 1080); ",
    "$pres.Close(); $pp.Quit(); ",
    "[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null; ",
    "[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pp) | Out-Null; ",
    "[gc]::Collect(); [gc]::WaitForPendingFinalizers();"
  )
  ps_file <- tempfile(fileext = ".ps1")
  writeLines(ps, ps_file)

  status <- system2(
    "powershell",
    c("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps_file),
    stdout = TRUE,
    stderr = TRUE
  )
  unlink(ps_file)
  exit_status <- attr(status, "status")
  if (is.null(exit_status)) {
    exit_status <- 0L
  }
  if (!identical(as.integer(exit_status), 0L)) {
    cat(paste(status, collapse = "\n"), "\n")
  }
  identical(as.integer(exit_status), 0L) && file.exists(png_path)
}

RAW_FILENAME <- "raw.csv"
ROOT_FILENAME <- "ROOTID.csv"
GROUP_REF_NAME <- NULL
GROUP_TARGET_NAME <- NULL

load_run_user_parameters("run.R", environment())

raw_arg <- get_cli_arg("raw")
root_arg <- get_cli_arg("root")
ref_arg <- get_cli_arg("ref")
tgt_arg <- get_cli_arg("tgt")
category_arg <- get_cli_arg("category", "")
results_arg <- get_cli_arg("results", file.path("output", "results.csv"))
pptx_arg <- get_cli_arg("pptx", file.path("output", ".preview_chat", "detail_slide_preview.pptx"))
png_arg <- get_cli_arg("png", file.path("output", ".preview_chat", "detail_slide_preview.png"))
layout_mode_arg <- get_cli_arg("layout-mode", "")
detail_layout_arg <- get_cli_arg("detail-layout", "")
bullet_placeholder_type_arg <- get_cli_arg("bullet-placeholder-type", "")

if (!is.null(raw_arg) && nzchar(raw_arg)) RAW_FILENAME <- raw_arg
if (!is.null(root_arg) && nzchar(root_arg)) ROOT_FILENAME <- root_arg
if (!is.null(ref_arg) && nzchar(ref_arg)) GROUP_REF_NAME <- split_group_arg(ref_arg)
if (!is.null(tgt_arg) && nzchar(tgt_arg)) GROUP_TARGET_NAME <- split_group_arg(tgt_arg)

if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here", type = "binary")
}

source("src/bootstrap/libs.R", local = environment())
source(here::here("src", "bootstrap", "utils.R"), local = environment())
source(here::here("src", "bootstrap", "runtime_config.R"), local = environment())
source(here::here("src", "01_load_data.R"), local = environment())
source(here::here("src", "03_create_ppt.R"), local = environment())

start_time <- Sys.time()
initial_object_names <- initialize_runtime_context(environment())
runtime_stage <- run_stage_runtime_config(initial_object_names)
preview_ppt_config <- runtime_stage$ppt_config_resolved
if (!is.null(layout_mode_arg) && nzchar(layout_mode_arg)) {
  preview_ppt_config$ppt_layout_mode <- layout_mode_arg
}
if (!is.null(detail_layout_arg) && nzchar(detail_layout_arg)) {
  preview_ppt_config$detail_slide_layout <- detail_layout_arg
}
if (!is.null(bullet_placeholder_type_arg) && nzchar(bullet_placeholder_type_arg)) {
  preview_ppt_config$slide_header_bullet_placeholder_type <- bullet_placeholder_type_arg
}
ppt_cfg <- resolve_ppt_config(preview_ppt_config)

results_path <- normalizePath(results_arg, winslash = "/", mustWork = FALSE)
if (!file.exists(results_path)) {
  stop("Results file not found. Run the pipeline once first: ", results_path)
}

result_dt <- data.table::fread(results_path)
if (!"Category2" %in% names(result_dt)) {
  stop("Results file has no Category2 column: ", results_path)
}

cat2_list <- unique(result_dt[!is.na(Category2), Category2])
if (!nzchar(category_arg)) {
  category_arg <- as.character(cat2_list[[1]])
}
if (!category_arg %in% cat2_list) {
  stop("Category not found in results.csv: ", category_arg)
}

load_stage <- run_stage_load_data(
  raw_filename = RAW_FILENAME,
  root_filename = ROOT_FILENAME,
  general_config = runtime_stage$general_config_resolved
)

grid_ncol <- max(1L, as.integer(ppt_cfg$detail_grid_ncol))
grid_nrow <- max(1L, as.integer(ppt_cfg$detail_grid_nrow))
max_detail_slots <- max(1L, grid_ncol * grid_nrow)
detail_top_n <- max(1L, as.integer(ppt_cfg$detail_top_n))
detail_plot_mode <- tolower(as.character(ppt_cfg$detail_plot_mode))
if (!detail_plot_mode %in% c("composite_v1", "legacy_scatter")) {
  detail_plot_mode <- "composite_v1"
}

plot_groups <- resolve_plot_groups(
  load_stage$data,
  final_ref = GROUP_REF_NAME,
  final_tgt = GROUP_TARGET_NAME
)
if (length(plot_groups$ref) == 0 || length(plot_groups$tgt) == 0) {
  detail_plot_mode <- "legacy_scatter"
}

detail_layout <- calculate_detail_plot_layout(ppt_cfg, grid_ncol, grid_nrow)
sub_dt <- result_dt[Category2 == category_arg]
sub_dt <- sub_dt[order(-Abs_Sigma_Score)]
top_msrs <- head(sub_dt$MSR, detail_top_n)
top_msrs <- top_msrs[!is.na(top_msrs)]
if (length(top_msrs) == 0L) {
  stop("No MSR found for category: ", category_arg)
}

template_path <- resolve_ppt_template_path(ppt_cfg)
if (file.exists(template_path)) {
  ppt <- read_pptx(template_path)
} else {
  ppt <- read_pptx()
}

ppt <- add_slide(
  ppt,
  layout = resolve_ppt_config_string(ppt_cfg$detail_slide_layout, "Title Only"),
  master = resolve_ppt_config_string(ppt_cfg$ppt_master, "Office Theme")
)
preview_detail_bullets <- resolve_ppt_slide_bullets(
  ppt_cfg,
  "detail_slide_bullets",
  list(
    category = category_arg,
    detail_top_n = detail_top_n,
    ref = plot_groups$ref,
    target = plot_groups$tgt,
    sigma_threshold = NA_character_,
    generated_at = format(Sys.time(), "%y%m%d_%H%M%S")
  )
)
if (resolve_ppt_header_mode(ppt_cfg) != "template_placeholder") {
  ppt <- add_ppt_slide_header(
    ppt,
    ppt_cfg,
    bullets = preview_detail_bullets
  )
}
detail_header_label <- paste("Category:", category_arg, "-", paste0("Top ", detail_top_n, " Sigma Delta"))
ppt <- add_detail_grid_table(ppt, detail_layout, ppt_cfg, header_label = detail_header_label)

temp_dir <- tempdir()
index <- 1L
for (msr in top_msrs) {
  if (index > max_detail_slots) {
    break
  }
  if (!msr %in% names(load_stage$data)) {
    log_msg(paste0("[Warning] MSR column not found in raw dt; skipped: ", msr))
    next
  }

  slot_location <- detail_layout_for_index(detail_layout, index)
  msr_name_title <- as.character(msr)
  msr_direction <- "Stable"

  if ("ITEM_NAME" %in% names(sub_dt)) {
    item_name_i <- sub_dt[MSR == msr, ITEM_NAME][1]
    if (!is.na(item_name_i) && nzchar(as.character(item_name_i))) {
      msr_name_title <- as.character(item_name_i)
    }
  }
  if ("Direction" %in% names(sub_dt)) {
    direction_i <- sub_dt[MSR == msr, Direction][1]
    if (!is.na(direction_i) && nzchar(as.character(direction_i))) {
      msr_direction <- as.character(direction_i)
    }
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

  png_path <- file.path(temp_dir, paste0("detail_preview_", sanitize_file_token(msr), "_", index, ".png"))
  if (detail_plot_mode == "composite_v1") {
    generate_composite_plot_png(
      dt = load_stage$data,
      msr = msr,
      msr_title = msr_name_title,
      ref_groups = plot_groups$ref,
      tgt_groups = plot_groups$tgt,
      png_path = png_path,
      width_in = detail_layout$plot_w,
      height_in = detail_layout$plot_h,
      dpi = as.numeric(ppt_cfg$plot_dpi),
      ppt_cfg = ppt_cfg
    )
  } else {
    legacy_plot <- build_legacy_scatter_plot(
      dt = load_stage$data,
      msr = msr,
      title_text = NULL,
      ppt_cfg = ppt_cfg
    )
    ggplot2::ggsave(
      png_path,
      plot = legacy_plot,
      width = detail_layout$plot_w,
      height = detail_layout$plot_h,
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
      width = detail_layout$plot_w,
      height = detail_layout$plot_h
    )
  )

  index <- index + 1L
}

if (resolve_ppt_header_mode(ppt_cfg) == "template_placeholder") {
  ppt <- add_ppt_slide_header(
    ppt,
    ppt_cfg,
    bullets = preview_detail_bullets
  )
}

pptx_path <- normalizePath(pptx_arg, winslash = "/", mustWork = FALSE)
pptx_dir <- dirname(pptx_path)
if (!dir.exists(pptx_dir)) {
  dir.create(pptx_dir, recursive = TRUE)
}
if (.Platform$OS.type == "windows" && basename(pptx_dir) == ".preview_chat") {
  try(system2("attrib", c("-h", shQuote(pptx_dir))), silent = TRUE)
}
print(ppt, target = pptx_path)

png_path <- normalizePath(png_arg, winslash = "/", mustWork = FALSE)
png_dir <- dirname(png_path)
if (!dir.exists(png_dir)) {
  dir.create(png_dir, recursive = TRUE)
}
exported_png <- export_first_slide_png(pptx_path, png_path)
if (.Platform$OS.type == "windows" && basename(pptx_dir) == ".preview_chat") {
  try(system2("attrib", c("+h", shQuote(pptx_dir))), silent = TRUE)
}

elapsed_sec <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
cat("PREVIEW_CATEGORY=", category_arg, "\n", sep = "")
cat("PREVIEW_PPTX=", pptx_path, "\n", sep = "")
if (isTRUE(exported_png)) {
  cat("PREVIEW_PNG=", png_path, "\n", sep = "")
} else {
  cat("PREVIEW_PNG_EXPORT=skipped\n")
}
cat("PREVIEW_ELAPSED_SEC=", elapsed_sec, "\n", sep = "")
