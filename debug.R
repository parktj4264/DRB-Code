source('src/00_libs.R')
source('src/00_utils.R')
source('src/01_load_data.R')
source('src/02_calc_sigma.R')
RAW_FILENAME <- 'raw.csv'
ROOT_FILENAME <- 'ROOTID.csv'
load_res <- load_and_filter_data(paste0('data/', RAW_FILENAME), paste0('data/', ROOT_FILENAME), 130)
dt <- load_res$data
calc_res <- calculate_sigma(dt, load_res$msr_cols, 0.5, NULL, NULL)
result_dt <- calc_res$res
msr_info <- data.table::fread('data/msrinfo.csv')
cat("result_dt$MSR class:", class(result_dt$MSR), "\n")
cat("sample result_dt$MSR:\n")
print(head(result_dt$MSR))
cat("msr_info$ITEM_ID class:", class(msr_info$ITEM_ID), "\n")
cat("sample msr_info$ITEM_ID:\n")
print(head(msr_info$ITEM_ID))
merged_dt <- merge(result_dt, msr_info, by.x='MSR', by.y='ITEM_ID', all.x=TRUE)
cat("merged_dt Category2 NAs:", sum(is.na(merged_dt$Category2)), "\n")
cat("sample merged_dt Category2:\n")
print(head(merged_dt$Category2))

if("Category2" %in% names(merged_dt)) {
  cat2_list <- unique(merged_dt[!is.na(Category2), Category2])
  cat("cat2_list:\n")
  print(cat2_list)
  
  for(c2 in cat2_list) {
      sub_dt <- merged_dt[Category2 == c2]
      sub_dt <- sub_dt[order(-Abs_Sigma_Score)]
      top8_msrs <- head(sub_dt$MSR, 8)
      cat("Top 8 MSRs for", c2, ":", paste(top8_msrs, collapse=","), "\n")
  }
}
