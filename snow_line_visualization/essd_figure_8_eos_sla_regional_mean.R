# =============================================================================
# Script for Fig. 8: Glacier-specific EoS SLA trend for the Alps (2000-2025)
# Last update: 2026-01-08
# Alexander R. Groos (alexander.groos@fau.de)
# =============================================================================

# Load required packages
library(tidyverse)
library(viridis)

# Paths
sla_path <- "/PATH/Alps_Glacier_EoS_SLA_2000-2025.csv"
doy_path <- "/PATH/Alps_Glacier_EoS_SLA_DOY_2000-2025.csv"

# Read SLA (treat NA, SO, TO as missing)
sla_df <- read_csv(sla_path, na = c("NA", "SO", "TO"))

# Read DOY (also treat SO, TO as NA)
doy_df <- read_csv(doy_path, na = c("NA", "SO", "TO"))

# Convert SLA to long format
sla_long <- sla_df %>%
  pivot_longer(-Year, names_to = "Glacier_ID", values_to = "EoS_SLA")

# Convert DOY to long format
doy_long <- doy_df %>%
  pivot_longer(-Year, names_to = "Glacier_ID", values_to = "DOY")

# Merge SLA & DOY by Year + Glacier_ID
df_long <- sla_long %>%
  left_join(doy_long, by = c("Year", "Glacier_ID"))

# Filter glaciers with ≥10 valid SLA observations
valid_glaciers <- df_long %>%
  filter(!is.na(EoS_SLA)) %>%
  count(Glacier_ID) %>%
  filter(n >= 10) %>%
  pull(Glacier_ID)

df_filtered <- df_long %>%
  filter(Glacier_ID %in% valid_glaciers)

# Normalize by glacier mean
df_normalized <- df_filtered %>%
  group_by(Glacier_ID) %>%
  mutate(EoS_SLA_anomaly = EoS_SLA - mean(EoS_SLA, na.rm = TRUE)) %>%
  ungroup()

# Compute regional annual stats
regional_stats <- df_normalized %>%
  group_by(Year) %>%
  summarise(
    regional_mean = mean(EoS_SLA_anomaly, na.rm = TRUE),
    regional_sd   = sd(EoS_SLA_anomaly, na.rm = TRUE),
    n_glaciers    = sum(!is.na(EoS_SLA_anomaly)),
    mean_doy      = mean(DOY, na.rm = TRUE)
  )

# Total number of glaciers
total_glaciers <- length(unique(df_normalized$Glacier_ID))

# Compute regional stats and add percentage
regional_stats <- df_normalized %>%
  group_by(Year) %>%
  summarise(
    regional_mean = mean(EoS_SLA_anomaly, na.rm = TRUE),
    regional_sd   = sd(EoS_SLA_anomaly, na.rm = TRUE),
    n_glaciers    = sum(!is.na(EoS_SLA_anomaly)),
    mean_doy      = mean(DOY, na.rm = TRUE)
  ) %>%
  mutate(percent_glaciers = round(100 * n_glaciers / total_glaciers, 0))

# === Linear trend model ===
lm_model <- lm(regional_mean ~ Year, data = regional_stats)
slope     <- coef(lm_model)[2]                     
r2_value  <- summary(lm_model)$r.squared           
p_value   <- summary(lm_model)$coefficients[2,4]   

# RMSD of residuals
rmsd <- sqrt(mean(residuals(lm_model)^2, na.rm = TRUE))

beta_txt <- sprintf("β = %.2f m/yr", slope)
r2_txt   <- sprintf("R² = %.2f", r2_value)
p_txt    <- ifelse(p_value < 0.001, "p < 0.001", sprintf("p = %.3f", p_value))
rmsd_txt <- sprintf("RMSD = %.1f m", rmsd)

# === Predict trend values for dynamic label placement with offsets ===
offset_up   <- 15  # labels above trend
offset_down <- 15  # labels below trend

regional_stats <- regional_stats %>%
  mutate(trend_fit = predict(lm_model, newdata = data.frame(Year = Year))) %>%
  mutate(label_y = ifelse(regional_mean >= trend_fit,
                          regional_mean + offset_up,    # above trend → higher
                          regional_mean - offset_down)) # below trend → lower

# === CREATE FIGURE ===
show_sd <- TRUE

p <- ggplot(regional_stats, aes(x = Year, y = regional_mean)) +
  
  {if (show_sd)
    geom_ribbon(aes(ymin = regional_mean - regional_sd,
                    ymax = regional_mean + regional_sd),
                fill = "grey80", alpha = 0.5)
  } +
  
  geom_line(color = "black", size = 1) +
  geom_point(aes(color = mean_doy), size = 4) +
  
  # Dynamic percentage labels
  geom_text(
    aes(x = Year, y = label_y, label = paste0(percent_glaciers, "%")),
    size = 4,
    color = "black"
  ) +
  
  scale_color_viridis_c(option = "viridis", name = "Mean DOY") +
  
  geom_smooth(method = "lm", se = FALSE, color = "chocolate1", size = 1,
              linetype = "dashed") +
  
  annotate(
    "text",
    x = min(regional_stats$Year) + 1,
    y = max(regional_stats$regional_mean, na.rm = TRUE),
    label = paste(beta_txt, r2_txt, p_txt, rmsd_txt, sep = "\n"),
    hjust = 0, vjust = 0,
    size = 5,
    color = "chocolate1"
  ) +
  
  labs(
    x = "Year",
    y = "ΔEoS SLA (m)"
  ) +
  
  theme_bw(base_size = 14) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = c(0.95, 0.05),
    legend.justification = c("right", "bottom"),
    legend.background = element_rect(fill = alpha("white", 0.8), color = "black")
  )

# Save figure
ggsave(
  filename = "/PATH/essd_figure_8.png",
  plot = p,
  width = 10,
  height = 7,
  dpi = 300
)
