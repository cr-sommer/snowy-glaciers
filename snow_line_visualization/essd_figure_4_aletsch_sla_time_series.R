# =============================================================================
# Script for Fig. 4: SLA time series for Grosser Aletschgletscher (2000-2025)
# Last update: 2026-01-08
# Alexander R. Groos (alexander.groos@fau.de)
# =============================================================================

# Load required library
library(dplyr)

# Determine quality assurance threshold
QA_threshold <- 1

# Load transient SLA data for Aletschgletscher
aletsch_sla <- read.csv("/PATH/11-01_RGI2000-v7.0-G-11-02596.csv")

# Reformat date
aletsch_sla$Date <- as.Date(aletsch_sla$Date, format = "%Y-%m-%d")

# Keep only rows where QA_FLAG is greater than a certain threshold
aletsch_sla <- aletsch_sla[aletsch_sla$QA_FLAG >= QA_threshold, ]

# === Keep only measurement dates in April–November ===
aletsch_sla$month <- as.numeric(format(aletsch_sla$Date, "%m"))

# Keep April–November
aletsch_sla <- aletsch_sla[aletsch_sla$month >= 4 & aletsch_sla$month <= 11, ]

# Extract year
aletsch_sla$Year <- as.numeric(format(aletsch_sla$Date, "%Y"))

# === Winter polygon function ===

add_winter_shading <- function(year, ymin, ymax, col = "grey90") {
  # Winter: Dec 1 (prev year) – Mar 31 (current year)
  x_start <- as.Date(paste0(year - 1, "-12-01"))
  x_end   <- as.Date(paste0(year, "-03-31"))
  
  polygon(
    x = c(x_start, x_end, x_end, x_start),
    y = c(ymin, ymin, ymax, ymax),
    col = col,
    border = NA
  )
}

# PNG output
png("/PATH/essd_figure_4.png",
    width = 16, height = 16, res = 300, units = "cm")

par(mfrow = c(3, 1), mgp = c(2.5, 1, 0), mar = c(4, 4, 0, 0), oma = c(0, 0, 0.5, 0.5))


# === CREATE FIGURE ===

# --- (a) Full time series 2000–2025 ---
plot(NA, NA, type = "n",
     xlim = range(aletsch_sla$Date),
     ylim = range(aletsch_sla$SLE_Corr, na.rm = TRUE),
     ylab = "SLA (m a.s.l.)", xlab = "Period (2000–2025)", xaxs="i", xaxt = "n")

ymin <- par("usr")[3]
ymax <- par("usr")[4]

# Shade winters
for (yr in 2001:2025) add_winter_shading(yr, ymin, ymax)

# Draw each year as a separate line
for(yr in unique(aletsch_sla$Year)) {
  seg <- aletsch_sla %>% filter(Year == yr)
  lines(seg$Date, seg$SLE_Corr, col = "dodgerblue4", lwd = 1)
}

# Year markers
abline(v = as.Date(paste0(2000:2019, "-01-01")), lty = 3)
abline(v = as.Date(paste0(2021:2025, "-01-01")), lty = 3)
abline(v = as.Date(c("2020-01-01", "2025-10-10")), lty = 2, lwd = 2.5)

# Add xlabels (5-year steps)
axis.Date(1, at = seq(as.Date("2000-01-01"), as.Date("2025-01-01"), by = "5 years"), format = "%Y")

mtext("(a)", side = 2, line = 2.4, at = 3300, cex = 0.8, las = 2)

# --- (b) 2020–2025 subset ---
plot(NA, NA, type = "n",
     xlim = as.Date(c("2020-01-01", "2025-10-31")),
     ylim = range(aletsch_sla$SLE_Corr, na.rm = TRUE),
     ylab = "SLA (m a.s.l.)", xlab = "Period (2020–2025)",
     xaxs="i", xaxt="n")

ymin <- par("usr")[3]
ymax <- par("usr")[4]

for (yr in 2021:2025) add_winter_shading(yr, ymin, ymax)

for(yr in unique(aletsch_sla$Year[aletsch_sla$Year >= 2020 & aletsch_sla$Year <= 2025])) {
  seg <- aletsch_sla %>% filter(Year == yr)
  lines(seg$Date, seg$SLE_Corr, col = "dodgerblue4", lwd = 1)
}

abline(v = as.Date(paste0(2020:2022, "-01-01")), lty = 3)
abline(v = as.Date("2025-01-01"), lty = 3)
abline(v = as.Date(c("2023-01-01", "2024-01-01")), lty = 2, lwd = 2.5)

axis(side = 1, at = as.Date(paste0(2020:2025, "-01-01")), labels = 2020:2025)

mtext("(b)", side = 2, line = 2.4, at = 3300, cex = 0.8, las = 2)



# --- (c) 2023 subset

plot(NA, NA, type = "n",
     xlim = as.Date(c("2023-01-01", "2023-12-31")),
     ylim = range(aletsch_sla$SLE_Corr, na.rm = TRUE),
     ylab = "SLA (m a.s.l.)", xlab = "Period (2023)",
     xaxs = "i", xaxt = "n")

ymin <- par("usr")[3]
ymax <- par("usr")[4]

# Shade winter entering 2023 and leaving 2023
add_winter_shading(2023, ymin, ymax)
add_winter_shading(2024, ymin, ymax)

seg <- aletsch_sla %>% filter(Year == 2023)
lines(seg$Date, seg$SLE_Corr, col = "dodgerblue4", lwd = 1)

# Plot 3: 2023 zoom, months Jan–Dec
axis.Date(1, at = seq(as.Date("2023-01-01"), as.Date("2023-12-01"), by = "1 month"), format = "%b")

mtext("(c)", side = 2, line = 2.4, at = 3300, cex = 0.8, las = 2)

# =====================================================================

dev.off()
