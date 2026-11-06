# Counting on suppression

This project is the repository for the data, scripts, and materials used for the Stage 1 Registered Report entitled: "***Counting on Suppression: Does Learning to Ignore Distractors Depend on Executive Resources? A Registered Report***".

### Project Structure ###

The project is organized into the following main sections:

- **Input**: Data used in the analyses.
    - *load_group*: Data of the load group, one CSV per session as saved by the PsychoPy task (empty until the data are collected).
    - *vicente_conesa_2023*: Columns used from the trial-level data of Experiments 1-3 of Vicente-Conesa et al. (2023), the control group of the study, and from the awareness test of Experiment 1.
    - *meta_analysis*: Statistics of Gao and Theeuwes (2020) used in the meta-analysis: the suppression effects read from their figures and their *t* values (`gao2020_effects.csv`), and the error bars of their figures (`gao2020_figure_se.csv`).
    - `apaquarto_reference.docx`: Word template used to render the manuscript.
- **Output**: Results generated from **scripts**.
    - *analysis*: R objects of the analyses, used by the manuscript.
    - *simulations*: Replicates of the power and sensitivity simulations.
    - *figures*: Figures of the manuscript.
    - *manuscript*: Rendered manuscript.
- **Scripts**: Includes the scripts used to load and preprocess the data and to run the analyses.
- **Materials**: The PsychoPy task of the load group (`psychopy_task`, with its own README).
- **_extensions**: Quarto extension used to render the manuscript (`rr_executive_manuscript.qmd`) in APA style (`apaquarto`).
- **filters**: Lua filters that write references such as "Figure 1A" in the manuscript (`fig.lua`) and the landscape page of Table 1 in Word (`landscape.lua`).

##### Scripts Folder Structure #####

- *control_models.R*: Models of the control group, whose parameters generate the simulated data of the power analysis (**Sample Size Rationale**), and the suppression effect of the control group (**Control Group**).
- *meta_analysis.R*: Meta-analysis of previous load manipulations (**Appendix**), which sets the effect sizes of H1 and H2. The data of Vicente-Conesa et al. (2024) are not part of the repository: the script downloads them from OSF.
- *power.R*: Simulation-based power analysis of H1 and H2 and power of the outcome-neutral criteria (**Sample Size Rationale**).
- *sensitivity.R*: Sensitivity of the exploratory analyses (**Sample Size Rationale**).
- *analysis.R*: Preregistered analyses (**Statistical Analyses**): pre-processing and exclusions, hypothesis tests, outcome-neutral criteria, and exploratory analyses. While `Input/load_group` is empty, it runs on a load group simulated in the format of the task, so it can be applied without changes once the data are collected.
- *figures.R*: Figures 1 and 2, and the figure of the results (on the simulated load group until the data are collected).

All the above .R files call `source(...)` to run *functions.R*, where helper functions are loaded into the workspace, and those that use the control group also run *load_data.R*, where its data are loaded and preprocessed. `run_all.R` runs all the scripts (cached results in **Output** are used when available).

### How to Reproduce ###

The scripts need **R** (version 4.3.1), **CmdStan** with `cmdstanr` (for `brms`), and **Quarto** (version 1.7) with a LaTeX distribution. Each script installs and loads its packages with `pacman`.

1. Download or clone the repository and open `rr_executive_vsl.Rproj`.
2. Run `run_all.R`. The results of every script are cached in `output/analysis`; set `force_main <- TRUE` to run the analyses again. The simulation of H1 and H2 in `power.R` takes about 16 h on 18 cores, so its replicates are kept in `output/simulations` and are only simulated again if that file is removed. If `meta_analysis.R` runs and `Input/vicente_conesa_2024/data.csv` is missing, it downloads that file from OSF with `osfr`. It never overwrites or removes the local copy. The results of `analysis.R`, which run on the simulated load group, are not part of the repository: `run_all.R` generates them, together with the figure of the results.
3. Render the manuscript with `quarto render rr_executive_manuscript.qmd --to apaquarto-pdf`.

### License ###

Code and materials are released under a [CC BY 4.0](LICENSE.md) license. The data in **Input** come from Vicente-Conesa et al. (2023; see Links) and Gao and Theeuwes (2020), which should be cited when the data are used.

### Links ###

- Stage 1 registration: PCI RR will preregister the approved protocol on OSF at in-principle acceptance
- Zenodo repository: https://doi.org/10.5281/zenodo.XXXXXXX
- Data of Vicente-Conesa et al. (2023): <https://osf.io/xtsa2/>
- Data of Vicente-Conesa et al. (2024): <https://osf.io/b8g2v/>
