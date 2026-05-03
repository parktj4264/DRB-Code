run_test <- function(test_file) {
  cat("[RUN] ", test_file, "\n", sep = "")
  source(test_file, local = new.env(parent = globalenv()))
}

test_files <- c(
  "tests/test_regression_glass_priority.R",
  "tests/test_metric_dual_mode_raw_access.R",
  "tests/test_metric_raw_fast_smoke.R",
  "tests/test_e2e_output_schema.R"
)

for (test_file in test_files) {
  run_test(test_file)
}

cat("All tests passed.\n")
