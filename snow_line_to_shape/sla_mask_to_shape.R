### This scripts provides tools to convert snow line altitudes to spatial masks
################################################################################
# Masks are produced based on r-terra package
# Christian Sommer (chris.sommer@fau.de)


library(terra)
library(stringr)
library(lubridate)
library(parallel)




## path options ##
wd <- "YOUR-WORKING-DIRECTORY" # working directory used to store output
data_path <- "YOUR-INPUT-DATA-PATH" # path to input data directory (>>> Geotiffs are stored here)
glac_path <- "YOUR-PATH-TO-GLACIER-INVENTORY-SHP" # path to RGI7.0 glacier inventory (e.g. ~./RGI2000-v7.0-G-11_central_europe.shp)


## processing options ##
proc_parallel <- 1 # run parallel CPUs




### create processing environment
setwd(wd); print(getwd())
dir.create(paste0(wd, '/r_tmp'), showWarnings = T)
terraOptions(tempdir = paste0(wd, '/r_tmp'), datatype = "FLT4S", overwrite = T) 




### MASK PRODUCTION => use multi-band Geotiff output of Earth Engine
print('> ENTERING SLA MASK PRODUCTION FROM RASTER MASK DATA')

# load glacier inventory
glac_inv <- vect(glac_path)

# load multi-band Geotiffs
ls_tifs <- list.files(path = data_path, pattern = glob2rx("*RGI2000*.tif$"), full.names = T, recursive = T)
print(paste0('Number of multi-band Geotiffs is: ', length(ls_tifs)))

# loop multi-band Geotiffs and convert spatial masks
i=1
for (i in seq_along(ls_tifs)) {
  
  # select filename
  print('... Load raster masks')
  tif_path <- ls_tifs[13]
  print(tif_path)
  
  # get rgi_id from filename
  tif_name <- tools::file_path_sans_ext(basename(tif_path))
  tif_name <- substr(tif_name, 7, nchar(tif_name))
  print(tif_name)
  
  # load raster file
  multi_mask <- rast(tif_path)
  print(nlyr(multi_mask))
  multi_date <- str_extract(names(multi_mask), "(?s)[0-9]{8}(?!.*[0-9]{8})") # get date from string
  print(multi_date)
  multi_doy <- yday(as.Date(multi_date, "%Y%m%d")) # calculate day of the year
  
  
  # load corresponding glacier outline
  print('... Load geometry outline')
  glac_outline <- glac_inv[glac_inv$rgi_id == tif_name,]
  glac_outline <- project(glac_outline, crs(multi_mask))
  glac_outline <- fillHoles(glac_outline) # remove inner holes in polygon
  buff_outline <- buffer(glac_outline, width = -60)
  
  # convert multi-band raster to list of raster masks
  ls_multi_mask <- as.list(multi_mask)
  
  
  ### convert to polygon masks
  print('... Convert to polygon masks')
  if (proc_parallel == 1) {
    # parallel conversion
    
    n_cores <- max(1, detectCores() - 2) # select number of CPUs
    
    ls_polys_mask <- mclapply(
      ls_multi_mask,
      function(x) {
        poly <- as.polygons(x, dissolve = TRUE)
        poly <- fillHoles(poly)
        poly <- aggregate(poly, dissolve = TRUE)
        wrap(poly) # serialize object
      },
      mc.cores = n_cores
    )
    
    ls_polys_mask <- lapply(ls_polys_mask, unwrap) # reconstruct terra objects
    
  } else {
    # sequential conversion
    
    ls_polys_mask <- lapply(ls_multi_mask, as.polygons, dissolve = T) # convert raster to polygon
    ls_polys_mask <- lapply(ls_polys_mask, fillHoles, inverse = F) # remove inner holes
    ls_polys_mask <- lapply(ls_polys_mask, function(x) aggregate(x, dissolve = T)) # dissolve if multipolygons
  }
  invisible(gc())
  
  # add dates as attribute table
  ls_polys_mask <- Map(function(x, y, z) {values(x) <- cbind(y, z); return(x)}, x = ls_polys_mask, y = as.list(multi_date), z = as.list(multi_doy))
  
  
  ### convert to line masks
  print('... Convert to lines')
  ls_lines_mask <- lapply(ls_polys_mask, as.lines) # convert polygon to lines
  ls_lines_mask <- lapply(ls_lines_mask, function(x) {crop(x, buff_outline)}) # mask by glacier outline
  ls_lines_mask <- lapply(ls_lines_mask, function(x) aggregate(x, dissolve = T)) # dissolve if multilines
  
  # add dates as attribute table
  ls_lines_mask <- Map(function(x, y, z) {values(x) <- cbind(y, z); return(x)}, x = ls_lines_mask, y = as.list(multi_date), z = as.list(multi_doy))
  
  ### merge into shapefile
  print('... Union')
  lines_mask <- do.call("rbind", ls_lines_mask)
  polys_mask <- do.call("rbind", ls_polys_mask)
  
  ### save files
  print('... Save vector masks')
  file_name <- paste0(wd, '/spat_', tif_name) # output file string
  print(file_name)
  writeVector(polys_mask, paste0(file_name, '_SLA_poly.gpkg'), layer = "SLA_poly", overwrite = T)
  writeVector(lines_mask, paste0(file_name, '_SLA_line.gpkg'), layer = "SLA_line", overwrite = T)
  
  # clean
  rm(ls_multi_mask, tif_name, tif_path)
}

print('PASSED')









