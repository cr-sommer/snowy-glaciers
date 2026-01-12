# =============================================================================
# Compute end-of-summer (EoS) snow line altitude (SLA) per glacier (2000–2025)
# and the corresponding day-of-year (DOY) with statistical (SO)
# and topographic (TO) outlier flagging
# Last update: 2026-01-08
# Alexander R. Groos (alexander.groos@fau.de)
# =============================================================================

# Load required libraries
library(dplyr)
library(readr)
library(lubridate)
library(stringr)
library(purrr)

# === CONFIGURATION ===

# Define quality assurance threshold
QA_threshold <- 1

# Define SLA column number in dataset
SLA_column_no <- 25

# Define analysis parameters
start_year <- 2000
end_year <- 2025
start_day <- "07-15"  # Start of EoS period
end_day   <- "09-30"  # End of EoS period
sd_threshold <- 2     # SD multiplier for statistical outlier
z_buffer     <- 400   # Elevation buffer (m) for topographic outlier
min_scenes   <- 3     # Minimum number of scenes required for confident EoS SLA determination

# === INPUT DIRECTORIES ===

# Path to directory with csv tables (i.e. SLA time series) for all glaciers
data_directory <- "/PATH/INPUT_FOLDER_NAME"
# Path to RGI (version 7.0) directory
attr_file <- "/PATH/RGI2000-v7.0-G-11_central_europe-attributes.csv"
# Path to output directory
output_directory <- "/PATH/OUTPUT_FOLDER_NAME"

# === LOAD GLACIER ATTRIBUTE DATA FROM RGI ===
attr_data <- read_csv(attr_file, show_col_types = FALSE) %>%
  select(rgi_id, zmean_m) %>%
  mutate(id = str_extract(rgi_id, "\\d{2}-\\d{5}"))

# === Function to compute annual max SLA and DOY for one glacier ===
compute_sla_max <- function(file_path, start_day, end_day) {
  data <- read_csv(file_path, show_col_types = FALSE)
  
  # Keep only rows where QA_FLAG is greater than a certain threshold
  data <- data %>% filter(QA_FLAG >= QA_threshold)
  
  # Select only the required columns
  data <- data %>%
    select(Date = 1, SLA = SLA_column_no) %>%
    mutate(
      Date = ymd(Date),
      Year = year(Date),
      SLA = as.numeric(SLA)
    ) %>%
    filter(!is.na(SLA))
  
  # Compute DOY for seasonal filtering
  start_doy <- yday(ymd(paste0("2000-", start_day)))
  end_doy   <- yday(ymd(paste0("2000-", end_day)))
  
  data <- data %>%
    mutate(doy = yday(Date)) %>%
    filter(doy >= start_doy & doy <= end_doy)
  
  # Compute max SLA and its DOY per year
  data_annual <- data %>%
    group_by(Year) %>%
    summarise(
      SLA = if (n() > 0) round(max(SLA, na.rm = TRUE), 0) else NA_real_,
      DOY = if (n() > 0) doy[which.max(SLA)] else NA_real_,
      n_scenes = n()
    ) %>%
    ungroup()
  
  # Ensure all years (2000–2025) are included
  all_years <- tibble(Year = start_year:end_year)
  data_annual <- full_join(all_years, data_annual, by = "Year") %>%
    arrange(Year)
  
  return(data_annual)
}

# === Main function to process all glaciers ===
compute_all_glaciers_sla_and_doy <- function(data_dir, out_dir, attr_data, start_day, end_day,
                                             sd_threshold, z_buffer, min_scenes) {
  # Detect all SLA glacier files
  files_full <- list.files(data_dir, pattern = "^11-01_RGI2000-v7\\.0-G-11-\\d{5}\\.csv$", full.names = TRUE)
  
  files <- setNames(
    files_full,
    str_extract(basename(files_full), "\\d{2}-\\d{5}")
  )
  
  # Lists to store SLA and DOY outputs
  glacier_sla_list <- list()
  glacier_doy_list <- list()
  
  for (gid in names(files)) {
    file <- files[[gid]]
    df <- compute_sla_max(file, start_day, end_day)
    
    # Add reference elevation (zmean_m)
    z_ref <- attr_data$zmean_m[attr_data$id == gid]
    
    # --- Flagging SLA ---
    
    # Glacier-specific statistical and topographic outlier detection for each year
    # if number per scenes between 15 July and 30 September was less than 3
    # See Section 3.6 in the data paper for a detailed description
    
    sla_df <- df %>%
      mutate(SLA = case_when(
        is.na(SLA) ~ "NA",
        n_scenes < min_scenes & length(na.omit(SLA)) >= 10 & SLA < (mean(na.omit(SLA)) - sd_threshold * sd(na.omit(SLA))) ~ "SO",
        n_scenes < min_scenes & length(na.omit(SLA)) < 10 & SLA < (z_ref - z_buffer) ~ "TO",
        TRUE ~ as.character(SLA)
      )) %>%
      select(Year, SLA)
    colnames(sla_df)[2] <- gid
    
    # --- DOY inherits outlier flag from SLA ---
    doy_df <- df %>%
      select(Year, DOY) %>%
      left_join(sla_df, by = "Year") %>%
      mutate(
        DOY = case_when(
          get(gid) %in% c("SO", "TO", "NA") ~ get(gid),  # copy SLA outlier status
          TRUE ~ as.character(DOY)                      # keep numeric DOY
        )
      ) %>%
      select(Year, DOY)
    
    colnames(doy_df)[2] <- gid
    
    # Store in lists
    glacier_sla_list[[gid]] <- sla_df
    glacier_doy_list[[gid]] <- doy_df
  }
  
  # Merge all glaciers
  sla_combined <- reduce(glacier_sla_list, full_join, by = "Year") %>% arrange(Year)
  doy_combined <- reduce(glacier_doy_list, full_join, by = "Year") %>% arrange(Year)
  
  # === Save outputs ===
  out_sla_path <- file.path(out_dir, "Alps_Glacier_EoS_SLA_2000-2025.csv")
  out_doy_path <- file.path(out_dir, "Alps_Glacier_EoS_SLA_DOY_2000-2025.csv")
  
  write_csv(sla_combined, out_sla_path)
  write_csv(doy_combined, out_doy_path)
  
  message("✅ SLA output written to: ", out_sla_path)
  message("✅ DOY output written to: ", out_doy_path)
  
  return(list(SLA = sla_combined, DOY = doy_combined))
}

# === RUN SCRIPT ===
results <- compute_all_glaciers_sla_and_doy(
  data_dir = data_directory,
  out_dir = output_directory,
  attr_data = attr_data,
  start_day = start_day,
  end_day = end_day,
  sd_threshold = sd_threshold,
  z_buffer = z_buffer,
  min_scenes = min_scenes
)
