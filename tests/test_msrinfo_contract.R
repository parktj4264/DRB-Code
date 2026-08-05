# Regression test: msrinfo SPEC_TYPE has a small, explicit directional contract.
source("src/bootstrap/utils.R", local = environment())

raw_values <- c("u", " D ", "n", "", NA_character_)
stopifnot(identical(
  normalize_msrinfo_spec_type(raw_values),
  c("U", "D", "N", "", "")
))
stopifnot(identical(
  msrinfo_spec_type_label_ko(raw_values),
  c("망소", "망대", "망목", "", "")
))

invalid_error <- tryCatch(
  {
    normalize_msrinfo_spec_type(c("U", "X"), context = "msrinfo.csv SPEC_TYPE")
    NULL
  },
  error = identity
)
stopifnot(inherits(invalid_error, "error"))
stopifnot(grepl("msrinfo.csv SPEC_TYPE", conditionMessage(invalid_error), fixed = TRUE))
stopifnot(grepl("Invalid value(s): X", conditionMessage(invalid_error), fixed = TRUE))

cat("PASS: test_msrinfo_contract.R\n")
