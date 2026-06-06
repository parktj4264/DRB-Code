# DRB-Code (?쒓뎅??

DRB-Code??湲곗?援?reference)怨?鍮꾧탳援?target) 媛?痢≪젙媛??대룞??鍮꾧탳 遺꾩꽍?섎뒗 R 湲곕컲 ?뚯씠?꾨씪?몄엯?덈떎.

?몄뼱:
- English: README.md
- Korean: docs/ko/README.md

?꾩옱 ?듭떖 ?숈옉:
- 二쇱슂 ?섏궗寃곗젙 吏?? `metric_one_sigma`
- `Sigma_Score`, `Abs_Sigma_Score`??`metric_one_sigma` 湲곕컲
- 異붽? 硫뷀듃由?? 肄붿뼱 ?섏궗寃곗젙 濡쒖쭅??諛붽씀吏 ?딄퀬 異쒕젰 而щ읆?쇰줈 ?뺤옣 媛??
- 硫붿씤 ?ㅽ뻾 ?먮쫫??PPT ?붿빟 ?앹꽦 ?ы븿

## ?꾨줈?앺듃 援ъ“

```text
DRB-Code/
  data/                     # ?낅젰 ?뚯씪 (raw.csv, ROOTID.csv, optional msrinfo.csv)
  output/                   # 遺꾩꽍 寃곌낵臾?
  src/
    bootstrap/
      libs.R
      utils.R
      runtime_config.R
    01_load_data.R
    02_calc_stats.R
    03_create_ppt.R
    metrics/                # metric_<name>.R ?뚮윭洹몄씤 ?뚯씪
  tests/                    # ?뚯뒪???ㅽ겕由쏀듃 諛??ㅽ뻾湲?
  run.R                     # ?ъ슜??硫붿씤 ?ㅽ뻾 吏꾩엯??遺꾩꽍)
  main.R                    # ?ㅼ??ㅽ듃?덉씠??
```

## 鍮좊Ⅸ ?쒖옉

1. `data/`???낅젰 ?뚯씪 諛곗튂:
- `raw.csv`
- `ROOTID.csv`
- optional `msrinfo.csv`

2. ?꾩슂 ??`run.R` ?뚮씪誘명꽣 ?섏젙.

3. `run.R` ?ㅽ뻾.

## `run.R` ?뚮씪誘명꽣

- `RAW_FILENAME`: `data/` ???낅젰 raw ?곗씠???뚯씪
- `ROOT_FILENAME`: `data/` ??洹몃９ 留ㅽ븨 ?뚯씪
- `GOOD_CHIP_LIMIT`: ?좏깮???꾪꽣 而룹삤??
- `SIGMA_THRESHOLD`: Up/Down ?먯젙 ?꾧퀎媛?
- `GROUP_REF_NAME`: ?좏깮??湲곗? 洹몃９
- `GROUP_TARGET_NAME`: ?좏깮??鍮꾧탳 洹몃９

## 異쒕젰臾?

- `output/results.csv`: 理쒖떊 寃곌낵 ?뚯씠釉?
- `output/results_<timestamp>/`: ?ㅽ뻾 ?꾩뭅?대툕 ?곗텧臾?
- `output/sigma_summary_latest.pptx`: 理쒖떊 PPT ?붿빟蹂?
- `output/snapshot_*.csv`: ?섎룄?곸쑝濡?git 異붿쟻?섎뒗 ?ㅻ깄???뚯씪

## 硫뷀듃由??뺤옣 (?묒뾽)

??硫뷀듃由?쓣 異붽??섎젮硫?`src/metrics/metric_custom.R`(?먮뒗 ?ㅻⅨ `metric_*.R` ?뚯씪)???⑥닔瑜?異붽??섏꽭??

?쒖?:
- ?⑥닔紐낆? `metric_`濡??쒖옉?댁빞 ??
- ?먮룞 濡쒕뵫 洹쒖튃:
  `src/metrics/` ?꾨옒??`.R` ?뚯씪? 硫뷀듃由??붿쭊??紐⑤몢 source ?쒕떎.
- ?먮룞 ?몄떇 洹쒖튃:
  ?⑥닔紐??⑦꽩??`^metric_`???⑥닔留?硫뷀듃由?쑝濡??섏쭛?쒕떎.
- 吏???쒓렇?덉쿂:
  `metric_x(pair_stats)` ?먮뒗 `metric_x(pair_stats, raw_access)`
- `pair_stats` 而щ읆:
  `MSR`, `ref_group`, `target_group`, `mean_ref`, `mean_tgt`, `sd_ref`, `sd_tgt`, `n_ref`, `n_tgt`
- `raw_access` ?ы띁:
  `has_pair(msr, ref_group, target_group)`,
  `get_pair(msr, ref_group, target_group)`,
  `get_group_values(msr, group_name)`,
  `get_group_meta(msr, group_name, include_values = FALSE)`,
  `get_group_data(msr, group_name)`,
  `get_pair_meta(msr, ref_group, target_group, include_values = FALSE)`
- `raw_access` 硫뷀? ?곗씠??踰붿쐞:
  `PARTID` ?댁쟾 而щ읆? ?꾨? 硫뷀? 而⑦뀓?ㅽ듃濡?蹂댁〈?섏뼱 議고쉶 媛???? `EDGE`, `Radius`, `LOTID`, `WF`, bin 而щ읆, 湲고? ?ъ슜???뺤쓽 硫뷀? 而щ읆)
- 異쒕젰: 湲몄씠媛 ?뺥솗??`nrow(pair_stats)`??numeric 踰≫꽣
- 寃곌낵 而щ읆:
  `metric_<name>` ?⑥닔 1媛쒕떦 `metric_<name>`, `abs_metric_<name>` 2媛?而щ읆???앹꽦??
- ?좏슚?섏? ?딆? 媛?non-finite)? `0`?쇰줈 移섑솚 沅뚯옣
- ?ы띁/?좏떥 ?⑥닔??異붽??대룄 ?섏?留??⑥닔紐낆뿉 `metric_` ?묐몢?대? 遺숈씠吏 留?寃?

?붿쭊 洹쇨굅 肄붾뱶:
- ?뚯씪 濡쒕뵫: `src/02_calc_stats.R` (`list.files(...\\.R$)`, `sys.source(...)`)
- 硫뷀듃由??⑥닔 ?섏쭛: `src/02_calc_stats.R` (`ls(..., pattern = "^metric_")`)
- 異쒕젰 而щ읆 ?앹꽦: `src/02_calc_stats.R` (`final_dt[, (metric_name) := ...]`, `abs_` 而щ읆)

?덉떆:

```r
metric_my_stat <- function(pair_stats) {
  score <- (as.numeric(pair_stats$mean_tgt) - as.numeric(pair_stats$mean_ref)) /
    as.numeric(pair_stats$sd_ref)
  score[!is.finite(score)] <- 0
  as.numeric(score)
}
```

## ?뚯뒪??

?꾩껜 ?뚯뒪???ㅽ뻾:

```bash
Rscript tests/run_tests.R
```

?꾩옱 ?뚯뒪??踰붿쐞:
- core one_sigma ?뚭? 寃利?
- raw_access 硫뷀? ?곗씠???묎렐 寃利?`EDGE`/`Radius` ?덉떆)
- ?ㅽ궎留??섏? end-to-end 寃利?
- pooled SD 硫뷀듃由?寃利??대떦 釉뚮옖移?湲곗?)

## 臾몄꽌

- 釉뚮옖移??꾨왂 (EN): docs/BRANCH_STRATEGY.md
- 釉뚮옖移??꾨왂 (KOR): docs/ko/BRANCH_STRATEGY.md
- 硫뷀듃由??뚮윭洹몄씤 ?쒖? (EN): docs/METRIC_CONTRACT.md
- 硫뷀듃由??뚮윭洹몄씤 ?쒖? (KOR): docs/ko/METRIC_CONTRACT.md

## 釉뚮옖移??뚰겕?뚮줈??

- 由대━利?釉뚮옖移? `main`
- 踰좎씠?ㅻ씪???듯빀 釉뚮옖移? `develop` (?대┛ ?곹깭 ?좎?, direct push 湲덉?)
- ?묒뾽 釉뚮옖移?`feature/*`: ?쒖뒪???붿??덉뼱留?諛??명봽???묒뾽
- ?묒뾽 釉뚮옖移?`stats/*`: ?듦퀎/硫뷀듃由?紐⑤뜽 濡쒖쭅 ?묒뾽
- ?뚮뱶諛뺤뒪 釉뚮옖移?`exp/*`: ?쇳빀 ?듯빀 ?뚯뒪?몄슜 ?꾩떆 釉뚮옖移?
- ?덉쟾 釉뚮옖移?`backup/*`: 怨좎쐞??援ъ“ 蹂寃????꾩떆 ?ㅻ깄??釉뚮옖移?
- ?듭떖 洹쒖튃: `exp/*`??`develop`?쇰줈 蹂묓빀?섏? ?딆쑝硫? 寃利앸맂 `feature/*` ?먮뒗 `stats/*`留?PR濡?`develop`??蹂묓빀
- ?곸꽭 ?뺤콉: docs/BRANCH_STRATEGY.md


