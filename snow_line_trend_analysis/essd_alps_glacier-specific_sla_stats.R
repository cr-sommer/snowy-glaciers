# =============================================================================
# Compute multiannual mean and trend of end-of-summer (EoS) snow line
# altitude (SLA) and DOY (2000–2025) with robust 3-criterion filtering
# Last update: 2026-01-08
# Alexander R. Groos (alexander.groos@fau.de)
# =============================================================================

# Load required libraries
library(dplyr)
library(readr)
library(stringr)
library(broom)
library(purrr)

# === INPUT DIRECTORIES ===
# Path to table with glacier-specific EoS SLA data
eos_sla_file     <- "/PATH/Alps_Glacier_EoS_SLA_2000-2025.csv"
# Path to table with glacier-specific EoS SLA DOY data
eos_sla_doy_file <- "/PATH/Alps_Glacier_EoS_SLA_DOY_2000-2025.csv"
# Path to RGI (version 7.0) directory
attr_file        <- "/PATH/RGI2000-v7.0-G-11_central_europe-attributes.csv"
# Path to output directory
output_file      <- "/PATH/Alps_Glacier_EoS_SLA_2000-2025_stats.csv"

# Study period
period_start <- 2000
period_end   <- 2025

# Trend unit (change per year or decade)
trend_per_decade <- FALSE

# Minimum number of valid EoS SLA data points (50 % criterion) 
min_years_for_trend <- ceiling((period_end - period_start + 1) * 0.5)
message("Minimum valid years for trend: ", min_years_for_trend)

# Load data
sla_data     <- read_csv(eos_sla_file, show_col_types = FALSE)
sla_doy_data <- read_csv(eos_sla_doy_file, show_col_types = FALSE)
attr_data    <- read_csv(attr_file, show_col_types = FALSE)

# Restrict to analysis period
sla_filtered     <- sla_data %>% filter(Year >= period_start, Year <= period_end)
sla_doy_filtered <- sla_doy_data %>% filter(Year >= period_start, Year <= period_end)

years <- sla_filtered$Year
glacier_ids <- names(sla_filtered)[-1]

# === Function: check 3-criterion data completeness ===
check_glacier_criteria <- function(years_valid, start_year, end_year) {
  total_years <- end_year - start_year + 1
  # Criterion 1: ≥ 50 % valid
  crit1 <- length(years_valid) >= ceiling(total_years * 0.5)
  # Criterion 2: ≥ 1 valid year in ≥ 4 of 5 five-year blocks
  blocks <- cut(years_valid, breaks = seq(start_year, end_year + 1, by = 5), right = FALSE)
  crit2 <- length(unique(blocks)) >= 4
  # Criterion 3: time span ≥ 15 years
  crit3 <- (max(years_valid) - min(years_valid)) >= 15
  return(all(crit1, crit2, crit3))
}

# === Function: compute mean, trend, and p-value for a series ===
compute_trend_stats <- function(values, years, trend_per_decade) {
  numeric_idx <- suppressWarnings(!is.na(as.numeric(values)))
  years_valid <- years[numeric_idx]
  vals_valid  <- as.numeric(values[numeric_idx])
  n_valid     <- length(vals_valid)
  
  res <- list(
    mean = NA_real_,
    n = n_valid,
    trend = NA_real_,
    pval = NA_real_,
    temp_trend = NA_real_
  )
  
  if (n_valid == 0) return(res)
  
  res$mean <- mean(vals_valid, na.rm = TRUE)
  
  if (check_glacier_criteria(years_valid, period_start, period_end)) {
    model <- lm(vals_valid ~ years_valid)
    model_summary <- tidy(model)
    slope <- model_summary$estimate[2]
    pval  <- model_summary$p.value[2]
    if (trend_per_decade) slope <- slope * 10
    
    res$trend <- round(slope, 3)
    res$pval <- pval
  }
  
  return(res)
}

# === Compute SLA and DOY statistics for each glacier ===
stats_list <- map(glacier_ids, function(id) {
  sla_vals <- sla_filtered[[id]]
  doy_vals <- sla_doy_filtered[[id]]
  
  sla_stats <- compute_trend_stats(sla_vals, years, trend_per_decade)
  doy_stats <- compute_trend_stats(doy_vals, years, trend_per_decade)
  
  tibble(
    id_short = id,
    eos_sla_mean = round(sla_stats$mean, 0),
    eos_sla_n = sla_stats$n,
    eos_sla_trend = round(sla_stats$trend, 3),
    eos_sla_sig = round(sla_stats$pval, 3),
    eos_temp_trend = round(sla_stats$temp_trend, 3),
    eos_sla_doy_mean = round(doy_stats$mean, 0),
    eos_sla_doy_trend = round(doy_stats$trend, 3),
    eos_sla_doy_sig = round(doy_stats$pval, 3)
  )
})

sla_stats <- bind_rows(stats_list)

# === Join with attribute data and save ===
attr_with_stats <- attr_data %>%
  mutate(id_short = str_extract(rgi_id, "\\d{2}-\\d{5}")) %>%
  left_join(sla_stats, by = "id_short") %>%
  select(-id_short)

# Keep only glaciers with valid SLA mean
attr_with_stats_clean <- attr_with_stats %>%
  filter(!is.na(eos_sla_mean))

# Save output
write_csv(attr_with_stats_clean, output_file)

cat("✅ Summary table with EoS SLA and DOY statistics saved to:\n", output_file, "\n")
