### Glacier-specific filter of GEE Output
################################################################################
# * Filter Google Earth Engine output csv-tables and save to disk
# * Estimate snow line measurement uncertainty
# * Create preview figures
# Christian Sommer (chris.sommer@fau.de)

library(lubridate)
library(stringr)
library(plyr)
library(terra)



## working directory is input data path
wd <- paste0("/home/qo78vomo/storage/ee_snow_lines/output_01/RGI2000-v7.0-G-11_central_europe/11-01_geometries")

## forced snow line filters
obs_min_date <- "04-01" # minimum date filter (format "MM-DD"), leave empty "" or set input
obs_max_date <- "11-30" # maximum date filter (format "MM-DD"), leave empty "" or set input
spat_cov_global <- 10 # minimum spatial coverage of entire glacier [%]

## optional snow line filters >>> these are used to create confidence flag column
flag_cov_glb <- 30 # minimum reliable spat. coverage [%]
flag_area_glb <- 0.5 # minimum reliable total glacier area [km2]
flag_area_cls <- 0.09 # minimum reliable total snow class area [km2]
flag_nsir_sd <- 3 # minimum reliable infrared standard deviation
flag_nsir_th <- 7 # minimum reliable OTSU threshold value for snow
flag_nsir_bd <- 0.2 # minimum reliable interclass separability

## create output preview figures
plot_preview <- 1

## glacier inventory of processing region (only required if plot_preview = 1)
rgi_inv <- "/home/qo78vomo/storage/ee_snow_lines/inventory/RGI2000-v7.0-G-11_central_europe/RGI2000-v7.0-G-11_central_europe.shp"



## ! NO CHANGES BELOW ! ##



### Create environment and find data tables
################################################################################

# script environment
print('Create processing environment')
setwd(wd)#; print(getwd())
print(paste0('... data input path is:', wd))

# create export dir in input dir
export_dir <- paste0(wd, '/export')
dir.create(export_dir, showWarnings = F)
print(paste0('... write data output to: ', export_dir))

# find input data tables
print('Import data tables')
ls_reg_tables <- list.files(path = wd, pattern = glob2rx('*RGI2000*.csv$'), full.names = T, recursive = F)
print(paste0("... data count is: ", length(ls_reg_tables)))

################################################################################





### RESHAPE INPUT TABLES
################################################################################
print('Load table exports')
ls_grd_data <- lapply(ls_reg_tables, function(x) {read.csv(x, header = T, stringsAsFactors = F)}) # load data 
#ls_grd_name <- as.list(tools::file_path_sans_ext(basename(ls_reg_tables))) # load names
#ls_grd_name <- lapply(ls_grd_name, function(x) {strsplit(x, split = '_')[[1]][2]}) # extract RGI IDs


## satellite image information (DATE, SENSOR)
print('... reading satellite image information')
img_date <- lapply(ls_grd_data, function(x) {x$'date_start'}) # date
img_yday <- lapply(img_date, function(x) {yday(x)}) # day of the year
img_pltf <- lapply(ls_grd_data, function(x) {x$'sat_origin'}) # sensor ID

grd_image <- Map(function(x1, x2, x3) {
  data.frame(Date = x1, 
             Doy = x2, 
             Sensor = x3)
  }, 
  x1 = img_date, 
  x2 = img_yday, 
  x3 = img_pltf)

rm(img_date, img_yday, img_pltf)


## satellite image coverage section
print('... reading satellite image spatial coverage')
cov_glb <- lapply(ls_grd_data, function(x) {x$'area_valid' / x$'area_geometry' * 100}) # spat. coverage of entire glacier area (global coverage)
cov_cls <- lapply(ls_grd_data, function(x) {x$'area_class' / x$'area_valid' * 100}) # spat. fraction of snow-classified cells compared to all valid cells
sur_glb <- lapply(ls_grd_data, function(x) {x$'area_valid' / 1000000}) # area covered by sat. image in km2
sur_cls <- lapply(ls_grd_data, function(x) {x$'area_class' / 1000000}) # area classified as snow in km2

grd_spat <- Map(function(x1, x2, x3, x4) {
  data.frame(Cov_Glb = x1, 
             Cov_Cls = x2, 
             Area_Glb = x3, 
             Area_Cls = x4)
  }, 
  x1 = cov_glb, 
  x2 = cov_cls, 
  x3 = sur_glb, 
  x4 = sur_cls)

grd_spat <- lapply(grd_spat, round, digits = 2)
rm(cov_glb, cov_cls, sur_glb, sur_cls)


## classification numeric results
print('... reading numeric classification metadata')
sdev_nsir <- lapply(ls_grd_data, function(x) {x$'sd_nsir'}) # standard deviation of infrared ratio reflectance
sdev_ndwi <- lapply(ls_grd_data, function(x) {x$'sd_ndwi'}) # standard deviation of NDWI ratio reflectance
thrs_nsir <- lapply(ls_grd_data, function(x) {x$'th_nsir'}) # threshold of infrared ratio reflectance (THIS IS OTSU)
thrs_ndwi <- lapply(ls_grd_data, function(x) {x$'th_ndwi'}) # threshold of NDWI ratio reflectance (always 0.1)
bhatt_d <- lapply(ls_grd_data, function(x) {x$'bhatt_dist'}) # bhataccharya distance

grd_num <- Map(function(x1, x2, x3, x4, x5) {
  data.frame(SD_NSIR = x1, 
             SD_NDWI = x2, 
             TH_NSIR = x3, 
             TH_NDWI = x4, 
             BHA = x5)
  }, 
  x1 = sdev_nsir, 
  x2 = sdev_ndwi, 
  x3 = thrs_nsir, 
  x4 = thrs_ndwi, 
  x5 = bhatt_d)

grd_num <- lapply(grd_num, round, digits = 2)
rm(sdev_nsir, sdev_ndwi, thrs_nsir, thrs_ndwi, bhatt_d)


## snow-line elevation
print('... reading snow line observations')
sla_otsu <- lapply(ls_grd_data, function(x) {x$'tsla_otsu'}) # snow line based from Otsu threshold in meter
dlt_time <- lapply(ls_grd_data, function(x) {x$'delta_years'}) # time difference in years
dlt_elev <- lapply(ls_grd_data, function(x) {x$'elev_corr'}) # elevation correction factor in meter
sla_corr <- lapply(ls_grd_data, function(x) {x$'tsla_corr'}) # snow line corrected with vertical dh factor in meter

grd_sla <- Map(function(x1, x2, x3, x4) {
  data.frame(SLA = x1, 
             DLT_TIME = x2, 
             DLT_ELEV = x3,
             SLA_CORR = x4)
  }, 
  x1 = sla_otsu, 
  x2 = dlt_time, 
  x3 = dlt_elev,
  x4 = sla_corr)

grd_sla <- lapply(grd_sla, round, digits = 2)
rm(sla_otsu, dlt_time, dlt_elev, sla_corr)


## merge table columns
grd_output <- Map(function(x1, x2, x3, x4) {
  cbind(x1, 
        x2, 
        x3, 
        x4)
  }, 
  x1 = grd_image, 
  x2 = grd_spat, 
  x3 = grd_num, 
  x4 = grd_sla)

grd_names <- as.list(tools::file_path_sans_ext(basename(ls_reg_tables))) # RGI-IDs of glaciers
#grd_names <- lapply(grd_names, function(x) {strsplit(x, split = '_')[[1]][2]})
names(grd_output) <- grd_names
rm(ls_grd_data, grd_image, grd_spat, grd_num, grd_sla, grd_names)


## calculate snow line uncertainty
print('... calculate snow line uncertainty')
# NOTE: spatial coverage error formula is based on poly. regression with estimated coefficients (see paper for details)
spat_error <- lapply(grd_output, function(x) {
  2.367e+02 + (-1.014e+01 * x$Cov_Glb) + (1.539e-01 * x$Cov_Glb^2) + (-7.765e-04 * x$Cov_Glb^3)
  })
# NOTE: dhdt error formula is based on mean dhdt error of Central Europe region
dhdt_error <- lapply(grd_output, function(x) {abs(x$DLT_TIME * 0.21)}) # time difference x mean dhdt error
dhdt_error <- Map(function(x1, x2) {cbind(x1, x2$Date)}, x1 = dhdt_error, x2 = grd_output)
# multiply error outside dhdt survey period x 2
dhdt_error <- lapply(dhdt_error, function(x) {
  x[x[,2] < "2000-01-01" | x[,2] >= "2020-01-01",1] <- as.numeric(x[x[,2] < "2000-01-01" | x[,2] >= "2020-01-01",1]) * 2; return(x)
  })
dhdt_error <- lapply(dhdt_error, function(x) {as.numeric(x[,1])}) # return dhdt error
# other error contributions (check paper)
ndsi_error <- 88.03
range_error <- 41.73
shade_error <- 37.88

# total error budget
total_error <- Map(function(x1, x2) {
  round(sqrt(x1^2 + x2^2 + ndsi_error^2 + range_error^2 + shade_error^2), 2)
  }, 
  x1 = spat_error, 
  x2 = dhdt_error)

grd_output <- Map(function(x1, x2) {x1$SLA_ERROR <- x2; return(x1)}, x1 = grd_output, x2 = total_error)
rm(spat_error, dhdt_error, ndsi_error, range_error, shade_error, total_error); invisible(gc())
################################################################################





### FILTER INPUT TABLES
################################################################################
print('Filter table exports')

## apply forced exclusion filter
print('... pre-filter data exports')

# Apply date range filter (if provided)
if(obs_min_date != "") {
  grd_output <- lapply(grd_output, function(x) {x[format(as.Date(x$Date), '%m-%d') >= obs_min_date,]})
}
if(obs_max_date != "") {
  grd_output <- lapply(grd_output, function(x) {x[format(as.Date(x$Date), '%m-%d') <= obs_max_date,]})
}

# Apply minimum spatial coverage filter
grd_output <- lapply(grd_output, function(x) {x[x$Cov_Glb >= spat_cov_global,]}) # filter by total coverage of glacier area


## apply optional confidence filter >>> add confidence flag (filters are described in paper)
print('... optional filter (confidence flag)')
grd_output <- lapply(grd_output, function(x) { x[complete.cases(x),] })
grd_output <- lapply(grd_output, function(x) {x$QA_FLAG <- rep(0, nrow(x)); return(x)}) # add empy confidence level flag

grd_output <- lapply(grd_output, function(x) {x$QA_FLAG[x$Cov_Glb >= flag_cov_glb] <- x$QA_FLAG[x$Cov_Glb >= flag_cov_glb] + 1; return(x)}) # at least 30% global coverage
grd_output <- lapply(grd_output, function(x) {x$QA_FLAG[x$Area_Glb >= flag_area_glb] <- x$QA_FLAG[x$Area_Glb >= flag_area_glb] + 1; return(x)}) # at least 0.5 km2 global coverage
grd_output <- lapply(grd_output, function(x) {x$QA_FLAG[x$Area_Cls >= flag_area_cls] <- x$QA_FLAG[x$Area_Cls >= flag_area_cls] + 1; return(x)}) # at least 0.09 km2 snow area
grd_output <- lapply(grd_output, function(x) {x$QA_FLAG[x$SD_NSIR >= flag_nsir_sd] <- x$QA_FLAG[x$SD_NSIR >= flag_nsir_sd] + 1; return(x)}) # filter by SD of NSIR band
grd_output <- lapply(grd_output, function(x) {x$QA_FLAG[x$TH_NSIR >= flag_nsir_th] <- x$QA_FLAG[x$TH_NSIR >= flag_nsir_th] + 1; return(x)}) # filter by NSIR reflectance threshold
grd_output <- lapply(grd_output, function(x) {x$QA_FLAG[x$BHA >= flag_nsir_bd] <- x$QA_FLAG[x$BHA >= flag_nsir_bd] + 1; return(x)}) # filter by Bhatt.Distance of green band

# scale confidence flag between 0 and 1
n_filter <- length(c(flag_cov_glb, flag_area_glb, flag_area_cls, flag_nsir_sd, flag_nsir_th, flag_nsir_bd))
grd_output <- lapply(grd_output, function(x) {x$QA_FLAG <- x$QA_FLAG / n_filter; return(x)})
################################################################################





### WRITE FILTERED INPUT TABLES
################################################################################
print('Write filtered table exports')
grd_names <- paste0(export_dir, '/', names(grd_output), '.csv')
Map(function(x1, x2) {
  write.csv(x1, x2, row.names = F)
  }, 
  x1 = grd_output, 
  x2 = as.list(grd_names))
################################################################################





### OPTIONAL - create quicklooks
################################################################################

if(plot_preview == 1) {
  print('Preview time-series plots')
  
  # create export dir in input dir
  preview_dir <- paste0(wd, '/preview')
  dir.create(preview_dir, showWarnings = F)
  print(paste0('... write plot output to: ', preview_dir))
  
  # select years range for figures
  min_year <- as.integer( min(unlist(lapply(grd_output, function(x) {format(as.Date(min(x$Date)), '%Y')})), na.rm = T) )
  max_year <- as.integer( max(unlist(lapply(grd_output, function(x) {format(as.Date(max(x$Date)), '%Y')})), na.rm = T) )
  plt_year <- min_year:max_year # sequence of years to plot in figure
  print(plt_year)
  
  # plot creation loop
  print('... create plots')
  pr = txtProgressBar(1, length(grd_output), style = 3)
  plt <- 1
  for (plt in seq_along(grd_output)) {
    
    # plot elevation margins
    ylim_min <- round_any(min(grd_output[[plt]]$SLA_CORR, na.rm = T), 300, f = floor)
    ylim_max <- round_any(max(grd_output[[plt]]$SLA_CORR, na.rm = T), 300, f = ceiling)
    
    # plot colors per year
    plt_colors <- grDevices::rainbow(length(plt_year))
    names(plt_colors) <- plt_year
    
    # split data table by year
    plt_data <- grd_output[[plt]]
    plt_data$Year <- format(as.Date(plt_data$Date), '%Y')
    plt_data <- split(plt_data, f = plt_data$Year)
    
    # plot month labels
    x_pos <- yday(paste(min_year, str_pad(4:12, width = 2, pad = '0'), '01', sep = "-")) # position of month breaks based on first year
    x_lab <- str_pad(4:12, width = 2, pad = '0')
    
    # create multi-panel figure
    plot_name <- paste(preview_dir, '/', names(grd_output)[plt], '.png', sep = '')
    
    png(filename = plot_name, width = 10, height = 12, units = 'in', res = 180)
    par(mfrow = c(10,5), mar = c(2,2,2,2))
    lapply(plt_data, function(x) {
      plot(x$Doy[x$QA_FLAG==1], x$SLA_CORR[x$QA_FLAG==1], col = plt_colors[x$Year], type = "b", pch = 16, xaxt = 'n', xlab = 'time', ylab = 'elevation',
           main = x$Year[1], xlim = c(x_pos[1]-10, x_pos[length(x_pos)]+10), ylim = c(ylim_min, ylim_max),
           xaxs = 'i', yaxs = 'i')
      points(x$Doy[x$QA_FLAG > 0.5 & x$QA_FLAG < 1], x$SLA_CORR[x$QA_FLAG > 0.5 & x$QA_FLAG < 1], pch = 4, col = "black")
      abline(h = c(ylim_min, ylim_max))
      axis(side = 1, at = x_pos, labels = x_lab)
    }
    )
    dev.off()
    
    # clean
    rm(ylim_min, ylim_max, plt_colors, plt_data, x_pos, x_lab, plot_name)
    setTxtProgressBar(pr, plt)
  }
  
  
  rm(min_year, max_year, plt_year, pr); invisible(gc())
}


print('PASSED')




