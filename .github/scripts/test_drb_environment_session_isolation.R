library_paths <- gsub("\\\\", "/", .libPaths())
stopifnot(!any(grepl("/DRB/R-", library_paths, fixed = TRUE)))
cat("ORDINARY_R_SESSION_ISOLATION_OK\n")
