# Test the tracked corporate PPT template remains officer-compatible and
# exposes the placeholders used by the generator.
suppressPackageStartupMessages(library(officer))
source("src/03_create_ppt.R", local = environment())

tol <- 1e-6
template_path <- here::here("data", "template_16_9.pptx")
stopifnot(file.exists(template_path))

template_ppt <- officer::read_pptx(template_path)
template_size <- officer::slide_size(template_ppt)
stopifnot(abs(template_size$width - 13.33333) < 1e-4)
stopifnot(abs(template_size$height - 7.5) < tol)
stopifnot(length(template_ppt) == 1L)

layout_names <- officer::layout_summary(template_ppt)
stopifnot(any(
  layout_names$layout == "Title and Content" &
    layout_names$master == "Office Theme"
))
stopifnot(any(
  layout_names$layout == "Title Only" &
    layout_names$master == "Office Theme"
))

summary_layout <- officer::layout_properties(
  template_ppt,
  layout = "Title and Content",
  master = "Office Theme"
)
detail_layout <- officer::layout_properties(
  template_ppt,
  layout = "Title Only",
  master = "Office Theme"
)

fixed_chrome_labels <- c(
  "DRB_Divider",
  "DRB_Samsung_Logo",
  "DRB_Footer_Message",
  "DRB_Confidential"
)
stopifnot(all(fixed_chrome_labels %in% summary_layout$ph_label))
stopifnot(all(fixed_chrome_labels %in% detail_layout$ph_label))

summary_title <- summary_layout[
  summary_layout$ph_label == "DRB_Title_Placeholder",
]
summary_body <- summary_layout[
  summary_layout$ph_label == "DRB_Body_Placeholder",
]
detail_title <- detail_layout[
  detail_layout$ph_label == "DRB_Title_Placeholder",
]
detail_body <- detail_layout[
  detail_layout$ph_label == "DRB_Body_Placeholder",
]

stopifnot(nrow(summary_title) == 1L)
stopifnot(nrow(summary_body) == 1L)
stopifnot(nrow(detail_title) == 1L)
stopifnot(nrow(detail_body) == 1L)
stopifnot(abs(summary_title$offx - 0.2952756) < tol)
stopifnot(abs(summary_title$offy - 0.3740157) < tol)
stopifnot(abs(summary_title$cy - 0.5314961) < tol)
stopifnot(abs(summary_body$offx - 0.2952756) < tol)
stopifnot(abs(summary_body$offy - 1.0314961) < tol)
stopifnot(abs(summary_body$cx - 12.598425) < tol)
stopifnot(abs(detail_title$offx - summary_title$offx) < tol)
stopifnot(abs(detail_body$offy - summary_body$offy) < tol)

cfg <- resolve_ppt_config(list(
  ppt_layout_mode = "template",
  slide_affiliation = "DRB Team"
))
generated_ppt <- read_pptx_for_generation(cfg)
stopifnot(length(generated_ppt) == 0L)
generated_ppt <- officer::add_slide(
  generated_ppt,
  layout = cfg$detail_slide_layout,
  master = cfg$ppt_master
)
generated_ppt <- add_ppt_slide_header(
  generated_ppt,
  cfg,
  bullets = c("Template contract check")
)

test_pptx_path <- tempfile(fileext = ".pptx")
on.exit(unlink(test_pptx_path, force = TRUE), add = TRUE)
print(generated_ppt, target = test_pptx_path)

generated_summary <- officer::pptx_summary(
  officer::read_pptx(test_pptx_path)
)
generated_text <- paste(generated_summary$text, collapse = "\n")
stopifnot(grepl(cfg$slide_title, generated_text, fixed = TRUE))
stopifnot(grepl("Template contract check", generated_text, fixed = TRUE))
stopifnot(grepl("DRB Team", generated_text, fixed = TRUE))

cat("PASS: test_ppt_template_contract.R\n")
