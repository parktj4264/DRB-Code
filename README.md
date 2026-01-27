# Semiconductor Defect Analysis (DRB-Code)

This R project is designed for high-performance anomaly detection in large-scale semiconductor metrology data (~4GB). It calculates the **Sigma Score (Glass's Delta)** between Reference and Target groups using parallel processing.

[🇰🇷 Korean README (한글)](README_KR.md)

## 🚀 How to Run

1.  **Prepare Data**:
    *   Place your large raw data file in `data/` (e.g., `data/raw.csv`).
    *   Place your mapping file in `data/` (e.g., `data/ROOTID.csv`).
    *   *Note: `ROOTID.csv` must contain `ROOTID` and `GROUP` columns.*

2.  **Configure & Execute**:
    *   Open **`run.R`**.
    *   Adjust filenames (`RAW_FILENAME`, `ROOT_FILENAME`) if needed.
    *   Set group defaults (`GROUP_REF_NAME`, `GROUP_TARGET_NAME`) or leave `NULL` for auto-detection.
    *   Run the script!

3.  **Check Results**:
    *   Results are saved to `output/results.csv` (configurable).
    *   Columns include `Mean_<Ref>`, `Mean_<Tgt>`, `SD_<Ref>`, `Sigma_Score`, and `Direction`.

## 📂 Project Structure

```bash
DRB-Code/
├── run.R                # [USER] Entry point. Set parameters here.
├── main.R               # [CORE] Orchestrator. Sources modules and runs logic.
├── data/                # [INPUT] Input CSV files.
├── output/              # [OUTPUT] Generated CSV results.
└── src/
    ├── 00_libs.R        # Package loader ("Invincible Version")
    ├── 00_utils.R       # Helper functions (Logging, Safe Core Count)
    ├── 01_load_data.R   # Data ingestion (Memory optimized filtering)
    └── 02_calc_sigma.R  # Parallel Sigma Score Calculation
```

## ✨ Key Features

*   **⚡ Parallel Processing**: Uses `future` and `data.table` for maximum speed.
*   **🛡️ Memory Safety**: Automatically adjusts core usage based on file size.
*   **📊 Robust Filtering**: Fast `LDS Hot Bin` filtering before heavy processing.
*   **📦 Smart Dependencies**: Auto-installs and loads required packages via `src/00_libs.R`.
