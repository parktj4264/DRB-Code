source("src/bootstrap/libs.R", local = environment())
source("src/bootstrap/utils.R", local = environment())
source("src/bootstrap/io_utils.R", local = environment())
source("src/04_create_spotfire.R", local = environment())

run_spotfire_bundle_test <- function() {
stopifnot(isTRUE(normalize_spotfire_generation_flag(TRUE)))
stopifnot(!normalize_spotfire_generation_flag(FALSE))
stopifnot(!normalize_spotfire_generation_flag("false"))
stopifnot(isTRUE(normalize_spotfire_generation_flag("1")))
stopifnot(isTRUE(normalize_spotfire_generation_flag(NULL)))
stopifnot(get_spotfire_raw_output_name("raw.csv") == "raw_spotfire.csv")
stopifnot(get_spotfire_raw_output_name("data_wow.csv") == "data_wow_spotfire.csv")

test_dir <- tempfile("drb_spotfire_bundle_")
stopifnot(dir.create(test_dir, recursive = TRUE, showWarnings = FALSE))
on.exit(unlink(test_dir, recursive = TRUE, force = TRUE), add = TRUE)
source_raw <- file.path(test_dir, "source_raw.csv")
writeLines(c(
  "LOTID,WF,PARTID,M1,M2",
  "L1,1,P1,0,0",
  "L2,2,P2,1,2"
), source_raw, useBytes = TRUE)

schema <- build_spotfire_raw_schema(source_raw)
stopifnot(identical(schema$TYPE, c("String", "Integer", "String", "Real", "Real")))
stopifnot(identical(schema$IS_MSR, c(FALSE, FALSE, FALSE, TRUE, TRUE)))

raw_out <- file.path(test_dir, "raw.csv")
raw_first <- write_spotfire_raw_csv(source_raw, raw_out)
stopifnot(isTRUE(raw_first$updated))
raw_lines <- readLines(raw_out, warn = FALSE)
stopifnot(raw_lines[[1L]] == "LOTID,WF,PARTID,M1,M2")
stopifnot(raw_lines[[2L]] == "String,Integer,String,Real,Real")
stopifnot(identical(raw_lines[-c(1L, 2L)], readLines(source_raw, warn = FALSE)[-1L]))
raw_mtime <- file.info(raw_out)$mtime
raw_second <- write_spotfire_raw_csv(source_raw, raw_out)
stopifnot(!raw_second$updated)
stopifnot(identical(file.info(raw_out)$mtime, raw_mtime))

result_dt <- data.table::data.table(
  MSR = c("M1", "M2"),
  GOOBAE_Category1 = c("WLS", "WLS"),
  GOOBAE_Category2 = c("1WL", "1WL"),
  GOOBAE_NAME = c("WL000", "WL001"),
  GOOBAE_ORDER = c(1, 2)
)
raw_dt <- data.table::data.table(
  GROUP = c("A", "A", "B"),
  M1 = c(1, 3, 5),
  M2 = c(2, NA, 8)
)
root_source <- file.path(test_dir, "ROOTID.csv")
data.table::fwrite(data.table::data.table(ROOTID = c("R1", "R2"), GROUP = c("A", "B")), root_source)
goobae <- build_spotfire_goobae_table(result_dt, raw_dt)
stopifnot(identical(names(goobae), names(empty_spotfire_goobae_table())))
stopifnot(nrow(goobae) == 4L)
stopifnot(goobae[MSR == "M1" & GROUP == "A", VALUE] == 2)
stopifnot(goobae[MSR == "M1" & GROUP == "B", VALUE] == 5)
stopifnot(goobae[MSR == "M2" & GROUP == "A", VALUE] == 2)
stopifnot(goobae[MSR == "M2" & GROUP == "B", VALUE] == 8)

bundle_dir <- file.path(test_dir, "spotfire")
stopifnot(dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE))
writeLines("legacy", file.path(bundle_dir, "raw.csv"))
bundle <- write_spotfire_bundle(
  result_dt = result_dt,
  sigma_dt = data.table::data.table(MSR = c("M1", "M2"), sigma_score = c(0.1, 0.2)),
  dt = raw_dt,
  raw_path = source_raw,
  root_path = root_source,
  output_dir = bundle_dir
)
expected_paths <- file.path(bundle_dir, c(
  "results.csv", "source_raw_spotfire.csv", "rootid.csv", "goobae.csv", "sigma_score_raw.csv"
))
stopifnot(all(file.exists(expected_paths)))
stopifnot(basename(bundle$raw_path) == "source_raw_spotfire.csv")
stopifnot(isTRUE(bundle$legacy_raw_removed))
stopifnot(!file.exists(file.path(bundle_dir, "raw.csv")))
stopifnot(identical(data.table::fread(file.path(bundle_dir, "rootid.csv")), data.table::fread(root_source)))
stopifnot(all(dirname(normalizePath(expected_paths, winslash = "/")) == normalizePath(bundle_dir, winslash = "/")))
stopifnot(length(list.files(bundle_dir, pattern = "\\.(tmp|bak)$")) == 0L)
}

run_spotfire_bundle_test()
cat("PASS: test_spotfire_bundle.R\n")
