#' @title Preview One Composite Detail Plot
#' @description Standalone developer helper for quickly previewing one MSR composite plot.
#'
#' Usage:
#'   Rscript devtools/preview_composite_plot.R
#'   Rscript devtools/preview_composite_plot.R --msr=ML_MSR_122
#'   Rscript devtools/preview_composite_plot.R --msr=ML_MSR_122 --out=output/.preview_chat/composite_preview.png
#'
#' Notes:
#' - This script does NOT source run.R or main.R.
#' - It only reads the User Parameters block from run.R, then runs the minimum stages
#'   needed to render one composite PNG.
#' - CLI args override run.R parameters.

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

# Safe defaults. run.R User Parameters and CLI args can override these.
RAW_FILENAME <- "raw.csv"
ROOT_FILENAME <- "ROOTID.csv"
SIGMA_THRESHOLD <- 0.5
GROUP_REF_NAME <- NULL
GROUP_TARGET_NAME <- NULL

load_run_user_parameters("run.R", environment())

raw_arg <- get_cli_arg("raw")
root_arg <- get_cli_arg("root")
sigma_arg <- get_cli_arg("sigma")
ref_arg <- get_cli_arg("ref")
tgt_arg <- get_cli_arg("tgt")
preview_msr <- get_cli_arg("msr", "")
out_arg <- get_cli_arg("out", file.path("output", ".preview_chat", "composite_preview.png"))

if (!is.null(raw_arg) && nzchar(raw_arg)) RAW_FILENAME <- raw_arg
if (!is.null(root_arg) && nzchar(root_arg)) ROOT_FILENAME <- root_arg
if (!is.null(sigma_arg) && nzchar(sigma_arg)) SIGMA_THRESHOLD <- as.numeric(sigma_arg)
if (!is.null(ref_arg) && nzchar(ref_arg)) GROUP_REF_NAME <- split_group_arg(ref_arg)
if (!is.null(tgt_arg) && nzchar(tgt_arg)) GROUP_TARGET_NAME <- split_group_arg(tgt_arg)

if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here", type = "binary")
}

source("src/bootstrap/libs.R", local = environment())
source(here::here("src", "bootstrap", "utils.R"), local = environment())
source(here::here("src", "bootstrap", "runtime_config.R"), local = environment())
source(here::here("src", "01_load_data.R"), local = environment())
source(here::here("src", "02_calc_stats.R"), local = environment())
source(here::here("src", "03_create_ppt.R"), local = environment())

start_time <- Sys.time()
initial_object_names <- initialize_runtime_context(environment())

runtime_stage <- run_stage_runtime_config(initial_object_names)
load_stage <- run_stage_load_data(
  raw_filename = RAW_FILENAME,
  root_filename = ROOT_FILENAME,
  general_config = runtime_stage$general_config_resolved
)
calc_stage <- run_stage_calculate_sigma(
  load_stage = load_stage,
  sigma_threshold = SIGMA_THRESHOLD,
  group_ref_name = GROUP_REF_NAME,
  group_target_name = GROUP_TARGET_NAME,
  metric_params_file = METRIC_PARAMS_FILE,
  metric_params_run = METRIC_PARAMS,
  na_policy = runtime_stage$NA_POLICY
)

ppt_cfg <- resolve_ppt_config(runtime_stage$ppt_config_resolved)
grid_ncol <- max(1L, as.integer(ppt_cfg$detail_grid_ncol))
grid_nrow <- max(1L, as.integer(ppt_cfg$detail_grid_nrow))
plot_w <- (as.numeric(ppt_cfg$slide_width) - as.numeric(ppt_cfg$margin_left) - as.numeric(ppt_cfg$margin_right)) / grid_ncol
plot_h <- (as.numeric(ppt_cfg$slide_height) - as.numeric(ppt_cfg$margin_top) - as.numeric(ppt_cfg$margin_bottom)) / grid_nrow

candidate_dt <- calc_stage$result_dt[Direction %in% c("Up", "Down")]
if ("Abs_Sigma_Score" %in% names(candidate_dt)) {
  candidate_dt <- candidate_dt[order(-Abs_Sigma_Score)]
}

if (!nzchar(preview_msr)) {
  if (nrow(candidate_dt) == 0L) {
    stop("No flagged MSR found for preview. Pass --msr=<MSR_NAME> to preview a specific metric.")
  }
  preview_msr <- as.character(candidate_dt$MSR[[1]])
}

if (!preview_msr %in% names(load_stage$data)) {
  stop("Preview MSR is not present in loaded data: ", preview_msr)
}

plot_groups <- resolve_plot_groups(
  load_stage$data,
  final_ref = calc_stage$final_ref,
  final_tgt = calc_stage$final_tgt
)

out_path <- normalizePath(out_arg, winslash = "/", mustWork = FALSE)
out_dir <- dirname(out_path)
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}
if (grepl("/output/\\.preview_chat$|\\\\output\\\\\\.preview_chat$", normalizePath(out_dir, winslash = "/", mustWork = FALSE))) {
  try(suppressWarnings(Sys.chmod(out_dir, mode = "0700")), silent = TRUE)
}

if (.Platform$OS.type == "windows" && basename(out_dir) == ".preview_chat") {
  try(system2("attrib", c("+h", shQuote(out_dir))), silent = TRUE)
}

generate_composite_plot_png(
  dt = load_stage$data,
  msr = preview_msr,
  msr_title = preview_msr,
  ref_groups = plot_groups$ref,
  tgt_groups = plot_groups$tgt,
  png_path = out_path,
  width_in = plot_w,
  height_in = plot_h,
  dpi = as.numeric(ppt_cfg$plot_dpi),
  ppt_cfg = ppt_cfg
)

elapsed_sec <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
cat("PREVIEW_PNG=", out_path, "\n", sep = "")
cat("PREVIEW_MSR=", preview_msr, "\n", sep = "")
cat("PREVIEW_ELAPSED_SEC=", elapsed_sec, "\n", sep = "")