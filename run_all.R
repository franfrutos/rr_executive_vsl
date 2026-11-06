## -----------------------------------------------------------------------------
## Author: Francisco Garre-Frutos
## -----------------------------------------------------------------------------

# Edit to run the analyses again even if cached results exist
force_main <- FALSE

dirs <- c("output/analysis", "output/figures", "output/manuscript", "output/models", "output/simulations")
for (dir in dirs) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
}

run_cached <- function(name, script) {
  if (force_main || !file.exists(file.path("output/analysis", paste0(name, ".rds")))) {
    message("Running ", script, "...")
    source(script, local = new.env())
  } else {
    message("Using cached results: output/analysis/", name, ".rds")
  }
}

# Models of the control group
run_cached("control_models", "scripts/control_models.R")

# Meta-analysis of previous load manipulations (Appendix)
run_cached("meta_analysis", "scripts/meta_analysis.R")

# Power of the confirmatory tests and of the outcome-neutral criteria. The
# simulation of H1 and H2 takes about 16 h on 18 cores; its replicates in
# output/simulations are reused
run_cached("power", "scripts/power.R")

# Sensitivity of the exploratory analyses (replicates in output/simulations)
run_cached("sensitivity", "scripts/sensitivity.R")

# Preregistered analyses (on a simulated load group until Input/load_group
# contains the data). Simulated results are not reused once the data exist
analysis_path <- "output/analysis/analysis.rds"
load_files <- list.files("Input/load_group", pattern = "^ast_.*\\.csv$")

if (length(load_files) > 0 && file.exists(analysis_path) && readRDS(analysis_path)$simulated) {
  file.remove(analysis_path)
}

run_cached("analysis", "scripts/analysis.R")

# Figures
message("Drawing the figures...")
source("scripts/figures.R", local = new.env())

# Versions of R and packages used to generate the results
writeLines(capture.output(sessionInfo()), "output/session_info.txt")

message("Pipeline completed.")
