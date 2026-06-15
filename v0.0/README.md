# 🧠 PatchMaster Analysis Toolkit (Igor Pro)

Custom Igor Pro toolkit for analyzing electrophysiological recordings exported from PatchMaster.

---

## 🚀 Features

- Batch processing of traces using prefix-based selection  
- Baseline correction and linear drift removal  
- Peak amplitude extraction (corrected and raw)  
- Passive membrane property estimation (Cm, Rs)  
- Organized output structure for downstream analysis  

---
## ⚙️ Installation

1. Copy all `.ipf` files into your Igor Pro **User Procedures** folder  

2. Restart Igor Pro (or recompile procedures)

3. Open the panel from the menu:

Analysis → Nanion → Panel

---

## 🧩 Workflow

The core analysis pipeline follows these steps:

Trace selection → Baseline correction → Linear detrending → Peak extraction → Passive property estimation

---
## ▶️ Example Usage

### 1. Export data from PatchMaster

Experiments must be exported from PatchMaster using the following settings:

- Export one group at a time  
- Format: **Igor**
- Enable:
  - **Trace relative to sweep**
  - **Allow data access**
- Export mode: **Traces and Stimulus**  


These settings ensure compatibility with the analysis pipeline and proper reconstruction of traces in Igor Pro.

---

### 2. Load data in Igor Pro

- Open the exported file by **double-clicking the PatchMaster-generated file** (`.pxp`)
- This will load all waves into the **root** of the Data Browser (typically unorganized)

---

### 3. Define trace prefix
- The prefix corresponds to the PatchMaster group name
- All matching traces will be selected for analysis

---

## 4. 📁 Folder Structure
Root/

├─ Trace/ # Raw traces

├─ Stimulus / # Stimulus

├─ Analysis/ # Output results

└─ Packages/

└─ Wave_prefix

---
## 5. Output

Results are saved in the Analysis/ folder:

- peak_net → corrected peak amplitudes.
- Netpeak → [corrected, fit, raw] values.
- cm → membrane capacitance.
- rs → series resistance.
- Netpeak_index → index of maximum response.

---

## ⚠️ Design Notes

- Some dependencies (e.g., `Wave_prefix`) are intentionally implicit  
- Folder structure is partially hardcoded to match experimental organization  
- Certain legacy functions are preserved separately for reference  

---

## 🛠️ Requirements

- Igor Pro  
- PatchMaster-exported data  
- Consistent trace naming convention  

---

## 🔮 Future Improvements

- Parameterization of folder structure  
- Improved validation of dependencies  
- Modularization of analysis steps  
- Export compatibility (e.g., CSV, HDF5 for Python/R workflows)  
