local({
  r_minor <- paste0(
    R.version$major,
    ".",
    sub("^([0-9]+).*", "\\1", R.version$minor)
  )
  profile <- switch(
    r_minor,
    "4.1" = "r-4.1",
    "4.5" = "r-4.5",
    NULL
  )

  if (is.null(profile)) {
    message(
      "[DRB-Code] R ", r_minor,
      " is not a reviewed version. Use R 4.1.x or R 4.5.x."
    )
  } else {
    # renv profiles isolate the lockfile and package library by supported R
    # minor version. This is the R equivalent of choosing a Conda env.
    Sys.setenv(RENV_PROFILE = profile)
    # Package needs are held in a runtime manifest, which renv's static
    # dependency scanner cannot fully infer. 00_setup_environment.R performs
    # the stricter lockfile version check instead.
    Sys.setenv(RENV_CONFIG_SYNCHRONIZED_CHECK = "FALSE")
    source("renv/activate.R")
    message(
      "[DRB-Code · R ", as.character(getRversion()),
      " · renv profile ", profile, " active]"
    )
  }
})
