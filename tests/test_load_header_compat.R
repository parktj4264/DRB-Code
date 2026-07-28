# Regression test: use fread's normal one-row parser path for header inspection.
source("src/01_load_data.R", local = environment())

csv_path <- tempfile("drb_header_compat_", fileext = ".csv")
header_only_path <- tempfile("drb_header_only_", fileext = ".csv")
on.exit(unlink(c(csv_path, header_only_path), force = TRUE), add = TRUE)

writeLines(
  c(
    'LOTID,ROOTID,PARTID,"MSR,WITH,COMMAS",MSR_2',
    'L1,W1,P1,1.25,2.5'
  ),
  csv_path,
  useBytes = TRUE
)
writeLines("ROOTID,PARTID,MSR_1", header_only_path, useBytes = TRUE)

header_dt <- read_csv_header(csv_path)
stopifnot(data.table::is.data.table(header_dt))
stopifnot(nrow(header_dt) == 0L)
stopifnot(identical(
  names(header_dt),
  c("LOTID", "ROOTID", "PARTID", "MSR,WITH,COMMAS", "MSR_2")
))

header_only_dt <- read_csv_header(header_only_path)
stopifnot(nrow(header_only_dt) == 0L)
stopifnot(identical(names(header_only_dt), c("ROOTID", "PARTID", "MSR_1")))

cat("PASS: test_load_header_compat.R\n")
