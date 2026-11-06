## -----------------------------------------------------------------------------
## Author: Francisco Garre-Frutos
## -----------------------------------------------------------------------------

required_packages <- c(
  "here", "dplyr", "tidyr", "tibble", "ggplot2", "cowplot", "lme4",
  "lmerTest", "marginaleffects", "binom", "MASS", "glmmTMB"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    sprintf(
      "Missing required packages: %s",
      paste(missing_packages, collapse = ", ")
    )
  )
}

# MASS masks dplyr::select and glmmTMB is only needed by the awareness model, so
# both are only called with ::
suppressPackageStartupMessages(
  invisible(lapply(setdiff(required_packages, c("here", "MASS", "glmmTMB")), library, character.only = TRUE))
)

setwd(here::here())

# Plots ----
# Colour of the suppression effect in all the figures
supp_color <- "#762A83"

# Data functions ----
# Contrasts of Condition: suppression = LPDL - HPDL and capture = LPDL - ND
condition_contrasts <- function() {
  matrix(c(-2/3, 1/3, 1/3,
           1/3, 1/3, -2/3),
         ncol = 2, dimnames = list(c("HPDL", "LPDL", "ND"), c("suppression", "capture")))
}

# Variables of the LMMs: log RT, the contrasts as numeric columns (for the random
# part) and log time, which is 0 in the last block
add_model_vars <- function(d) {
  cm <- condition_contrasts()
  d$condition <- factor(d$condition, levels = rownames(cm))
  contrasts(d$condition) <- cm
  d %>%
    mutate(
      log_rt = log(rt),
      log_time_end = log(block) - log(6),
      suppression = cm[as.character(condition), "suppression"],
      capture = cm[as.character(condition), "capture"]
    )
}

# Pre-processing of the search task, the same for both groups. The 2.5 SDs are
# computed on the trials that pass the previous criteria
preprocess_search <- function(d) {
  d %>%
    group_by(participant_uid) %>%
    mutate(
      include = n() == 720 & mean(correct) >= .75,
      trimmed = !(block == 1 & trial_in_block <= 20) & correct == 1 & rt >= 200 & rt <= 3000,
      rt_mean = mean(rt[trimmed]),
      rt_sd = sd(rt[trimmed])
    ) %>%
    ungroup() %>%
    filter(include, trimmed, rt >= rt_mean - 2.5 * rt_sd, rt <= rt_mean + 2.5 * rt_sd) %>%
    add_model_vars()
}

# Smallest number of correct verifications above chance (one-sided binomial test)
min_correct <- function(n, alpha) {
  qbinom(1 - alpha, n, .5) + 1
}

# Simulated load group in the format of the task, to run analysis.R before the
# data are collected: new participants from the control model with time, with
# suppression attenuated as in H1 (r = .8) and no effect of the load on awareness
simulate_load_group <- function(params, aw_ctrl, raw_control, n = 160, r = .8, count_acc = .85) {
  set.seed(20261105)
  cm <- condition_contrasts()
  b <- params$beta
  re <- MASS::mvrnorm(n, mu = rep(0, ncol(params$Sigma_re)), Sigma = params$Sigma_re)

  search_acc <-
    raw_control %>%
    group_by(participant_uid, condition) %>%
    summarise(acc = mean(correct), .groups = "drop") %>%
    pivot_wider(names_from = condition, values_from = acc)

  bind_rows(lapply(seq_len(n), function(i) {
    hpdl <- sample(1:8, 1)
    acc <- search_acc[sample(nrow(search_acc), 1), ]

    trials <-
      tibble(
        block = rep(1:6, each = 120),
        trial_in_block = rep(1:120, 6),
        condition = unlist(lapply(1:6, function(x) sample(rep(c("ND", "HPDL", "LPDL"), c(40, 52, 28)))))
      ) %>%
      mutate(
        suppression = cm[condition, "suppression"],
        capture = cm[condition, "capture"],
        time = log(block) - log(6),
        rt = exp(
          b[["(Intercept)"]] + re[i, "(Intercept)"] +
            (b[["log_time_end"]] + re[i, "log_time_end"]) * time +
            (r * (params$a + params$s * time) + re[i, "suppression"]) * suppression +
            (b[["conditioncapture"]] + b[["conditioncapture:log_time_end"]] * time + re[i, "capture"]) * capture +
            rnorm(n(), 0, params$sigma)
        ),
        correct = rbinom(n(), 1, unlist(acc[condition])),
        correct = ifelse(rt > 3000, 0L, correct), # Time-outs
        rt_ms = ifelse(rt > 3000, NA, rt),
        participant = i,
        phase = "experimental"
      ) %>%
      dplyr::select(participant, phase, block, trial_in_block, condition, correct, rt_ms)

    verification <-
      tibble(participant = i, phase = "verification", verify_correct = rbinom(72, 1, count_acc))

    lambda <- rnorm(1, aw_ctrl$mu, aw_ctrl$sd)
    p_location <- exp(-lambda * circ_dist(1:8, hpdl))

    awareness <-
      tibble(participant = i, phase = "awareness", aware_r2 = sample(1:8, 1, prob = p_location))

    bind_rows(trials, verification, awareness) %>%
      mutate(hpdl = hpdl)
  }))
}

# Scores of each control participant, to express the simulated effects in ms.
# Learning: increase of suppression from block 1 to block 6
control_participant_scores <- function(control_clean) {
  overall <-
    control_clean %>%
    group_by(participant_uid, condition) %>%
    summarise(rt = mean(rt), .groups = "drop") %>%
    pivot_wider(names_from = condition, values_from = rt) %>%
    transmute(participant_uid, suppression_ms = LPDL - HPDL)

  learning <-
    control_clean %>%
    filter(condition %in% c("HPDL", "LPDL")) %>%
    group_by(participant_uid, block, condition) %>%
    summarise(rt = mean(rt), .groups = "drop") %>%
    pivot_wider(names_from = condition, values_from = rt) %>%
    group_by(participant_uid) %>%
    summarise(learning_ms = coef(lm(I(LPDL - HPDL) ~ log(block)))[[2]] * log(6), .groups = "drop")

  left_join(overall, learning, by = "participant_uid")
}

# Hedges' g_z of a within-participant effect with its 95% CI
g_z <- function(d, n) {
  j <- 1 - 3 / (4 * (n - 1) - 1)
  se <- sqrt(1 / n + d^2 / (2 * n))
  c(g = j * d, lo = j * (d - qnorm(.975) * se), hi = j * (d + qnorm(.975) * se))
}

# Model functions ----
# lmer fit with its warnings and messages captured instead of printed
fit_lmer_logged <- function(formula, data, REML = FALSE,
                            control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5)),
                            fun = lme4::lmer, ...) {
  warns <- character(0)
  msgs <- character(0)
  t0 <- Sys.time()
  fit <- withCallingHandlers(
    tryCatch(fun(formula, data = data, REML = REML, control = control, ...),
             error = function(e) e),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  list(fit = fit, warnings = warns, messages = msgs,
       seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")))
}

# A fit converges if lme4 gives no convergence message or warning and the
# optimizer code is 0; it is singular if isSingular(tol = 1e-4)
lmer_diagnostics <- function(res) {
  fit <- res$fit
  if (inherits(fit, "error")) {
    return(list(converged = FALSE, singular = NA, warnings = conditionMessage(fit)))
  }
  conv_msgs <- fit@optinfo$conv$lme4$messages
  list(converged = length(conv_msgs) == 0 && length(res$warnings) == 0 && fit@optinfo$conv$opt == 0,
       singular = isSingular(fit, tol = 1e-4),
       warnings = paste(unique(res$warnings), collapse = " | "))
}

# Random-effects structure of the control models: the first candidate that
# converges without a singular fit is kept. Fits cached in output/models
fit_control_model <- function(fixed, candidates, data, name) {
  for (m in names(candidates)) {
    path <- sprintf("output/models/%s_%s.rds", name, m)
    if (file.exists(path)) {
      res <- readRDS(path)
    } else {
      message("Fitting ", name, " ", m, "...")
      res <- fit_lmer_logged(as.formula(paste(fixed, "+", candidates[[m]])), data = data, REML = FALSE)
      saveRDS(res, path)
    }
    dg <- lmer_diagnostics(res)
    message(sprintf("%s %s: converged = %s, singular = %s", name, m, dg$converged, dg$singular))
    if (isTRUE(dg$converged) && !isTRUE(dg$singular)) {
      return(list(fit = res$fit, structure = m, random = candidates[[m]]))
    }
  }
  stop("No candidate random structure converged without a singular fit.")
}

# Row of the fixed-effects design for a group (-0.5 control, 0.5 load) and a condition
design_row <- function(fit, group_c, condition) {
  cm <- condition_contrasts()
  vals <- c("(Intercept)" = 1, group_c = group_c, suppression = cm[condition, "suppression"],
            capture = cm[condition, "capture"])
  vals["group_c:suppression"] <- group_c * vals[["suppression"]]
  vals["group_c:capture"] <- group_c * vals[["capture"]]
  x <- setNames(rep(0, length(fixef(fit))), names(fixef(fit)))
  x[intersect(names(vals), names(x))] <- vals[intersect(names(vals), names(x))]
  x
}

# Weights of an effect in the load group: effect + 0.5 x group x effect
load_weights <- function(fit, effect) {
  w <- setNames(rep(0, length(fixef(fit))), names(fixef(fit)))
  w[c(effect, paste0("group_c:", effect))] <- c(1, .5)
  w
}

# Effect in ms: sum of the back-transformed RTs of X_plus minus those of X_minus,
# with the SE by the delta method
ms_effect <- function(fit, X_plus, X_minus) {
  b <- fixef(fit)
  V <- as.matrix(vcov(fit))
  m_plus <- exp(drop(X_plus %*% b) + sigma(fit)^2 / 2)
  m_minus <- exp(drop(X_minus %*% b) + sigma(fit)^2 / 2)
  G <- colSums(X_plus * m_plus) - colSums(X_minus * m_minus)
  est <- sum(m_plus) - sum(m_minus)
  se <- sqrt(drop(t(G) %*% V %*% G))
  tibble(
    estimate_ms = est,
    ci_lower_ms = est - qnorm(.975) * se,
    ci_upper_ms = est + qnorm(.975) * se
  )
}

# Parameters of a control model used to simulate the data of both groups
control_params <- function(sel, control_clean) {
  b <- fixef(sel$fit)
  Sigma_re <- as.matrix(VarCorr(sel$fit)[[1]])
  attr(Sigma_re, "stddev") <- NULL
  attr(Sigma_re, "correlation") <- NULL
  list(
    random_structure = sel$random,
    beta = b,
    vcov_beta = as.matrix(vcov(sel$fit)),
    Sigma_re = Sigma_re,
    sigma = sigma(sel$fit),
    a = unname(b["conditionsuppression"]),
    s = ifelse("conditionsuppression:log_time_end" %in% names(b), unname(b["conditionsuppression:log_time_end"]), 0),
    n_participants = n_distinct(control_clean$participant_uid)
  )
}

# Power simulation ----
# Analysable trials of each control participant (condition and block), which
# the simulated participants reuse
make_skeletons <- function(control_clean) {
  sk <- control_clean %>%
    dplyr::select(participant_uid, block, condition, suppression, capture, log_time_end) %>%
    as.data.frame()
  lapply(split(sk, sk$participant_uid), function(x) {
    x$participant_uid <- NULL
    rownames(x) <- NULL
    x
  })
}

# Random-effects design columns, in the order of the covariance matrix
re_design <- function(d, re_names) {
  cols <- list(
    "(Intercept)" = rep(1, nrow(d)),
    "suppression" = d$suppression,
    "capture" = d$capture,
    "log_time_end" = d$log_time_end
  )
  do.call(cbind, cols[re_names])
}

# Data of both groups from the control model. The suppression effect of the load
# group is multiplied by r and its capture effect by r_capture. load_ids keeps
# the design of a cell fixed across replicates
simulate_power_data <- function(params, skeletons, n_load, r, load_ids = NULL, r_capture = 1) {
  ctrl_ids <- names(skeletons)
  if (is.null(load_ids)) load_ids <- sample(ctrl_ids, n_load, replace = TRUE)
  ids <- c(ctrl_ids, load_ids)
  n_c <- length(ctrl_ids)
  uid <- c(sprintf("C%03d", seq_len(n_c)), sprintf("L%03d", seq_len(n_load)))
  is_load_p <- rep(c(FALSE, TRUE), c(n_c, n_load))

  n_i <- vapply(skeletons[ids], nrow, integer(1))
  d <- do.call(rbind, unname(skeletons[ids]))
  d$participant_uid <- rep(uid, n_i)
  d$group_c <- rep(ifelse(is_load_p, .5, -.5), n_i)
  is_load <- d$group_c > 0

  b <- params$beta
  b0 <- function(term) if (term %in% names(b)) b[[term]] else 0
  k <- ifelse(is_load, r, 1)
  eta <- b[["(Intercept)"]] +
    ifelse(is_load, r_capture, 1) * b[["conditioncapture"]] * d$capture +
    b0("log_time_end") * d$log_time_end +
    b0("conditioncapture:log_time_end") * d$capture * d$log_time_end +
    k * (params$a * d$suppression + params$s * d$suppression * d$log_time_end)

  Sigma <- params$Sigma_re
  B <- matrix(MASS::mvrnorm(length(uid), mu = rep(0, ncol(Sigma)), Sigma = Sigma), ncol = ncol(Sigma))
  Z <- re_design(d, colnames(Sigma))
  idx <- rep(seq_along(uid), n_i)

  d$log_rt <- eta + rowSums(Z * B[idx, , drop = FALSE]) + rnorm(nrow(d), 0, params$sigma)
  attr(d, "load_ids") <- load_ids
  d
}

# Preregistered simplification of the random effects: the next structure is
# fitted if the previous one does not converge or is singular. The time-course
# model starts from the structure of its generator (the control model with time)
re_steps <- list(
  no_time = c("(1 + suppression + capture | participant_uid)", "(1 + suppression | participant_uid)",
              "(1 | participant_uid)"),
  time = c("(suppression + capture + log_time_end | participant_uid)",
           "(suppression + capture | participant_uid)", "(log_time_end | participant_uid)",
           "(1 | participant_uid)")
)

fit_lmer_planned <- function(dat, fixed, steps) {
  for (k in seq_along(steps)) {
    res <- fit_lmer_logged(as.formula(paste(fixed, "+", steps[[k]])), dat, REML = FALSE, fun = lmerTest::lmer)
    if (inherits(res$fit, "error")) next
    dg <- lmer_diagnostics(res)
    if ((isTRUE(dg$converged) && !isTRUE(dg$singular)) || k == length(steps)) {
      return(list(fit = res$fit, step = k, converged = isTRUE(dg$converged), singular = isTRUE(dg$singular),
                  warnings = dg$warnings))
    }
  }
  NULL
}

# The same simplification in the logistic regression of search accuracy
fit_glmer_planned <- function(dat, fixed, steps) {
  fit_glmer <- function(formula, data, REML, control) {
    lme4::glmer(
      formula,
      data = data,
      family = binomial,
      control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5))
    )
  }

  for (k in seq_along(steps)) {
    res <- fit_lmer_logged(as.formula(paste(fixed, "+", steps[[k]])), dat, fun = fit_glmer)
    if (inherits(res$fit, "error")) next
    dg <- lmer_diagnostics(res)
    if ((isTRUE(dg$converged) && !isTRUE(dg$singular)) || k == length(steps)) {
      return(list(fit = res$fit, step = k, converged = isTRUE(dg$converged), singular = isTRUE(dg$singular)))
    }
  }
  NULL
}

# lme4::refit() with the warnings kept, as in fit_lmer_logged()
refit_logged <- function(fit0, newresp) {
  warns <- character(0)
  t0 <- Sys.time()
  fit <- withCallingHandlers(
    tryCatch(lme4::refit(fit0, newresp = newresp), error = function(e) e),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) invokeRestart("muffleMessage")
  )
  list(fit = fit, warnings = warns, messages = character(0),
       seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")))
}

# Analysis of one simulated data set, as planned: H1 and the time course with
# one-sided Satterthwaite t tests, H2 with the TOST and ON2 one-sided. base: the
# maximal model, refitted in each replicate before trying simpler structures
fit_power_rep_lmer <- function(dat, delta, time = FALSE, base = NULL) {
  fixed <- if (time) "log_rt ~ group_c * (suppression + capture) * log_time_end" else "log_rt ~ group_c * (suppression + capture)"
  steps <- re_steps[[if (time) "time" else "no_time"]]
  t0 <- Sys.time()
  pf <- NULL
  if (!is.null(base)) {
    rf <- refit_logged(base, dat$log_rt)
    if (!inherits(rf$fit, "error")) {
      dg <- lmer_diagnostics(rf)
      if (isTRUE(dg$converged) && !isTRUE(dg$singular)) {
        pf <- list(fit = lmerTest::as_lmerModLmerTest(rf$fit), step = 1L, converged = TRUE, singular = FALSE,
                   warnings = dg$warnings)
      }
    }
    if (is.null(pf)) steps <- steps[-1] # the maximal structure failed: simplify
  }
  if (is.null(pf)) {
    pf <- tryCatch(fit_lmer_planned(dat, fixed, steps), error = function(e) NULL)
    if (!is.null(pf) && !is.null(base)) pf$step <- pf$step + 1L
  }
  out <- tibble(error = NA_character_, converged = NA, singular = NA, re_step = NA_integer_, warnings = NA_character_,
                est_gs = NA_real_, se_gs = NA_real_, df_gs = NA_real_, p_gs = NA_real_,
                est_gss = NA_real_, se_gss = NA_real_, df_gss = NA_real_,
                est_supp_load = NA_real_, se_supp_load = NA_real_, df_supp_load = NA_real_,
                p_noninf = NA_real_, p_nonsup = NA_real_, p_equiv = NA_real_,
                est_capt_load = NA_real_, se_capt_load = NA_real_, df_capt_load = NA_real_, p_capt_load = NA_real_,
                seconds = NA_real_)
  if (is.null(pf)) {
    out$error <- "no structure could be fitted"
    return(out)
  }
  fit <- pf$fit
  out$converged <- pf$converged
  out$singular <- pf$singular
  out$re_step <- pf$step
  out$warnings <- pf$warnings
  co <- summary(fit)$coefficients # Estimate, Std. Error, df, t value, Pr(>|t|)
  out$est_gs <- co["group_c:suppression", "Estimate"]
  out$se_gs <- co["group_c:suppression", "Std. Error"]
  out$df_gs <- co["group_c:suppression", "df"]
  out$p_gs <- pt(co["group_c:suppression", "t value"], co["group_c:suppression", "df"]) # H1: less suppression under load
  if (time) {
    out$est_gss <- co["group_c:suppression:log_time_end", "Estimate"]
    out$se_gss <- co["group_c:suppression:log_time_end", "Std. Error"]
    out$df_gss <- co["group_c:suppression:log_time_end", "df"]
  } else {
    w <- load_weights(fit, "suppression")
    df_c <- lmerTest::contest(fit, w, joint = FALSE)$df
    h <- marginaleffects::hypotheses(fit, hypothesis = unname(w), equivalence = c(-delta, delta), df = df_c)
    out$est_supp_load <- h$estimate
    out$se_supp_load <- h$std.error
    out$df_supp_load <- df_c
    out$p_noninf <- h$p.value.noninf
    out$p_nonsup <- h$p.value.nonsup
    out$p_equiv <- h$p.value.equiv
    w_capt <- load_weights(fit, "capture") # ON2
    df_capt <- lmerTest::contest(fit, w_capt, joint = FALSE)$df
    capt <- marginaleffects::hypotheses(fit, hypothesis = unname(w_capt), df = df_capt)
    out$est_capt_load <- capt$estimate
    out$se_capt_load <- capt$std.error
    out$df_capt_load <- df_capt
    out$p_capt_load <- pt(capt$estimate / capt$std.error, df_capt, lower.tail = FALSE)
  }
  out$seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

# One replicate. The design of a cell is drawn once from cell$seed, and replicate
# i simulates new responses from cell$seed + i (as in simr)
run_power_rep_lmer <- function(i, cell, params, skeletons, delta, time = FALSE) {
  key <- paste0("cell_", cell$cell_id)
  r_capture <- if (is.null(cell$r_capture)) 1 else cell$r_capture
  if (!exists(".base_fit", envir = .GlobalEnv) || get(".base_fit", envir = .GlobalEnv)$key != key) {
    set.seed(cell$seed)
    d0 <- simulate_power_data(params, skeletons, n_load = cell$n_load, r = cell$r, r_capture = r_capture)
    fixed <- if (time) "log_rt ~ group_c * (suppression + capture) * log_time_end" else "log_rt ~ group_c * (suppression + capture)"
    f_max <- as.formula(paste(fixed, "+", re_steps[[if (time) "time" else "no_time"]][[1]]))
    fit0 <- suppressWarnings(suppressMessages(
      lme4::lmer(f_max, data = d0, REML = FALSE, control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 1e5)))))
    assign(".base_fit", list(key = key, fit = fit0, load_ids = attr(d0, "load_ids")), envir = .GlobalEnv)
  }
  b <- get(".base_fit", envir = .GlobalEnv)
  set.seed(cell$seed + i)
  dat <- simulate_power_data(params, skeletons, n_load = cell$n_load, r = cell$r, load_ids = b$load_ids,
                             r_capture = r_capture)
  res <- fit_power_rep_lmer(dat, delta, time = time, base = b$fit)
  bind_cols(as_tibble(cell[c("cell_id", "n_load", "r")]),
            tibble(rep = i, seed = cell$seed + i, usable = is.na(res$error), n_control = length(skeletons)), res)
}

# Replicates of every cell in parallel, appended to `path` after each cell, so
# an interrupted run resumes where it stopped
run_cells <- function(cells, path, params, skeletons, delta, n_cores, time = FALSE) {
  done <- if (file.exists(path)) read.csv(path)[c("cell_id", "rep")] else data.frame(cell_id = numeric(0), rep = numeric(0))
  for (j in seq_len(nrow(cells))) {
    cell <- as.list(cells[j, ])
    todo <- setdiff(seq_len(cell$nsim), done$rep[done$cell_id == cell$cell_id])
    if (length(todo) == 0) next
    message(sprintf("[%s] cell %d: n_load = %d, r = %g, %d replicates", format(Sys.time(), "%H:%M:%S"),
                    cell$cell_id, cell$n_load, cell$r, length(todo)))
    cl <- parallel::makeCluster(n_cores)
    invisible(parallel::clusterCall(cl, setwd, getwd()))
    invisible(parallel::clusterEvalQ(cl, {
      suppressMessages(source("scripts/functions.R"))
      options(marginaleffects_safe = FALSE)
      NULL
    }))
    reps <- parallel::parLapplyLB(cl, todo, function(i, cell, params, skeletons, delta, time) {
      run_power_rep_lmer(i, cell, params, skeletons, delta, time = time)
    }, cell = cell, params = params, skeletons = skeletons, delta = delta, time = time)
    parallel::stopCluster(cl)
    write.table(bind_rows(reps), path, sep = ",", row.names = FALSE, col.names = !file.exists(path), append = file.exists(path))
  }
  read.csv(path)
}

# Power of each cell (reject: logical column with the decision of each
# replicate). Replicates in which no structure could be fitted count as
# non-rejections. Exact binomial 95% CI
power_summary <- function(reps, reject, ...) {
  reps %>%
    mutate(reject = usable & .data[[reject]] %in% TRUE) %>%
    group_by(...) %>%
    summarise(nsim = n(), n_reject = sum(reject), .groups = "drop") %>%
    mutate(power = n_reject / nsim,
           ci_lower = binom::binom.confint(n_reject, nsim, methods = "exact")$lower,
           ci_upper = binom::binom.confint(n_reject, nsim, methods = "exact")$upper)
}

# Power when the data only change in the fixed part: the fit is the same and only
# the tested coefficient shifts
shifted_power <- function(base, est, se, df, lower, shifts, alpha) {
  bind_rows(lapply(shifts, function(sh) {
    p <- pt((base[[est]] + sh) / base[[se]], base[[df]], lower.tail = lower)
    tibble(nsim = nrow(base), n_reject = sum(base$usable & p < alpha, na.rm = TRUE))
  })) %>%
    mutate(
      power = n_reject / nsim,
      ci_lower = binom::binom.confint(n_reject, nsim, methods = "exact")$lower,
      ci_upper = binom::binom.confint(n_reject, nsim, methods = "exact")$upper
    )
}

# Predictions of the awareness model in a group, with their 95% CIs from draws of
# the coefficients
aware_predictions <- function(m_aw, group_c, n_draws = 500) {
  set.seed(20261105)
  draws <- MASS::mvrnorm(n_draws, m_aw$b, m_aw$V)
  mu <- -(draws[, 1] + group_c * draws[, 2])
  p <- t(vapply(mu, function(m) p_dist_marginal(m, m_aw$sd) / k_dist, numeric(5)))
  p_location <- p_dist_marginal(-(m_aw$b[[1]] + group_c * m_aw$b[[2]]), m_aw$sd) / k_dist
  tibble(
    group_c = group_c,
    distance = 0:4,
    p_location = p_location,
    ci_lower = apply(p, 2, quantile, .025),
    ci_upper = apply(p, 2, quantile, .975)
  )
}

# One data set of ON1. Accuracy of each participant given by `accuracy`
simulate_on1 <- function(seed, accuracy, n_verif) {
  set.seed(seed)
  dat <- tibble(
    participant = factor(seq_along(accuracy)),
    correct = rbinom(length(accuracy), n_verif, accuracy),
    n = n_verif
  )

  fit <- suppressMessages(glmer(cbind(correct, n - correct) ~ 1 + (1 | participant), data = dat, family = binomial))
  b <- summary(fit)$coefficients[1, ]

  pnorm(b[["z value"]], lower.tail = FALSE) # A singular fit does not change this test
}

# Awareness model ----
# Gradient model of Franco-Martinez et al. (2025). dL: circular distance (0-4) of
# location l to the HPDL. P(l | lambda) = exp(-lambda * dL_l) / sum_m
# exp(-lambda * dL_m), with lambda ~ Normal(mu, sd) across participants
circ_dist <- function(a, b) pmin(abs(a - b), 8 - abs(a - b)) # 8 locations on a circle
k_dist <- c(1, 2, 2, 2, 1) # locations at each distance 0-4

# P(chosen distance = 0-4 | lambda), one row per lambda
p_dist_matrix <- function(lambda) {
  a <- outer(-lambda, 0:4) + rep(log(k_dist), each = length(lambda))
  m <- apply(a, 1, max)
  exp(a - (m + log(rowSums(exp(a - m)))))
}

# Marginal P(distance) over lambda ~ Normal(mu, sd)
p_dist_marginal <- function(mu, sd) {
  vapply(0:4, function(d) integrate(function(l) p_dist_matrix(l)[, d + 1] * dnorm(l, mu, sd),
                                    mu - 10 * sd, mu + 10 * sd, rel.tol = 1e-10)$value, numeric(1))
}

# Chosen distances (0-4) of n participants with lambda ~ Normal(mu, sd), as counts
simulate_counts <- function(n, mu, sd) {
  P <- p_dist_matrix(rnorm(n, mu, sd))
  d <- rowSums(runif(n) > t(apply(P, 1, cumsum))[, 1:4, drop = FALSE])
  tabulate(d + 1, 5)
}
counts_to_dl <- function(n) rep(0:4, n)

# The model as a mixed conditional logit with glmmTMB, through the Poisson
# formulation (Muff et al., 2020): one choice set of 8 locations per participant.
# mu = -(distance coefficient), and Distance x Group > 0 if the load weakens the gradient
choice_sets <- function(dl_chosen, group_c = rep(0, length(dl_chosen))) {
  set_dist <- c(0, 1, 1, 2, 2, 3, 3, 4)
  first_at <- c(1, 2, 4, 6, 8) # first location of the set at each distance 0-4
  n <- length(dl_chosen)
  tibble(id = factor(rep(seq_len(n), each = 8)),
         group_c = rep(group_c, each = 8),
         distance = rep(set_dist, n),
         y = as.integer(rep(1:8, n) == rep(first_at[dl_chosen + 1], each = 8)))
}

fit_glmmtmb <- function(dat, group = FALSE) {
  f <- if (group) y ~ 0 + distance + distance:group_c + (1 | id) + (0 + distance | id) else
    y ~ 0 + distance + (1 | id) + (0 + distance | id)
  fit <- glmmTMB::glmmTMB(f, family = poisson, data = dat,
                          map = list(theta = factor(c(NA, 1))), start = list(theta = c(log(1e3), 0)))
  b <- glmmTMB::fixef(fit)$cond
  V <- vcov(fit)$cond
  th <- fit$fit$par[names(fit$fit$par) == "theta"] # log SD of the random slope
  out <- list(converged = fit$fit$convergence == 0 && isTRUE(fit$sdr$pdHess),
              mu = -b[["distance"]], sd = unname(exp(th)))
  if (group) {
    out$b_int <- b[["distance:group_c"]]
    out$se_int <- sqrt(V["distance:group_c", "distance:group_c"])
    out$b <- b[c("distance", "distance:group_c")]
    out$V <- V[names(out$b), names(out$b)]
  }
  out
}

# One replicate of the sensitivity of the awareness model
run_awareness_rep <- function(i, cell, aw_ctrl, n_load) {
  set.seed(cell$seed + i)
  n <- cbind(
    simulate_counts(aw_ctrl$n, aw_ctrl$mu, aw_ctrl$sd),
    simulate_counts(n_load, (1 - cell$attenuation) * aw_ctrl$mu, aw_ctrl$sd)
  )
  dat <- choice_sets(c(counts_to_dl(n[, 1]), counts_to_dl(n[, 2])), rep(c(-.5, .5), c(aw_ctrl$n, n_load)))
  f <- tryCatch(fit_glmmtmb(dat, group = TRUE), error = function(e) NULL)
  ok <- !is.null(f)
  tibble(
    cell_id = cell$cell_id,
    attenuation_pct = cell$attenuation_pct,
    rep = i,
    converged = ok && f$converged,
    p = if (ok) pnorm(f$b_int / f$se_int, lower.tail = FALSE) else NA_real_
  )
}

# Meta-analysis ----
# SD of the RTs of each condition from the error bars of Gao and Theeuwes (2020)
cell_sd <- function(gao_se, e, l) {
  x <- gao_se[gao_se$exp == e & gao_se$load_condition == l, ]
  setNames(x$se_ms * sqrt(24), x$condition)
}

# Correlation between the HPDL and LPDL RTs given the SD of the suppression
# scores, and the other way around
r_from_sd <- function(s, sd_supp) {
  (s[["HPDL"]]^2 + s[["LPDL"]]^2 - sd_supp^2) / (2 * s[["HPDL"]] * s[["LPDL"]])
}

sd_from_r <- function(s, r) {
  sqrt(s[["HPDL"]]^2 + s[["LPDL"]]^2 - 2 * r * s[["HPDL"]] * s[["LPDL"]])
}

# Sampling covariance matrix: r sqrt(v_lower v_higher) between the two effects of
# a within-participant experiment
sampling_cov <- function(d) {
  V <- diag(d$v_g)
  for (cd in unique(d$code[d$design == "W"])) {
    i <- which(d$code == cd)
    V[i[1], i[2]] <- V[i[2], i[1]] <- d$r[i[1]] * sqrt(d$v_g[i[1]] * d$v_g[i[2]])
  }
  V
}

fit_brms <- function(d, file, priors, seed = 20261101) {
  d <- arrange(d, code, load_c) %>% mutate(es_id = factor(row_number()))
  brm(
    bf(g ~ load_c + (1 | es_id) + fcor(V)),
    data = d,
    data2 = list(V = sampling_cov(d)),
    prior = priors,
    control = list(adapt_delta = .95),
    backend = "cmdstanr",
    seed = seed,
    refresh = 0,
    silent = 2,
    file = file,
    file_refit = "on_change"
  )
}

# Effect under each load, modulation and the two quantities of the Sample Size
# Rationale: largest compatible attenuation and half-width under higher load
summarise_fit <- function(fit, label) {
  dr <- as_draws_df(fit)
  draws <- tibble(
    lower = dr$b_Intercept - .5 * dr$b_load_c,
    higher = dr$b_Intercept + .5 * dr$b_load_c,
    mod = dr$b_load_c,
    tau = dr$sd_es_id__Intercept
  )

  q <- function(x) c(median = median(x), ci_lower = unname(quantile(x, .025)), ci_upper = unname(quantile(x, .975)))

  summary <-
    bind_rows(lapply(names(draws), function(v) as_tibble(as.list(q(draws[[v]]))) %>% mutate(quantity = v))) %>%
    mutate(analysis = label, .before = 1)

  np <- nuts_params(fit)
  rhat <- posterior::summarise_draws(dr[, c("b_Intercept", "b_load_c", "sd_es_id__Intercept")], "rhat")$rhat

  criteria <- tibble(
    analysis = label,
    largest_attenuation_pct = -100 * quantile(draws$mod, .025)[[1]] / mean(draws$lower),
    higher_load_halfwidth_pct = 100 * diff(quantile(draws$higher, c(.025, .975))) / 2 / mean(draws$higher),
    divergences = sum(np$Value[np$Parameter == "divergent__"]),
    max_rhat = max(rhat)
  )

  list(draws = draws, summary = summary, criteria = criteria)
}

# Saving and loading the results ----
analysis_results_path <- function(name, dir = "output/analysis") {
  file.path(dir, paste0(name, ".rds"))
}

ensure_project_dirs <- function() {
  dirs <- c("output/analysis", "output/figures", "output/manuscript", "output/models", "output/simulations")
  invisible(lapply(dirs, function(dir) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
    }
  }))
}

save_analysis_objects <- function(name, ..., dir = "output/analysis") {
  objects <- list(...)
  if (is.null(names(objects)) || any(names(objects) == "")) {
    stop("All objects passed to save_analysis_objects() must be named.")
  }
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
  saveRDS(objects, analysis_results_path(name, dir = dir))
  invisible(objects)
}

load_analysis_objects <- function(name, dir = "output/analysis") {
  path <- analysis_results_path(name, dir = dir)
  if (!file.exists(path)) {
    stop(sprintf("Could not find saved analysis objects at '%s'.", path))
  }
  readRDS(path)
}
