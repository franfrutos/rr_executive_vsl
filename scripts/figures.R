## -----------------------------------------------------------------------------
## Author: Francisco Garre-Frutos
## -----------------------------------------------------------------------------

# Figures of the manuscript, drawn at the text width (16 cm) and saved as PNG (600
# dpi). Figure 1: sample size rationale. Figure 2: procedure of the load group,
# with the geometry of the PsychoPy task. Figure of the results: from analysis.R

# Loading packages----
source("scripts/functions.R")

if (!require(pacman)) {
  install.packages("pacman")
  library(pacman)
}

p_load(dplyr, # Data wrangling
       ggplot2, # Plotting
       cowplot, # Panels
       ggdist, # Posterior distributions
       magick # Bitmap of the regularity map (Figure 2)
)

ensure_project_dirs()

ctrl <- load_analysis_objects("control_models")
meta <- load_analysis_objects("meta_analysis")
pow <- load_analysis_objects("power")
sens <- load_analysis_objects("sensitivity")

# Theme of all the figures ----
ink <- "grey20"
label_size <- 6.5 / .pt

theme_results <- function() {
  theme_minimal(base_size = 7.5) +
    theme(
      text = element_text(color = ink),
      axis.text = element_text(size = 6.5, color = "grey35"),
      axis.title = element_text(size = 7.5, color = ink),
      axis.line = element_line(color = "grey55", linewidth = .3),
      axis.ticks = element_line(color = "grey55", linewidth = .3),
      axis.ticks.length = unit(1.5, "pt"),
      panel.grid = element_blank(),
      plot.title = element_text(size = 7.5, face = "bold", color = ink, margin = margin(0, 0, 3, 0)),
      plot.title.position = "panel",
      strip.text = element_text(size = 7.5, face = "bold", color = ink),
      strip.placement = "outside",
      legend.position = "none",
      plot.margin = margin(4, 6, 3, 3)
    )
}

# Figure 1 ----
target_power <- .90
n_planned <- 140 # minimum analysable load group
n_max <- 160     # participants to be recruited in the load group
fig_width <- 16  # cm, text width of the manuscript (A4 or Letter, 2.54 cm margins)
annot_size <- 6.5 / .pt # annotations in pt
h2_bound <- pow$h2_bound
params_no_time <- ctrl$params
# expected SE of the load-group suppression at the planned N (no suppression)
se_load_planned <- pow$h2 %>%
  filter(r == 0, n_load == n_planned) %>%
  pull(mean_se_supp_load)
# Confirmatory tests in the purples of panel A
test_colors <- c(H1 = "#9970AB", H2 = supp_color)
test_fills <- c(H1 = "#C2A5CF", H2 = supp_color)
sens_col <- "grey30" # exploratory tests
triple <- sens$triple
awareness <- sens$aware

# Reference: shaded area of power >= target and a thin vertical line from the
# x axis up to the curve at the reference value (planned N or MDE)
reference_layers <- function(x_ref, y_ref) {
  list(annotate("rect", xmin = -Inf, xmax = Inf, ymin = target_power, ymax = Inf, fill = "grey89"),
       annotate("segment", x = x_ref, xend = x_ref, y = -Inf, yend = y_ref, color = "grey45", linewidth = .35))
}

# Power by grid value (dat: power, ci_lower, ci_upper and the effect size es), with
# the minimum detectable effect as the vertical reference
sensitivity_panel <- function(dat, x, bottom_labels, x_title, x_subtitle, y_title = TRUE) {
  mde <- min(dat[[x]][dat$power >= target_power])
  labelled <- seq_len(nrow(dat)) %% 2 == 1
  ggplot(dat, aes(.data[[x]], power)) +
    reference_layers(mde, dat$power[dat[[x]] == mde]) +
    annotate("text", x = mde, y = .03, hjust = 1.08, size = annot_size, color = "grey30", parse = TRUE,
             label = sprintf("MDE == '%g%%'", mde)) +
    geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), fill = sens_col, alpha = .3) +
    geom_line(linewidth = .6, color = sens_col) +
    geom_point(shape = 21, size = 1.1, color = sens_col, fill = sens_col) +
    scale_x_continuous(breaks = dat[[x]], labels = ifelse(labelled, sprintf("%g\n(%s)", dat[[x]], bottom_labels), "")) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, .2), labels = paste0(seq(0, 100, 20), "%")) +
    labs(x = bquote(atop(.(x_title), .(x_subtitle))), y = if (y_title) "Power" else NULL) +
    theme_results()
}

panel_triple <- sensitivity_panel(triple, "attenuation_pct", sprintf("%.0f", triple$delta_learning_ms),
                                  "Learning-slope attenuation (%)", quote("(" * Delta[learning] * ", ms)"))
# Attenuation of the mean awareness gradient lambda (multilevel gradient
# model), with the expected proportion of HPDL choices in the load group
panel_awareness <- sensitivity_panel(awareness, "attenuation_pct", sprintf("%.0f", 100 * awareness$p_hpdl_load),
                                     "Awareness attenuation (%)", "(% HPDL choices, load group)", y_title = FALSE)

sens_row <- function(labels) {
  # same order as the exploratory analyses of the manuscript: acquisition, awareness
  cowplot::plot_grid(panel_triple, panel_awareness, nrow = 1, labels = labels, label_size = 10,
                     align = "hv", axis = "tblr")
}

# Confirmatory tests: power by N_load, with the planned N ----
# H1: 20% attenuation of the suppression effect; H2: no suppression in the load
# group, tested against the 18% bound
es20 <- pow$es
power_tests <- bind_rows(
  pow$power_conf %>%
    transmute(test = "H1", n_load, power, ci_lower, ci_upper),
  pow$h2 %>%
    filter(r == 0) %>%
    transmute(test = "H2", n_load, power = power_h2, ci_lower, ci_upper)
)
# The legend gives the contrast of each test, with the notation of the schematic
# (hypotheses_panel()); the effect sizes are in the caption
test_labels <- c(H1 = expression("H1:" ~ italic(S)[load] - italic(S)[control] < 0),
                 H2 = expression("H2:" ~ abs(italic(S)[load]) < Delta))
confirmatory_panel <- function() {
  ggplot(power_tests, aes(n_load, power, color = test, fill = test)) +
    # Planned sample: a line up to the lower curve, and a light band from the minimum
    # analysable N to the N to be recruited
    annotate("rect", xmin = n_planned, xmax = n_max, ymin = -Inf, ymax = Inf, fill = "grey95") +
    reference_layers(n_planned, min(power_tests$power[power_tests$n_load == n_planned])) +
    annotate("segment", x = n_max, xend = n_max, y = -Inf, yend = min(power_tests$power[power_tests$n_load == n_max]),
             color = "grey45", linewidth = .35) +
    annotate("text", x = c(n_planned, n_max), y = .03, hjust = c(1.08, -.08), size = annot_size, color = "grey30", parse = TRUE,
             label = c("italic(N)[min]", "italic(N)[max]")) + # the values are read on the x axis
    geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = .3, color = NA) +
    geom_line(linewidth = .6) +
    geom_point(shape = 21, size = 1.1) +
    scale_x_continuous(breaks = sort(unique(power_tests$n_load))) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, .2), labels = paste0(seq(0, 100, 20), "%")) +
    # colour and fill share title and labels, so the legend keys show line, point and band
    scale_color_manual(NULL, values = test_colors, labels = test_labels) +
    scale_fill_manual(NULL, values = test_fills, labels = test_labels) +
    labs(x = quote("Load group size," ~ italic(N)[load]), y = "Power") +
    theme_results() +
    # no legend margin and a shorter key: the legend sits clear of the N_max line
    theme(legend.position = "inside", legend.position.inside = c(1, .3), legend.justification = c(1, .5),
          legend.margin = margin(0, 0, 0, 0), legend.direction = "vertical", legend.background = element_blank(),
          legend.key = element_blank(), legend.key.width = unit(.5, "cm"), legend.key.height = unit(.38, "cm"))
}

# Schematic of what each test compares, in ms of suppression: the control effect
# and the effect assumed in the load group (H1, 20% smaller; H2, no suppression
# within the bounds). Error bars: +-1 SE, expected at the planned N in the load group
hypotheses_panel <- function() {
  ctrl_ms <- h2_bound$control_suppression_ms
  h1_ms <- ctrl_ms - es20$delta_suppression_ms
  bound <- h2_bound$delta_ms
  supp_col <- supp_color
  ms_per_log <- ctrl_ms / h2_bound$control_suppression
  se_ctrl <- ms_per_log * sqrt(params_no_time$vcov_beta["conditionsuppression", "conditionsuppression"])
  se_load <- ms_per_log * se_load_planned
  pts <- tibble(x = c(1, 2, 2), y = c(ctrl_ms, h1_ms, 0), grp = c("control", "load", "load"), se = c(se_ctrl, se_load, se_load))
  ggplot(pts, aes(x, y)) +
    annotate("rect", xmin = 1.75, xmax = 2.25, ymin = -bound, ymax = bound, fill = "grey89") +
    annotate("segment", x = 1.75, xend = 2.25, y = c(bound, -bound), yend = c(bound, -bound), color = "grey45", linewidth = .35) +
    annotate("segment", x = c(1, 2), xend = c(2, 2), y = c(ctrl_ms, h1_ms), yend = ctrl_ms, color = "grey45", linewidth = .35) +
    annotate("text", x = 1.5, y = h1_ms - 11, size = annot_size, color = "grey30", parse = TRUE,
             label = "'H1:' ~ italic(S)[load] - italic(S)[control] < 0") +
    annotate("text", x = 2, y = bound + 9, size = annot_size, color = "grey30", parse = TRUE,
             label = "'H2:' ~ abs(italic(S)[load]) < Delta") +
    geom_errorbar(aes(ymin = y - se, ymax = y + se), width = .08, color = supp_col, linewidth = .35) +
    geom_point(aes(fill = grp), shape = 21, size = 1.8, color = supp_col, stroke = .4) +
    scale_fill_manual(values = c(control = "white", load = supp_col), guide = "none") +
    scale_x_continuous(breaks = 1:2, labels = c("Control", "Load"), limits = c(.5, 2.5)) +
    scale_y_continuous(limits = c(-17, 88), breaks = seq(0, 80, 20)) +
    labs(x = NULL, y = "Suppression (ms)") +
    theme_results()
}
# The schematic first: it says what the power curves refer to
conf_row <- function(labels) {
  cowplot::plot_grid(hypotheses_panel(), confirmatory_panel(), nrow = 1, rel_widths = c(1, 2), labels = labels,
                     label_size = 10, align = "h", axis = "tb")
}

# Panel A: forest plot ----
# Two columns on the same scale (g_z): the load modulation (the basis of H1) and
# the suppression under each load (H2). Hollow: lower load; filled: higher load
minus <- function(x) gsub("-", "−", x) # typographic minus sign
forest_d <- meta$forest_d %>%
  # marker size by precision, set directly (a size scale would also act on the ggdist intervals)
  mutate(pt_size = 1.2 + 1.6 * (1 / se - min(1 / se)) / diff(range(1 / se)))
fp_rows <- distinct(forest_d, code, row)
supp_col <- supp_color
marker_fill <- c(lower = "white", higher = supp_col, mod = "#C2A5CF")
marker_line <- c(lower = supp_col, higher = supp_col, mod = supp_col)
# baselines of the posterior densities in the bottom row
pooled_y <- c(lower = 1.4, higher = .55, mod = .75)
post <- meta$draws %>%
  dplyr::select(lower, higher, mod) %>%
  tidyr::pivot_longer(everything(), names_to = "marker", values_to = "value") %>%
  mutate(panel = ifelse(marker == "mod", "mod", "load"), y = pooled_y[marker])
pooled <- post %>%
  group_by(marker, panel, y) %>%
  dplyr::summarise(est = median(value), lo = quantile(value, .025), hi = quantile(value, .975), .groups = "drop")
y_top <- max(fp_rows$row) + .9
x_lims <- list(load = c(0, 2.5), mod = c(-1.25, 1.25)) # the same length in both columns
forest_panel <- function(p, show_y) {
  dd <- forest_d[forest_d$panel == p, ]
  pp <- post[post$panel == p, ]
  lim <- x_lims[[p]]
  br <- seq(ceiling(2 * lim[1]) / 2, floor(2 * lim[2]) / 2, .5)
  title_layers <- if (p == "mod") {
    list(annotate("text", x = mean(lim), y = y_top, size = 7 / .pt, parse = TRUE,
                  label = "Delta * italic(S) == italic(S)[high~load] - italic(S)[low~load]"))
  } else { # the two markers explained in the title row
    list(annotate("point", x = c(.25, 1.3), y = y_top, shape = 21, size = 1.8, fill = marker_fill[c("lower", "higher")],
                  color = marker_line[c("lower", "higher")], stroke = .4),
         annotate("text", x = c(.33, 1.38), y = y_top, hjust = 0, size = 7 / .pt, parse = TRUE,
                  label = c("italic(S)[low~load]", "italic(S)[high~load]")))
  }
  ggplot(dd, aes(y = y)) +
    (if (p == "mod") annotate("segment", x = 0, xend = 0, y = .3, yend = y_top - .4, color = "grey70", linewidth = .35)) +
    geom_segment(aes(x = lo, xend = hi, yend = y), color = "grey25", linewidth = .35) +
    geom_point(aes(x = est, fill = marker, color = marker), size = dd$pt_size, shape = 21, stroke = .4) +
    stat_halfeye(data = pp, aes(x = value, y = y, fill = marker, slab_colour = marker), inherit.aes = FALSE,
                 orientation = "horizontal", .width = c(.66, .95), point_interval = "median_qi",
                 scale = .75, normalize = "groups", slab_linewidth = .35,
                 interval_colour = "grey20", point_colour = "grey20", point_fill = "grey20", point_size = 1.3,
                 interval_size_range = c(.5, 1.3)) +
    title_layers +
    scale_y_continuous(breaks = c(fp_rows$row, mean(range(pooled_y))), labels = c(fp_rows$code, "Meta-estimate")) +
    scale_x_continuous(breaks = br, labels = minus(formatC(br, format = "f", digits = 1))) +
    coord_cartesian(xlim = lim, ylim = c(.3, y_top + .4), expand = FALSE, clip = "off") +
    scale_fill_manual(values = marker_fill, guide = "none") +
    scale_color_manual(values = marker_line, aesthetics = c("colour", "slab_colour"), guide = "none") +
    labs(x = NULL, y = NULL) +
    theme_results() +
    theme(panel.grid.major = element_blank(), axis.text = element_text(size = 6.5),
          axis.text.y = if (show_y) element_text(size = 6.5, color = "black") else element_blank(),
          axis.line.y = element_blank(), axis.ticks.y = element_blank(),
          plot.margin = margin(2, 4, 0, if (show_y) 2 else 4, "mm"))
}
forest_panels <- list(mod = forest_panel("mod", TRUE), load = forest_panel("load", FALSE))
forest_widths <- c(1.39, 1) # the same length per unit in both columns
x_title <- cowplot::ggdraw() +
  cowplot::draw_label(quote("Standardized effect (Hedges'" ~ italic(g)[italic(z)] * ")"), x = .6, size = 8)

# Figure 1: one row per step of the sample size rationale ----
# The forest plot with the two criteria as effect sizes (g_z): H1, a decrease of
# 20% of the lower-load estimate; H2, +-18% of the higher-load estimate
fp <- c(forest_panels, list(widths = forest_widths, x_title = x_title, pooled = pooled))
q <- split(fp$pooled, fp$pooled$marker)
sesoi_g <- -.2 * q$lower$est
panel_load <- fp$load +
  annotate("text", x = q$higher$hi + .45, y = q$higher$y, hjust = 0, size = annot_size,
           color = test_colors[["H2"]], parse = TRUE,
           label = sprintf("'H2:' ~ italic(g)[z] %%+-%% '%.2f'", h2_bound$delta_h2 * q$higher$est))
panel_mod <- fp$mod +
  annotate("segment", x = sesoi_g, xend = sesoi_g, y = .3, yend = 1.7, color = test_colors[["H1"]], linewidth = .35) +
  annotate("text", x = sesoi_g - .03, y = 1.55, hjust = 1, size = annot_size, color = test_colors[["H1"]], parse = TRUE,
           label = sprintf("'H1:' ~ italic(g)[z] == '%s%.2f'", intToUtf8(0x2212), abs(sesoi_g)))
meta_row <- cowplot::plot_grid(
  cowplot::plot_grid(cowplot::plot_grid(panel_mod, panel_load, nrow = 1, align = "h", axis = "tb", rel_widths = fp$widths),
                     fp$x_title, ncol = 1, rel_heights = c(1, .09)),
  labels = "A", label_size = 10)
# Rows kept low so that the figure and its note fit on one page of the manuscript
overview <- cowplot::plot_grid(meta_row, conf_row(c("B", "C")), sens_row(c("D", "E")), ncol = 1, rel_heights = c(5, 4.8, 6))
ggsave("output/figures/fig-1.png", overview, width = fig_width, height = 15.8, units = "cm", dpi = 600, bg = "white")

# Figure 2 ----
fig_width <- 16    # cm, text width of the manuscript
fig_height <- 9.9  # cm (canvas 160 x 99 mm: 96 mm of drawing plus 3 mm of white margin below)
fixation_ms <- 500
text_pt <- 7
annot_col <- "grey35"

# Task geometry (px of the original program, y upwards) ----
positions <- tibble(pos = 1:8,
                    x = c(-220, -150, 0, 150, 220, 150, 0, -150),
                    y = c(0, 150, 220, 150, 0, -150, -220, -150))
green <- "#00FF00"
red <- "#FF0000"
screen_px <- 760 # side of the screen region drawn (the display spans 600 px)
hpdl <- 5        # same HPDL in both panels (location 5, on the right)

# Drawing list: every element is added in drawing order ----
canvas <- new.env()
canvas$n <- 0 # polygons drawn so far (their group ids give the drawing order)
canvas$polys <- list()
canvas$texts <- list()
canvas$arrows <- list()
canvas$lines <- list()

add_poly <- function(x, y, fill, colour = NA, lw = 0, alpha = 1) {
  canvas$n <- canvas$n + 1
  canvas$polys[[length(canvas$polys) + 1]] <- tibble(group = canvas$n, x = x, y = y, fill = fill,
                                                     colour = colour, lw = lw, alpha = alpha)
}

# Many polygons at once: id = 1, 2, ... in drawing order
add_poly_block <- function(df) {
  df$group <- canvas$n + df$id
  canvas$n <- canvas$n + max(df$id)
  canvas$polys[[length(canvas$polys) + 1]] <- transmute(df, group, x, y, fill, colour, lw, alpha = 1)
}

add_line <- function(x, y, xend, yend, colour = "grey55") {
  canvas$lines[[length(canvas$lines) + 1]] <- tibble(x = x, y = y, xend = xend, yend = yend, colour = colour)
}

add_text <- function(x, y, label, size = text_pt, colour = "black", family = "sans", face = "plain",
                     hjust = .5, vjust = .5, alpha = 1) {
  canvas$texts[[length(canvas$texts) + 1]] <- tibble(x = x, y = y, label = label, size = size / .pt,
                                                     colour = colour, family = family, face = face,
                                                     hjust = hjust, vjust = vjust, alpha = alpha)
}

add_arrow <- function(x, y, xend, yend, colour = "grey55") {
  canvas$arrows[[length(canvas$arrows) + 1]] <- tibble(x = x, y = y, xend = xend, yend = yend, colour = colour)
}

disc <- function(cx, cy, r, fill, ...) {
  th <- seq(0, 2 * pi, length.out = 121)
  add_poly(cx + r * cos(th), cy + r * sin(th), fill, ...)
}

rounded_rect <- function(x0, y0, w, h, r, fill, ...) {
  arc <- function(cx, cy, a0) {
    th <- seq(a0, a0 + pi / 2, length.out = 12)
    cbind(cx + r * cos(th), cy + r * sin(th))
  }
  p <- rbind(arc(x0 + w - r, y0 + h - r, 0), arc(x0 + r, y0 + h - r, pi / 2),
             arc(x0 + r, y0 + r, pi), arc(x0 + w - r, y0 + r, 3 * pi / 2))
  add_poly(p[, 1], p[, 2], fill, ...)
}

# A search item at (cx, cy) mm, with s mm per px
draw_item <- function(cx, cy, s, shape, colour, orientation, alpha = 1) {
  if (shape == "circle") {
    disc(cx, cy, 60 * s, colour, alpha = alpha)
    disc(cx, cy, 53 * s, "white", alpha = alpha)
  } else {
    half <- c(75 + 5 * sqrt(2), 75 - 5 * sqrt(2)) * s
    for (k in 1:2) {
      add_poly(cx + c(0, -half[k], 0, half[k]), cy + c(-half[k], 0, half[k], 0),
               c(colour, "white")[k], alpha = alpha)
    }
  }
  w <- if (orientation == "V") 7 else 100
  h <- if (orientation == "V") 100 else 7
  add_poly(cx + c(-1, 1, 1, -1) * w / 2 * s, cy + c(-1, -1, 1, 1) * h / 2 * s, "black", alpha = alpha)
}

# A search display: target shape and colour, singleton at distractor_pos (0 =
# none), line orientations of locations 1-8
draw_display <- function(cx, cy, s, target_pos, target_shape, colour, distractor_pos, orientations,
                         spotlight = FALSE) {
  other <- if (target_shape == "diamond") "circle" else "diamond"
  singleton <- if (colour == green) red else green
  for (i in 1:8) {
    x <- cx + positions$x[i] * s
    y <- cy + positions$y[i] * s
    if (spotlight && i == target_pos) disc(x, y, 105 * s, "grey85")
    draw_item(x, y, s, if (i == target_pos) target_shape else other,
              if (i == distractor_pos) singleton else colour, substr(orientations, i, i))
  }
}

# A screen: rounded white rectangle with a soft shadow; returns its centre.
# A faded screen (lighter edge and shadow) only appears on some trials.
draw_screen <- function(x0, y0, size, faded = FALSE) {
  rounded_rect(x0 + .45, y0 - .45, size, size, .9, if (faded) "grey94" else "grey86")
  rounded_rect(x0, y0, size, size, .9, "white", colour = if (faded) "grey78" else "grey55", lw = .25)
  c(x0 + size / 2, y0 + size / 2)
}

keycap <- function(cx, cy, size, label, family = "sans") {
  rounded_rect(cx - size / 2 + .25, cy - size / 2 - .25, size, size, .6, "grey75")
  rounded_rect(cx - size / 2, cy - size / 2, size, size, .6, "grey95", colour = "grey55", lw = .2)
  add_text(cx, cy, label, size = 6.5, family = family, face = "bold", colour = "grey20")
}

badge <- function(cx, cy, count, updated) {
  rounded_rect(cx - 2.1, cy - 2.1, 4.2, 4.2, 1, if (updated) "grey20" else "white",
               colour = if (updated) NA else "grey55", lw = .25)
  add_text(cx, cy, count, size = 6.5, face = "bold", colour = if (updated) "white" else "grey35")
}

placeholder <- function(cx, cy, w) rounded_rect(cx - w / 2, cy - .45, w, .9, .45, "grey85")

# Geometry of the regularity map: the screen lying flat, with the HPDL in front ----
az <- -40 * pi / 180 # rotation of the screen plane
el <- 38 * pi / 180  # elevation of the view
k_c <- .046          # mm per px
origin_c <- c(127, 73.5)
depth <- function(x, y) x * sin(az) + y * cos(az) # larger = farther
proj_x <- function(x, y) origin_c[1] + k_c * (x * cos(az) - y * sin(az))
proj_y <- function(x, y, z = 0) origin_c[2] + k_c * (depth(x, y) * sin(el) + z * cos(el))
half <- 340
cx <- c(-half, half, half, -half)
cy <- c(-half, -half, half, half)

# A. One trial: blank, fixation, search display, error feedback ----
size_a <- 26
s_a <- size_a / screen_px
step_a <- c(24, -9)
corner_a <- c(6, 68) # lower-left corner of the first screen
labels_a <- c("500 ms", paste(fixation_ms, "ms"), "≤ 3 s", "3 s")
for (k in 1:4) {
  x0 <- corner_a[1] + (k - 1) * step_a[1]
  y0 <- corner_a[2] + (k - 1) * step_a[2]
  if (k == 3) {
    # A soft beam from the search display to the map: small cells, more transparent
    # with distance
    n_t <- 30
    n_s <- 12
    map_top <- c(proj_x(-half, half), proj_y(-half, half))
    map_left <- c(proj_x(-half, -half), proj_y(-half, -half))
    beam_point <- function(t, s) { # t: along the beam (0 = display); s: across (0 = upper edge)
      disp <- c(x0 + size_a, y0 + size_a * (1 - s))
      map <- map_top + s * (map_left - map_top)
      list(x = disp[1] + t * (map[1] - disp[1]), y = disp[2] + t * (map[2] - disp[2]))
    }
    for (i in seq_len(n_t)) {
      for (j in seq_len(n_s)) {
        t <- (i - c(1, 0)) / n_t
        s <- (j - c(1, 0)) / n_s
        p <- mapply(beam_point, t = c(t[1], t[2], t[2], t[1]), s = c(s[1], s[1], s[2], s[2]))
        add_poly(unlist(p["x", ]), unlist(p["y", ]), "grey35",
                 alpha = .15 * (1 - mean(t))^1.3 * (1 - .75 * mean(s)))
      }
    }
  }
  centre <- draw_screen(x0, y0, size_a, faded = k == 4)
  if (k == 2) add_text(centre[1], centre[2], "+", size = 11, family = "serif")
  if (k == 3) {
    draw_display(centre[1], centre[2], s_a, target_pos = 8, target_shape = "diamond", colour = green,
                 distractor_pos = hpdl, orientations = "VHHVHHVH")
  }
  if (k == 4) add_text(centre[1], centre[2], "Error! :(", size = 7.5, family = "serif", colour = "grey45")
  add_text(x0, y0 - 1.6, labels_a[k], colour = annot_col, hjust = 0)
  if (k == 3) { # target (location 8, above the keys) and distractor (location 5, the HPDL)
    target <- c(centre[1] - 150 * s_a, centre[2] - 150 * s_a)
    distractor <- c(centre[1] + 220 * s_a, centre[2])
    add_line(target[1] - 2.9, target[2] - .9, target[1] - 8.4, target[2] - 4.2)
    add_text(target[1] - 8.8, target[2] - 4.2, "Target", colour = annot_col, hjust = 1)
    add_line(distractor[1] + 1.6, distractor[2] + 1.6, distractor[1] + 6.8, distractor[2] + 8.6)
    add_text(distractor[1] + 7.1, distractor[2] + 9, "Distractor", colour = annot_col, hjust = 0, vjust = 0)
  }
}
# response keys under the target, below the duration of the display, each with
# its line above it: left = horizontal (the answer in this display, right under
# the target), up = vertical
for (key in list(list(x = target[1], glyph = "←", o = "H"), list(x = target[1] + 7.5, glyph = "↑", o = "V"))) {
  keycap(key$x, 39.5, 4.6, key$glyph)
  w <- if (key$o == "V") .35 else 3.4
  h <- if (key$o == "V") 3.4 else .35
  add_poly(key$x + c(-1, 1, 1, -1) * w / 2, 44.6 + c(-1, -1, 1, 1) * h / 2, "black")
}

# B. One period of the counting task ----
y_b <- -1       # reference height of panel B (the screens start 3.5 mm above)
size_b <- 22
s_b <- size_b / screen_px
size_m <- 15    # trials of the period
s_m <- size_m / screen_px
x_start <- 7
# start of the period: orientation to count (text as grey bars) and counter at 0
centre <- draw_screen(x_start, y_b + 3.5, size_b)
placeholder(centre[1], centre[2] + 5.5, 13)
add_poly(centre[1] + c(-1, 1, 1, -1) * .3, centre[2] - 1.2 + c(-1, -1, 1, 1) * 3.5, "black")
badge(centre[1], y_b + 3.5 + size_b + 3.2, "0", FALSE)
add_arrow(x_start + size_b + 1.2, centre[2], x_start + size_b + 4.2, centre[2])
# trials: the target is checked on every trial (spotlight); the count is
# updated when its line is vertical
trials_b <- tibble(
  target_pos = c(2, 6, 4, 8, 3),
  target_shape = c("circle", "diamond", "circle", "diamond", "diamond"),
  colour = c(green, green, red, red, green),
  distractor_pos = c(hpdl, 1, 0, hpdl, hpdl),
  orientations = c("HVHHVHVH", "VHHVHHHV", "HHVVHVHH", "VHHHVHHV", "HVVHHHVH"),
  count = c("1", "1", "2", "3", "5"),
  updated = c(TRUE, FALSE, TRUE, TRUE, TRUE)
)
x_trials <- x_start + size_b + 5.5 + c(0, 1, 2, 3, 4.45) * (size_m + 2.4)
for (j in seq_len(nrow(trials_b))) {
  t <- trials_b[j, ]
  centre <- draw_screen(x_trials[j], y_b + 7, size_m)
  draw_display(centre[1], centre[2], s_m, t$target_pos, t$target_shape, t$colour, t$distractor_pos,
               t$orientations, spotlight = TRUE)
  badge(centre[1], y_b + 7 + size_m + 3.2, t$count, t$updated)
}
gap_mid <- (x_trials[4] + size_m + x_trials[5]) / 2
add_text(gap_mid, y_b + 7 + size_m / 2, "…", size = 9, colour = annot_col)
add_text(gap_mid, y_b + 7 + size_m + 3.2, "…", size = 9, colour = annot_col)
# length of the period
x_left <- x_trials[1]
x_right <- x_trials[5] + size_m
y_brace <- y_b + 5.2
add_poly(c(x_left, x_right, x_right, x_left), y_brace + c(0, 0, .18, .18), "grey55")
for (xx in c(x_left, x_right)) add_poly(xx + c(0, .18, .18, 0), y_brace + c(0, 0, 1.2, 1.2), "grey55")
add_text((x_left + x_right) / 2, y_brace - 1.8, "8, 10 or 12 trials", colour = annot_col)
# verification: a number, yes (S) or no (N)
x_verify <- x_right + 5.2
add_arrow(x_right + 1.2, y_b + 7 + size_m / 2, x_verify - 1.2, y_b + 7 + size_m / 2)
centre <- draw_screen(x_verify, y_b + 3.5, size_b)
add_poly(centre[1] + c(-1, 1, 1, -1) * .3, centre[2] + 6 + c(-1, -1, 1, 1) * 2, "black")
add_text(centre[1], centre[2] + .8, "5", size = 12, family = "serif", face = "bold")
keycap(centre[1] - 3.6, centre[2] - 6, 4.6, "S")
keycap(centre[1] + 3.6, centre[2] - 6, 4.6, "N")

# A (continued). The regularity map ----
# Height over each location proportional to the probability of the colour
# singleton (HPDL 65%, each LPDL 5%), and colour by height
z_px <- 700          # height of a probability of 1, in px
sd_px <- 30          # width of the peaks, in px
prob <- ifelse(positions$pos == hpdl, .65, .05)
bump <- function(x, y, l) prob[l] * exp(-((x - positions$x[l])^2 + (y - positions$y[l])^2) / (2 * sd_px^2))
surface <- function(x, y) Reduce(`+`, lapply(1:8, function(l) bump(x, y, l)))
# slope of the surface (in px of height per px), for the shading
slope_x <- function(x, y) Reduce(`+`, lapply(1:8, function(l) -bump(x, y, l) * (x - positions$x[l]) / sd_px^2)) * z_px
slope_y <- function(x, y) Reduce(`+`, lapply(1:8, function(l) -bump(x, y, l) * (y - positions$y[l]) / sd_px^2)) * z_px
# the screen lying flat
add_poly(proj_x(cx, cy) + .45, proj_y(cx, cy) - .45, "grey86")
add_poly(proj_x(cx, cy), proj_y(cx, cy), "white", colour = "grey55", lw = .25)
# the eight locations, as the outlines of the items of the display
th <- seq(0, 2 * pi, length.out = 61)
for (l in 1:8) {
  xx <- positions$x[l] + 60 * cos(th)
  yy <- positions$y[l] + 60 * sin(th)
  add_poly(proj_x(xx, yy), proj_y(xx, yy), NA, colour = "grey78", lw = .25)
}
# The peaks are drawn as a bitmap, so the surface is smooth: small quads painted
# from back to front at three times the final resolution, then reduced
ramp_cols <- c("white", "#FEE0D2", "#FCBBA1", "#FC9272", "#FB6A4A", "#EF3B2C", "#CB181D", "#99000D")
ramp <- colorRamp(ramp_cols, space = "Lab")
step <- 2.5
g <- seq(-half, half - step, by = step)
light <- c(-.55, .35, .76) / sqrt(sum(c(-.55, .35, .76)^2))
quads <- expand.grid(x0 = g, y0 = g) %>%
  as_tibble() %>%
  mutate(p00 = surface(x0, y0), p10 = surface(x0 + step, y0),
         p11 = surface(x0 + step, y0 + step), p01 = surface(x0, y0 + step)) %>%
  filter(pmax(p00, p10, p11, p01) > .0005) %>%
  mutate(xc = x0 + step / 2, yc = y0 + step / 2,
         sx = slope_x(xc, yc), sy = slope_y(xc, yc),
         lit = pmax(0, (-sx * light[1] - sy * light[2] + light[3]) / sqrt(sx^2 + sy^2 + 1)),
         shade = (.68 + .32 * lit) / (.68 + .32 * light[3]),
         pc = surface(xc, yc),
         f = (pc / max(prob))^.6,
         d = depth(xc, yc)) %>%
  arrange(desc(d))
base <- pmin(ramp(quads$f) * quads$shade, 255)
quads$fill <- rgb(base[, 1], base[, 2], base[, 3], alpha = pmin(1, quads$pc / .02) * 255, maxColorValue = 255)
corner_dx <- c(0, step, step, 0, NA)
corner_dy <- c(0, 0, step, step, NA)
p_corner <- cbind(quads$p00, quads$p10, quads$p11, quads$p01, NA)
qx <- as.vector(t(outer(quads$x0, corner_dx, `+`)))
qy <- as.vector(t(outer(quads$y0, corner_dy, `+`)))
qz <- as.vector(t(p_corner)) * z_px
ext <- c(100, 156, 54, 94) # mm: x min, x max, y min, y max of the bitmap
ss <- 3
px_per_mm <- 600 / 25.4
w_px <- round((ext[2] - ext[1]) * px_per_mm)
h_px <- round((ext[4] - ext[3]) * px_per_mm)
peaks_file <- tempfile(fileext = ".png")
png(peaks_file, width = w_px * ss, height = h_px * ss, type = "cairo", antialias = "none", bg = "transparent")
par(mar = c(0, 0, 0, 0))
plot.new()
plot.window(xlim = ext[1:2], ylim = ext[3:4], xaxs = "i", yaxs = "i")
polygon(proj_x(qx, qy), proj_y(qx, qy, qz), col = quads$fill, border = NA)
invisible(dev.off())
peaks_raster <- as.raster(magick::image_resize(magick::image_read(peaks_file), sprintf("%dx%d!", w_px, h_px)))
unlink(peaks_file)
# the front edges of the screen again, over the foot of the peaks
front <- c(4, 1, 2) # left, nearest and right corners
add_line(proj_x(cx[front[1:2]], cy[front[1:2]]), proj_y(cx[front[1:2]], cy[front[1:2]]),
         proj_x(cx[front[2:3]], cy[front[2:3]]), proj_y(cx[front[2:3]], cy[front[2:3]]))
hp <- positions[positions$pos == hpdl, ]
left <- positions[which.min(proj_x(positions$x, positions$y)), ] # the leftmost LPDL on the page
# the probabilities, with leader lines as the labels of A
top_hp <- c(proj_x(hp$x, hp$y), proj_y(hp$x, hp$y, .65 * z_px))
add_line(top_hp[1] + .9, top_hp[2] + .3, top_hp[1] + 5.2, top_hp[2] + 2.2)
add_text(top_hp[1] + 5.6, top_hp[2] + 2.3, "65%", colour = tail(ramp_cols, 1), face = "bold", hjust = 0)
top_left <- c(proj_x(left$x, left$y), proj_y(left$x, left$y, .05 * z_px))
add_line(top_left[1] - 1.2, top_left[2], top_left[1] - 3.6, top_left[2] - .4)
add_text(top_left[1] - 3.9, top_left[2] - .5, "5%", colour = annot_col, hjust = 1)

# Panel letters ----
add_text(0, 96, "A", size = 10, face = "bold", hjust = 0, vjust = 1)
add_text(0, 33.5, "B", size = 10, face = "bold", hjust = 0, vjust = 1)

# Figure ----
polys <- bind_rows(canvas$polys)
texts <- bind_rows(canvas$texts)
arrows <- bind_rows(canvas$arrows)
fig <- ggplot() +
  geom_polygon(data = polys, aes(x, y, group = group, fill = fill, colour = colour, linewidth = lw, alpha = alpha)) +
  annotation_raster(peaks_raster, ext[1], ext[2], ext[3], ext[4], interpolate = TRUE) +
  geom_segment(data = arrows, aes(x, y, xend = xend, yend = yend, colour = colour), linewidth = .35,
               arrow = arrow(length = unit(1.2, "mm"), type = "closed")) +
  geom_segment(data = bind_rows(canvas$lines), aes(x, y, xend = xend, yend = yend, colour = colour),
               linewidth = .25) +
  geom_text(data = texts, aes(x, y, label = label, size = size, colour = colour, family = family,
                              fontface = face, hjust = hjust, vjust = vjust, alpha = alpha)) +
  scale_fill_identity() + scale_colour_identity() + scale_linewidth_identity() +
  scale_alpha_identity() + scale_size_identity() +
  coord_fixed(xlim = c(0, 160), ylim = c(-3, 96), expand = FALSE) +
  theme_void() +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.margin = margin(0, 0, 0, 0))

ggsave("output/figures/fig-2.png", fig, width = fig_width, height = fig_height, units = "cm",
       dpi = 600, bg = "white")

# Figure of the results ----
# From analysis.R: the simulated load group until Input/load_group contains the data
an <- load_analysis_objects("analysis")

# Colours of Figure 1: the control in greys and the load group in purples. Within a
# group, the tone follows the interference of the distractor: darker, slower
conditions <- c("ND", "HPDL", "LPDL")

tones <- c(
  Control.ND = "grey75", Control.HPDL = "grey52", Control.LPDL = "grey22",
  Load.ND = "#C2A5CF", Load.HPDL = "#9970AB", Load.LPDL = supp_color
)

group_colors <- c(Control = "grey30", Load = supp_color)
group_tints <- c(Control = "grey80", Load = "#D9C7E0")
add_tone <- function(d) {
  mutate(d, condition = factor(condition, levels = conditions), tone = paste(group, condition, sep = "."))
}

# RTs by condition: a violin of the density, the participants spread by it, and the
# means with their 95% CIs, connected
set.seed(20261105)

spread_by_density <- function(y, width = .3) {
  dens <- density(y)
  runif(length(y), -1, 1) * width * approx(dens$x, dens$y / max(dens$y), xout = y)$y
}

rt_ind <-
  an$fig_rt_ind %>%
  add_tone() %>%
  group_by(tone) %>%
  mutate(x = as.numeric(condition), x_dot = x + spread_by_density(rt)) %>%
  ungroup()

rt_means <-
  an$fig_rt %>%
  add_tone() %>%
  mutate(x = as.numeric(condition))

plot_rt <-
  ggplot(rt_ind, aes(x = x, y = rt, fill = tone, color = tone)) +
  ggdist::stat_slab(aes(group = tone), orientation = "vertical", side = "both", scale = .62, adjust = .8,
                    normalize = "groups", color = NA, alpha = .28) +
  geom_point(aes(x = x_dot), shape = 16, size = .35, alpha = .55) +
  geom_line(data = rt_means, aes(group = group), color = ink, linewidth = .45) +
  geom_linerange(data = rt_means, aes(ymin = rt - ci, ymax = rt + ci), color = "white", linewidth = 1.5,
                 lineend = "round") +
  geom_linerange(data = rt_means, aes(ymin = rt - ci, ymax = rt + ci), color = ink, linewidth = .7,
                 lineend = "round") +
  geom_point(data = rt_means, shape = 21, size = 1.5, color = "white", fill = ink, stroke = .35) +
  facet_wrap(~ group, strip.position = "bottom") +
  coord_cartesian(xlim = c(.55, 3.45), ylim = c(500, 2000), expand = FALSE) +
  scale_x_continuous(breaks = 1:3, labels = conditions) +
  scale_y_continuous(breaks = seq(500, 2000, 500)) +
  scale_color_manual(values = tones) +
  scale_fill_manual(values = tones) +
  labs(x = NULL, y = "Response time (ms)") +
  theme_results() +
  theme(panel.spacing.x = unit(6, "pt"))

# RTs by block in each group: raw data and model predictions
rt_range <- range(an$fig_preds$conf.low, an$fig_preds$conf.high)
preds <- add_tone(an$fig_preds)
blocks <- add_tone(an$fig_blocks)

plot_rt_blocks <- function(g) {
  filter(preds, group == g) %>%
    ggplot(aes(x = block, y = estimate, color = tone, fill = tone, group = condition)) +
    geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = .14, color = NA) +
    geom_line(linewidth = .65, lineend = "round") +
    geom_linerange(data = filter(blocks, group == g), aes(y = rt, ymin = rt - ci, ymax = rt + ci),
                   linewidth = .35, position = position_dodge(.22)) +
    geom_point(data = filter(blocks, group == g), aes(y = rt), shape = 21, size = 1.2, color = "white", stroke = .25,
               position = position_dodge(.22)) +
    coord_cartesian(ylim = rt_range, xlim = c(.85, 6.15), clip = "off") +
    scale_x_continuous(breaks = 1:6) +
    scale_color_manual(values = tones) +
    scale_fill_manual(values = tones) +
    labs(x = "Block", y = NULL) +
    theme_results() +
    theme(plot.margin = margin(4, 6, 3, 14))
}

# Conditional suppression effect by block in both groups, inset between both plots
plot_inset <-
  ggplot(an$fig_effects, aes(x = block, y = estimate_ms, color = group, fill = group)) +
  geom_ribbon(aes(ymin = ci_lower_ms, ymax = ci_upper_ms), alpha = .2, color = NA) +
  geom_line(linewidth = .6, lineend = "round") +
  geom_linerange(data = an$fig_supp, aes(y = estimate, ymin = estimate - se, ymax = estimate + se),
                 linewidth = .3, position = position_dodge(.2)) +
  geom_point(data = an$fig_supp, aes(y = estimate), shape = 21, size = .9, color = "white", stroke = .2,
             position = position_dodge(.2)) +
  coord_cartesian(xlim = c(.85, 6.15)) +
  scale_x_continuous(breaks = 1:6) +
  scale_color_manual(values = group_colors) +
  scale_fill_manual(values = group_colors) +
  labs(title = "Suppression effect (ms)", x = NULL, y = NULL) +
  theme_results() +
  theme(
    plot.title = element_text(size = 6.5, face = "plain", margin = margin(0, 0, 1, 0)),
    plot.margin = margin(2, 2, 1, 2)
  )

panel_blocks <-
  ggdraw(
    plot_grid(
      plot_rt_blocks("Control") +
        theme(axis.title.x = element_blank(), axis.text.x = element_blank(), axis.line.x = element_blank(),
              axis.ticks.x = element_blank()),
      plot_rt_blocks("Load"),
      ncol = 1,
      rel_heights = c(1, 1.14),
      align = "v",
      axis = "lr"
    )
  ) +
  draw_plot(plot_inset, x = .6, y = .345, width = .37, height = .185) +
  draw_label("Response time (ms)", x = .025, y = .55, angle = 90, size = 7.5, color = ink)

# Explicit knowledge: the data are bars with their SE, and the model a line with the
# band of its 95% CI
aware_shift <- c(Control = -.205, Load = .205)

aware_obs <- mutate(an$fig_aware, x = distance + aware_shift[group])
aware_pred <- mutate(an$fig_aware_pred, x = distance + aware_shift[group])
aware_top <- max(aware_pred$ci_upper, aware_obs$p_location + aware_obs$se) * 1.04

plot_aware <-
  ggplot(aware_obs, aes(x = x, fill = group, color = group)) +
  geom_col(aes(y = p_location), width = .38, color = NA) +
  annotate("segment", x = -.45, xend = 4.45, y = 1 / 8, yend = 1 / 8, color = "grey55", linewidth = .3, linetype = "22") +
  annotate("text", x = 4.45, y = 1 / 8 + .015, label = "Chance", hjust = 1, vjust = 0, size = label_size, color = "grey35") +
  geom_ribbon(data = filter(aware_pred, group == "Control"), aes(ymin = ci_lower, ymax = ci_upper), alpha = .22,
              color = NA, fill = group_colors[["Control"]]) +
  geom_ribbon(data = filter(aware_pred, group == "Load"), aes(ymin = ci_lower, ymax = ci_upper), alpha = .22,
              color = NA, fill = group_colors[["Load"]]) +
  geom_line(data = aware_pred, aes(y = p_location), linewidth = .4, lineend = "round") +
  geom_linerange(aes(ymin = p_location - se, ymax = p_location + se), color = ink, linewidth = .35) +
  annotate("rect", xmin = 3.05, xmax = 3.3, ymin = aware_top * c(.9, .79), ymax = aware_top * c(.96, .85),
           fill = group_tints) +
  annotate("text", x = 3.42, y = aware_top * c(.93, .82), label = names(group_tints), hjust = 0, size = label_size,
           color = ink) +
  coord_cartesian(ylim = c(0, aware_top)) +
  scale_y_continuous(labels = function(x) paste0(100 * x, "%"), breaks = seq(0, 1, .2)) +
  scale_x_continuous(breaks = 0:4) +
  scale_color_manual(values = group_colors) +
  scale_fill_manual(values = group_tints) +
  labs(x = "Distance from the HPDL", y = "Choices of each location") +
  theme_results()

plot_left <-
  plot_grid(
    plot_rt, plot_aware,
    ncol = 1,
    rel_heights = c(1.12, .88),
    labels = c("A", "C"),
    label_size = 10,
    align = "v",
    axis = "l"
  )

plot_results <-
  plot_grid(
    plot_left, panel_blocks,
    nrow = 1,
    rel_widths = c(.45, .55),
    labels = c("", "B"),
    label_size = 10
  )

ggsave("output/figures/fig-results.png", plot_results, width = 16, height = 12, units = "cm", dpi = 600, bg = "white")
