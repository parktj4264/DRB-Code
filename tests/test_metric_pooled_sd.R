# Pooled SD metric formula and edge-case tests
source("src/metrics/metric_pooled_sd_delta.R")

pair_dt <- data.frame(
  mean_ref = 10,
  mean_tgt = 13,
  sd_ref = 2,
  sd_tgt = 4,
  n_ref = 5,
  n_tgt = 7
)

expected <- (13 - 10) / sqrt(((5 - 1) * (2 ^ 2) + (7 - 1) * (4 ^ 2)) / (5 + 7 - 2))
actual <- metric_pooled_sd_delta(pair_dt)

stopifnot(is.numeric(actual))
stopifnot(length(actual) == 1)
stopifnot(abs(actual - expected) < 1e-10)

edge_dt <- data.frame(
  mean_ref = c(1, 1, 1, 1),
  mean_tgt = c(2, 2, 2, 2),
  sd_ref = c(1, 0, NA, 1),
  sd_tgt = c(1, 1, 1, NA),
  n_ref = c(1, 3, 3, 3),
  n_tgt = c(1, 3, 3, -1)
)

edge_actual <- metric_pooled_sd_delta(edge_dt)
stopifnot(is.numeric(edge_actual))
stopifnot(length(edge_actual) == nrow(edge_dt))
stopifnot(all(edge_actual == 0))

cat("PASS: test_metric_pooled_sd.R\n")
