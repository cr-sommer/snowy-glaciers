# =============================================================================
# Statistical analysis of glacier-specific end-of-summer (EoS) snow line
# altitudes (SLAs) and trends
# Last update: 2026-01-08
# Alexander R. Groos (alexander.groos@fau.de)
# =============================================================================

# Load required libraries
library(dplyr)
library(readr)
library(lubridate)
library(purrr)
library(tidyr)
library(broom)

# === INPUT DIRECTORIES ===
sla_file <- "/PATH/Alps_Glacier_EoS_SLA_2000-2025.csv"
stats_file <- "/PATH/Alps_Glacier_EoS_SLA_2000-2025_stats.csv"

# Parameters
trend_unit <- "per_decade"   # options: "per_year" or "per_decade"
min_years  <- 10             # minimum years for mean SLA calculation

# Load data
sla_data   <- read_csv(sla_file, show_col_types = FALSE)
stats_data <- read_csv(stats_file, show_col_types = FALSE)

# === 1. Mean EoS SLA for all glaciers (sla_n >= min_years) ===
sla_vec <- stats_data %>%
  filter(!is.na(eos_sla_n) & eos_sla_n >= min_years) %>%
  pull(eos_sla_mean)

sla_summary <- tibble(
  sla_mean = round(mean(sla_vec, na.rm = TRUE), 1),
  sla_sd   = round(sd(sla_vec, na.rm = TRUE), 1),
  sla_n    = length(sla_vec)
)

# === 2. Distribution of glaciers by sla_n class ===
sla_classes <- stats_data %>%
  mutate(sla_class = cut(
    eos_sla_n,
    breaks = c(0, 9, 19, 25, 26),
    labels = c("0-9", "10-19", "20-25", "26"),
    right = TRUE
  )) %>%
  group_by(sla_class) %>%
  summarise(
    glaciers_n = n(),
    pct = round(100 * n() / nrow(stats_data), 1)
  )

# === 3. SLA trends (all, positive, significant using p < 0.05) ===

trend_scale <- ifelse(trend_unit == "per_year", 10, 1)

sla_trend_summary <- stats_data %>%
  filter(!is.na(eos_sla_trend)) %>%
  summarise(
    total_glaciers = nrow(stats_data),
    valid_trends   = n(),
    pct_na         = round(100 * (1 - valid_trends / total_glaciers), 1),
    
    # --- all trends ---
    mean_trend_all = mean(eos_sla_trend, na.rm = TRUE) * trend_scale,
    sd_trend_all   = sd(eos_sla_trend, na.rm = TRUE) * trend_scale,
    
    # --- positive trends ---
    mean_trend_pos = mean(eos_sla_trend[eos_sla_trend > 0], na.rm = TRUE) * trend_scale,
    sd_trend_pos   = sd(eos_sla_trend[eos_sla_trend > 0], na.rm = TRUE) * trend_scale,
    n_pos          = sum(eos_sla_trend > 0, na.rm = TRUE),
    pct_pos        = round(100 * n_pos / valid_trends, 1),
    
    # --- significant trends (p < 0.05) ---
    mean_trend_sig = mean(eos_sla_trend[eos_sla_sig < 0.05], na.rm = TRUE) * trend_scale,
    sd_trend_sig   = sd(eos_sla_trend[eos_sla_sig < 0.05], na.rm = TRUE) * trend_scale,
    n_sig          = sum(eos_sla_sig < 0.05, na.rm = TRUE),
    pct_sig        = round(100 * n_sig / valid_trends, 1)
  )

# === Print summary results ===
cat("\n=== 1. Mean SLA for glaciers with >=", min_years, "years ===\n")
print(sla_summary)

cat("\n=== 2. SLA_n class distribution ===\n")
print(sla_classes)

cat("\n=== 3. SLA trend summary (m/year) ===\n")
print(
  sla_trend_summary %>%
    select(
      total_glaciers, valid_trends, pct_na,
      mean_trend_all, sd_trend_all,
      mean_trend_pos, sd_trend_pos, n_pos, pct_pos,
      mean_trend_sig, sd_trend_sig, n_sig, pct_sig
    )
)
