# =============================================================================
# Script for Fig. 7: Glacier-specific EoS SLA time series examples
# Last update: 2026-01-08
# Alexander R. Groos (alexander.groos@fau.de)
# =============================================================================

# Path to EoS SLA table
annual_eos_sla <- read.csv("/PATH/Alps_Glacier_EoS_SLA_2000-2025.csv", header = T)

# Vector comprising all years of time series
years <- annual_eos_sla$Year

# Glacier selection
adamello <- "11.03008"
aletsch <- "11.02596"
fiescher <- "11.02611"
gorner <- "11.01225"
hintereisferner <- "11.03116"
kanderfirn <- "11.01457"
mer_de_glace <- "11.00757"
morteratsch <- "11.02216"
pasterze <- "11.03664"
rhone <- "11.01706"
schlatenkees <- "11.03808"
unteraar <- "11.02645"

# Extract EoS SLA data for selected glaciers
adamello_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", adamello))], use.names=FALSE))
aletsch_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", aletsch))], use.names=FALSE))
fiescher_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", fiescher))], use.names=FALSE))
gorner_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", gorner))], use.names=FALSE))
hintereisferner_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", hintereisferner))], use.names=FALSE))
kanderfirn_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", kanderfirn))], use.names=FALSE))
mer_de_glace_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", mer_de_glace))], use.names=FALSE))
morteratsch_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", morteratsch))], use.names=FALSE))
pasterze_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", pasterze))], use.names=FALSE))
rhone_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", rhone))], use.names=FALSE))
schlatenkees_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", schlatenkees))], use.names=FALSE))
unteraar_eos_sla <- as.numeric(unlist(annual_eos_sla[which(colnames(annual_eos_sla)==paste0("X", unteraar))], use.names=FALSE))

# === Function to compute glacier-specific trends ===
glacier_trend <- function(x, y) {
  # x = years, y = glacier elevations (or SLA)
  
  # Remove NA values
  ok <- complete.cases(x, y)
  xx <- x[ok]
  yy <- y[ok]
  
  # Fit linear model (trend)
  model <- lm(yy ~ xx)
  coef_table <- summary(model)$coefficients
  
  # Extract slope and p-value
  slope   <- coef_table[2, 1]          # meters per year
  p_value <- coef_table[2, 4]          # significance
  
  # First and last valid years
  x_start <- xx[1]
  x_end   <- xx[length(xx)]
  
  # Predicted values at endpoints
  y_start <- predict(model, newdata = data.frame(xx = x_start))
  y_end   <- predict(model, newdata = data.frame(xx = x_end))
  
  # Return everything needed
  list(
    slope = slope,
    p_value = p_value,
    x_start = x_start,
    x_end = x_end,
    y_start = y_start,
    y_end = y_end
  )
}


# PNG output
png("/PATH/essd_figure_7.png", 
    width = 16.8, height = 12, res = 300, units = "cm")

# Layout: 1 row, 4 columns, reduced space
par(mfrow = c(4, 3), mgp = c(2.5, 1, 0), mar = c(1, 2.3, 0, 0), oma = c(2.75, 1.4, 0.5, 0.5), xpd = NA)

# --- (b) Plot time series for Mer de Glacer ---
mer_de_glace_lm <- glacier_trend(years, mer_de_glace_eos_sla)

plot(years, mer_de_glace_eos_sla, xlab = "", ylab = "EoS SLA (m a.s.l.)", t = "b", yaxt = "n", ylim = c(2800, 3350),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")
lines(c(mer_de_glace_lm$x_start, mer_de_glace_lm$x_end),
      c(mer_de_glace_lm$y_start, mer_de_glace_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2800, 3050, 3300), labels = TRUE)
text(2000.8, 3300, "(b)")
text(2007.8, 3301, "Mer de Glace", font = 2)
text(2020.5, 2900, bquote(beta == .(round(mer_de_glace_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2020, 2820, bquote(p == .(round(mer_de_glace_lm$p_value, 3))), col = "chocolate1")
text(2019, 2822, "p < 0.05", col = "chocolate1")

# --- (c) Plot time series for Gornergletscher ---
gorner_lm <- glacier_trend(years, gorner_eos_sla)

plot(years, gorner_eos_sla, xlab = "", ylab = "", t = "b", yaxt = "n", ylim = c(3100, 3750),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")  #, main = "")
lines(c(gorner_lm$x_start, gorner_lm$x_end),
      c(gorner_lm$y_start, gorner_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(3100, 3400, 3700), labels = TRUE)
text(2000.8, 3685, "(c)")
text(2009.0, 3686, "Gornergletscher", font = 2)
text(2008.1, 3550, bquote(beta == .(round(gorner_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2005, 3460, bquote(p == .(round(gorner_lm$p_value, 3))), col = "chocolate1")
text(2006, 3460, "p < 0.05", col = "chocolate1")

# --- (d) Plot time series for Kanderfirn --- 
kanderfirn_lm <- glacier_trend(years, kanderfirn_eos_sla)

plot(years, kanderfirn_eos_sla, xlab = "", ylab = "", t = "b",  yaxt = "n", ylim = c(2530, 3070),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")
lines(c(kanderfirn_lm$x_start, kanderfirn_lm$x_end),
      c(kanderfirn_lm$y_start, kanderfirn_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2550, 2800, 3050), labels = TRUE)
text(2001, 3015, "(d)")
text(2007, 3016, "Kanderfirn", font = 2)
text(2019.7, 2625, bquote(beta == .(round(kanderfirn_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2019, 2400, bquote(p == .(round(kanderfirn_lm$p_value, 3))), col = "chocolate1")
text(2017.7, 2550, "p < 0.05", col = "chocolate1")

# --- (e) Plot time series for Aletschgletscher ---
aletsch_lm <- glacier_trend(years, aletsch_eos_sla)

plot(years, aletsch_eos_sla, xlab = "", ylab = "EoS SLA (m a.s.l.)", t = "b", yaxt = "n", ylim = c(2880, 3350),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")
lines(c(aletsch_lm$x_start, aletsch_lm$x_end),
      c(aletsch_lm$y_start, aletsch_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2900, 3100, 3300), labels = TRUE)
text(2000.8, 3300, "(e)")
text(2009.2, 3301, "Aletschgletscher", font = 2)
text(2019.9, 2970, bquote(beta == .(round(aletsch_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2019, 2830, bquote(p == .(round(aletsch_lm$p_value, 3))), col = "chocolate1")
text(2017.9, 2900, "p < 0.05", col = "chocolate1")

# --- (f) Plot time series for Fieschergletscher ---
fiescher_lm <- glacier_trend(years, fiescher_eos_sla)

plot(years, fiescher_eos_sla, xlab = "", ylab = "", t = "b", yaxt = "n", ylim = c(2930, 3370),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")
lines(c(fiescher_lm$x_start, fiescher_lm$x_end),
      c(fiescher_lm$y_start, fiescher_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2975, 3150, 3325), labels = TRUE)
text(2000.7, 3320, "(f)")
text(2009.4, 3321, "Fieschergletscher", font = 2)
text(2020.5, 3010, bquote(beta == .(round(fiescher_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2019, 2960, bquote(p == .(round(fiescher_lm$p_value, 3))), col = "chocolate1")
text(2019, 2950, "p < 0.05", col = "chocolate1")

# --- (g) Plot time series for Unteraargletscher ---
unteraar_lm <- glacier_trend(years, unteraar_eos_sla)

plot(years, unteraar_eos_sla, xlab = "", ylab = "", t = "b", yaxt = "n", ylim = c(2650, 3250),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")
lines(c(unteraar_lm$x_start, unteraar_lm$x_end),
      c(unteraar_lm$y_start, unteraar_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2700, 2950, 3200), labels = TRUE)
text(2000.8, 3190, "(g)")
text(2009.8, 3191, "Unteraargletscher", font = 2)
text(2008, 3070, bquote(beta == .(round(unteraar_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2005, 2950, bquote(p == .(round(unteraar_lm$p_value, 3))), col = "chocolate1")
text(2006, 2980, "p < 0.05", col = "chocolate1")

# --- (h) Plot time series for Rhonegletscher ---
rhone_lm <- glacier_trend(years, rhone_eos_sla)

plot(years, rhone_eos_sla, xlab = "", ylab = "EoS SLA (m a.s.l.)", t = "b", yaxt = "n", ylim = c(2780, 3220),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")  #, main = "")
lines(c(rhone_lm$x_start, rhone_lm$x_end),
      c(rhone_lm$y_start, rhone_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2800, 3000, 3200), labels = TRUE)
text(2000.8, 3170, "(h)")
text(2009, 3171, "Rhonegletscher", font = 2)
text(2008, 3080, bquote(beta == .(round(rhone_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2005, 2990, bquote(p == .(round(rhone_lm$p_value, 3))), col = "chocolate1")
text(2006.5, 3015, "p < 0.05", col = "chocolate1")

# --- (i) Plot time series for Morteratschgletscher ---
morteratsch_lm <- glacier_trend(years, morteratsch_eos_sla)

plot(years, morteratsch_eos_sla, xlab = "", ylab = "", t = "b", yaxt = "n", ylim = c(2850, 3400),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")  #, main = "")
lines(c(morteratsch_lm$x_start, morteratsch_lm$x_end),
      c(morteratsch_lm$y_start, morteratsch_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2900, 3125, 3350), labels = TRUE)
text(2000.2, 3350, "(i)")
text(2009.9, 3351, "Morteratschgletscher", font = 2)
text(2007, 3270, bquote(beta == .(round(morteratsch_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2020, 2470, bquote(p == .(round(morteratsch_lm$p_value, 3))), col = "chocolate1")
text(2005, 3200, "p < 0.05", col = "chocolate1")

# --- (j) Plot time series for Adamello Glacier ---
adamello_lm <- glacier_trend(years, adamello_eos_sla)

plot(years, adamello_eos_sla, xlab = "", ylab = "", t = "b", yaxt = "n", ylim = c(2860, 3210),
     pch = 21, col = "black", bg = "dodgerblue3", xaxt = "n")  #, main = "")
lines(c(adamello_lm$x_start, adamello_lm$x_end),
      c(adamello_lm$y_start, adamello_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(1, at = seq(2000, 2025, 5), labels = FALSE)
axis(2, at = c(2900, 3050, 3200), labels = TRUE)
text(2000.8, 3170, "(j)")
text(2009, 3171, "Adamello Glacier", font = 2)
text(2007.5, 3110, bquote(beta == .(round(adamello_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2020, 2790, bquote(p == .(round(adamello_lm$p_value, 3))), col = "chocolate1")
text(2005.9, 3060, "p < 0.05", col = "chocolate1")

# --- (k) Plot time series for Hintereisferner ---
hintereisferner_lm <- glacier_trend(years, hintereisferner_eos_sla)

plot(years, hintereisferner_eos_sla, xlab = "Year", ylab = "EoS SLA (m a.s.l.)", t = "b", yaxt = "n", ylim = c(2850, 3270),
     pch = 21, col = "black", bg = "dodgerblue3")
lines(c(hintereisferner_lm$x_start, hintereisferner_lm$x_end),
      c(hintereisferner_lm$y_start, hintereisferner_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(2, at = c(2875, 3050, 3225), labels = TRUE)
text(2000.7, 3225, "(k)")
text(2008.2, 3226, "Hintereisferner", font = 2)
text(2020, 2930, bquote(beta == .(round(hintereisferner_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2020, 2890, bquote(p == .(round(hintereisferner_lm$p_value, 3))), col = "chocolate1")
text(2018.5, 2870, "p < 0.05", col = "chocolate1")

# --- (l) Plot time series for Schlatenkees ---
schlatenkees_lm <- glacier_trend(years, schlatenkees_eos_sla)

plot(years, schlatenkees_eos_sla, xlab = "Year", ylab = "", t = "b", yaxt = "n", ylim = c(2700, 3250),
     pch = 21, col = "black", bg = "dodgerblue3")
lines(c(schlatenkees_lm$x_start, schlatenkees_lm$x_end),
      c(schlatenkees_lm$y_start, schlatenkees_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(2, at = c(2750, 2975, 3200), labels = TRUE)
text(2000.6, 3200, "(l)")
text(2007.4, 3201, "Schlatenkees", font = 2)
text(2019.5, 2800, bquote(beta == .(round(schlatenkees_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2020, 2800, bquote(p == .(round(schlatenkees_lm$p_value, 3))), col = "chocolate1")
text(2017.5, 2725, "p < 0.05", col = "chocolate1")

# --- (m) Plot time series for Pasterze ---
pasterze_lm <- glacier_trend(years, pasterze_eos_sla)

plot(years, pasterze_eos_sla, xlab = "Year", ylab = "", t = "b", yaxt = "n", ylim = c(2730, 3180),
     pch = 21, col = "black", bg = "dodgerblue3")
lines(c(pasterze_lm$x_start, pasterze_lm$x_end),
      c(pasterze_lm$y_start, pasterze_lm$y_end),
      col = "chocolate1", lwd = 1, lty = 2)
axis(2, at = c(2750, 2950, 3150), labels = TRUE)
text(2001.3, 3130, "(m)")
text(2006.8, 3131, "Pasterze", font = 2)
text(2021, 2810, bquote(beta == .(round(pasterze_lm$slope, 1)) ~ "m/yr"), col = "chocolate1")
#text(2020, 2750, bquote(p == .(round(pasterze_lm$p_value, 3))), col = "chocolate1")
text(2020.2, 2750, "p < 0.05", col = "chocolate1")

dev.off()