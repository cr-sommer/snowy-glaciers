# =============================================================================
# Script for Fig. 6 (scatter plots): EoS SLA vs. glacier variable
# Last update: 2026-01-08
# Alexander R. Groos (alexander.groos@fau.de)
# =============================================================================

# Path to EoS SLA statistics table
eos_sla_stats <- read.csv("/PATH/Alps_Glacier_EoS_SLA_2000-2025_stats.csv", header = TRUE)

# Linear regression model (mean glacier-specific EoS SLA vs. glacier mean elevation)
lm_eos_sla <- lm(eos_sla_stats$eos_sla_mean ~ eos_sla_stats$zmean_m)

# Calculate R² and RMSD
R2 <- round(summary(lm_eos_sla)$r.squared, 2)
RMSD <- round(sd(eos_sla_stats$zmean_m-eos_sla_stats$eos_sla_mea),0)

# === CREATE FIGURE 6 ===

# PNG output
png("/PATH/essd_figure_6.png", 
    width = 16, height = 12.5, res = 300, units = "cm")

# Layout: 1 row, 4 columns, reduced space
par(mfrow = c(2, 3), mgp = c(2.5, 1, 0), mar = c(4, 1, 0, 0), oma = c(0, 3.0, 0.5, 0.5))

# --- Mean EoS SLA vs. Longitude ---
plot(eos_sla_stats$cenlon, eos_sla_stats$eos_sla_mean, pch = 21, bg = adjustcolor("dodgerblue3", alpha.f = 0.5), col = adjustcolor( "black", alpha.f = 0.5), xlab = "Longitude (°)", ylab = "Mean EoS SLA (m a.s.l.)", ylim = c(2000, 3750), xaxt = "n")
abline(h = mean(eos_sla_stats$eos_sla_mean), lty = 2)
axis(1, at = seq(7, 13, 2), labels = TRUE)
text(6.4, 3700, "(a)")
mtext(side = 2, text = "Mean EoS SLA (m a.s.l.)", line = 2.5, cex = 0.7)

# --- Mean EoS SLA vs. Latitude ---
plot(eos_sla_stats$cenlat, eos_sla_stats$eos_sla_mean, pch = 21, bg = adjustcolor("dodgerblue3", alpha.f = 0.5), col = adjustcolor( "black", alpha.f = 0.5), xlab = "Latitude (°)", ylab = "", ylim = c(2000, 3750), xaxt = "n", yaxt = "n")
abline(h = mean(eos_sla_stats$eos_sla_mean), lty = 2)
axis(1, at = seq(45, 47, 1), labels = TRUE)
axis(2, at = seq(2000, 3500, 500), labels = FALSE)
text(44.95, 3700, "(b)")

# --- Mean EoS SLA vs. Area ---
plot(eos_sla_stats$area_km2, eos_sla_stats$eos_sla_mean, pch = 21, bg = adjustcolor("dodgerblue3", alpha.f = 0.5), col = adjustcolor( "black", alpha.f = 0.5), xlab = "Area (km²)", ylab = "", ylim = c(2000, 3750), yaxt = "n")
abline(h = mean(eos_sla_stats$eos_sla_mean), lty = 2)
axis(2, at = seq(2000, 3500, 500), labels = FALSE)
text(16, 3600, "(c)")

# --- Mean EoS SLA vs. Elevation ---
plot(eos_sla_stats$zmean_m, eos_sla_stats$eos_sla_mean, pch = 21, bg = adjustcolor("dodgerblue3", alpha.f = 0.5), col = adjustcolor( "black", alpha.f = 0.5), xlab = "Mean elevation (m a.s.l.)", ylab = "Mean EoS SLA (m a.s.l.)", xlim = c(2000, 3650), ylim = c(2000, 3750))
abline(h = mean(eos_sla_stats$eos_sla_mean), lty = 2)
abline(v = mean(eos_sla_stats$zmean_m), lty = 2)
lines(x = c(1950, 3700), y = c(1950, 3700), lty = 2, col = "black", lwd = 1.5)
abline(lm_eos_sla, col = "chocolate1", lwd = 1.5, lty = 1)
text(2255, 3360, paste0("R2 = ", R2), col = "chocolate1")
text(2360, 3240, paste0("RMSD = ", RMSD, " m"), col = "chocolate1")
text(2050, 3700, "(d)")
mtext(side = 2, text = "Mean EoS SLA (m a.s.l.)", line = 2.5, cex = 0.7)

# --- Mean EoS SLA vs. Slope ---
plot(eos_sla_stats$slope_deg, eos_sla_stats$eos_sla_mean, pch = 21, bg = adjustcolor("dodgerblue3", alpha.f = 0.5), col = adjustcolor( "black", alpha.f = 0.5), xlab = "Mean slope (°)", ylab = "", ylim = c(2000, 3750), yaxt = "n")
abline(h = mean(eos_sla_stats$eos_sla_mean), lty = 2)
axis(2, at = seq(2000, 3500, 500), labels = FALSE)
text(7, 3700, "(e)")

# --- Mean EoS SLA vs. Aspect ---
plot(eos_sla_stats$aspect_deg, eos_sla_stats$eos_sla_mean, pch = 21, bg = adjustcolor("dodgerblue3", alpha.f = 0.5), col = adjustcolor( "black", alpha.f = 0.5), xlab = "Mean aspect (°)", ylab = "", ylim = c(2000, 3750), xaxt = "n", yaxt = "n")
abline(h = mean(eos_sla_stats$eos_sla_mean), lty = 2)
axis(1, at = seq(0, 360, 90), labels = TRUE)
axis(2, at = seq(2000, 3500, 500), labels = FALSE)
text(6, 3700, "(f)")

dev.off()
