### TSLA FUNCTIONS LIBRARY
# SENTINEL-2 FUNCTIONS SECTION: sensor-specific functions [Sentinel-2]
# LANDSAT FUNCTIONS SECTION: sensor-specific functions [Landsat-4-9]
# MAIN FUNCTIONS SECTION: general functions which are shared by different collections
# THRESHOLD FUNCTIONS SECTION: functions for image thresholding and TSLA selection
# EXPORT FUNCTIONS SECTION: data export functions

import ee

print('... Loading Raster Functions Catalogue')


# SENTINEL-2 functions #################################################################################################
########################################################################################################################

# function to apply Sentinel-2 DN scaling factors
def apply_sentinel2_scale(image):
    image_scaled = image.divide(10000)
    return image_scaled.copyProperties(image, ['system:time_start', 'system:id', 'MEAN_SOLAR_AZIMUTH_ANGLE', 'MEAN_SOLAR_ZENITH_ANGLE'])


# function to calculate NIR/SWIR Ratio of Sentinel-2
def add_s2_nsir(image):
    band_nir = image.select('B8')
    band_swr = image.select('B12')
    band_new = band_nir.multiply(band_nir.divide(band_swr))
    return image.addBands(band_new.rename('NSIR'))


# function to calculate NDWI of Sentinel-2
def add_s2_ndwi(image):
    band_new = image.normalizedDifference(['B3', 'B8'])
    return image.addBands(band_new.rename('NDWI'))


# function to calculate NDSI of Sentinel-2
def add_s2_ndsi(image):
    band_new = image.normalizedDifference(['B3', 'B12'])
    return image.addBands(band_new.rename('NDSI'))

########################################################################################################################
########################################################################################################################



# LANDSAT functions ####################################################################################################
########################################################################################################################

# function to apply Landsat 4-7 DN scaling factors
def apply_landsat4_5_7_scale(image):
    optical_bands = image.select('SR_B.')
    optical_bands = optical_bands.updateMask(optical_bands.lte(65455))
    optical_bands = optical_bands.multiply(0.0000275).add(-0.2)
    return image.addBands(optical_bands, None, True)


# function to apply Landsat 8-9 DN scaling factors
def apply_landsat8_9_scale(image):
    optical_bands = image.select('SR_B.')
    optical_bands = optical_bands.updateMask(optical_bands.lte(65455))
    optical_bands = optical_bands.multiply(0.0000275).add(-0.2)
    return image.addBands(optical_bands, None, True)


# function to calculate NIR/SWIR Ratio of Landsat 4-7
def add_landsat4_5_7_nsir(image):
    band_nir = image.select('SR_B4')
    band_swr = image.select('SR_B7')
    band_new = band_nir.multiply(band_nir.divide(band_swr))
    return image.addBands(band_new.rename('NSIR'))


# function to calculate NIR/SWIR Ratio of Landsat 8-9
def add_landsat8_9_nsir(image):
    band_nir = image.select('SR_B5')
    band_swr = image.select('SR_B7')
    band_new = band_nir.multiply(band_nir.divide(band_swr))
    return image.addBands(band_new.rename('NSIR'))


# function to calculate NDWI of Landsat 4-7
def add_landsat4_5_7_ndwi(image):
    band_new = image.normalizedDifference(['SR_B2', 'SR_B4'])
    return image.addBands(band_new.rename('NDWI'))


# function to calculate NDWI of Landsat 8-9
def add_landsat8_9_ndwi(image):
    band_new = image.normalizedDifference(['SR_B3', 'SR_B5'])
    return image.addBands(band_new.rename('NDWI'))


# function to calculate NDSI of Landsat 4-7
def add_landsat4_5_7_ndsi(image):
    band_new = image.normalizedDifference(['SR_B2', 'SR_B7'])
    return image.addBands(band_new.rename('NDSI'))


# function to calculate NDSI of Landsat 8-9
def add_landsat8_9_ndsi(image):
    band_new = image.normalizedDifference(['SR_B3', 'SR_B7'])
    return image.addBands(band_new.rename('NDSI'))

########################################################################################################################
########################################################################################################################



# Main functions section ###############################################################################################
########################################################################################################################

# function to list all satellite image ids of ImageCollection
def collect_image_id(image):
    return ee.Feature(image.geometry(), {
        'system:id': image.get('system:id'),
        'system:time_start': image.get('system:time_start')
    })


# function to preserve satellite platform ID
def satellite_name(image):
    sat_id = ee.String(image.get('system:id')).split('/').get(1)
    return image.set(
        'system:sat', sat_id
    )


# function to select resampling approach (default is nearest neighbor)
def resample_bilin(image):
    image = image.resample('bilinear')
    return image


# function to estimate static terrain shadow mask from multi-looking
def terrain_shadow(elevation, azimuth_min, azimuth_max, zenith_mean):
    # create list of potential azimuth angles (in 5deg steps between min/max azimuth)
    solar_azimuth_list = ee.List.sequence(ee.Number(azimuth_min), ee.Number(azimuth_max).add(5), 5)

    # calculate shaded image areas for each provided illumination direction
    def shaded_terrain(solar_azimuth):  # calculate terrain shadow from DEM, azimuth and zenith angles
        return ee.Terrain.hillShadow(
            image=elevation,
            azimuth=solar_azimuth,
            zenith=zenith_mean,
            neighborhoodSize=200,
            hysteresis=False).rename('SHD')

    shaded_terrain_images = solar_azimuth_list.map(shaded_terrain, dropNulls=True)

    # merge into multi-direction-viewing shade masks
    shaded_terrain_mask = ee.ImageCollection.fromImages(shaded_terrain_images).min() # merge multi terrain masks
    shaded_terrain_mask = shaded_terrain_mask.focalMin(radius=60, units='meters') # apply slight buffer to terrain mask
    shaded_terrain_mask = shaded_terrain_mask.eq(1).selfMask()
    return shaded_terrain_mask


# twin-function to mosaic image acquisitions of same day
def mosaic_by_date(imcol):
    imlist = imcol.toList(imcol.size())
    unique_dates = imlist.map(lambda im: ee.Image(im).date().format("YYYY-MM-dd")).distinct()  # get unique image dates
    mosaic_imlist = unique_dates.map(lambda d: create_mosaic(d, imcol))  # Create a list of mosaics for each unique date
    return ee.ImageCollection(mosaic_imlist)  # Return the final ImageCollection

def create_mosaic(date, imcol):
    date = ee.Date(date)
    # Filter the collection by the specific date and create a mosaic
    mosaic_image = imcol.filterDate(date, date.advance(1, "day")).mosaic()
    # Set properties for the mosaic image
    return mosaic_image.set(
        'system:time_start', date.millis(),
        'system:date_start', date.format('YYYY-MM-dd'),
        'system:sat_origin', imcol.first().get('system:sat')
    )


# function to apply NDSI mask
def mask_ndsi(image):
    ndsi = image.select('NDSI')
    ndsi_mask = ndsi.gte(0.7).And(ndsi.lte(2)) # create NDSI mask
    nsir_masked = image.select('NSIR').updateMask(ndsi_mask) # apply mask
    ndwi_masked = image.select('NDWI').updateMask(ndsi_mask) # apply mask
    return image.addBands(nsir_masked.rename('NSIR_masked')).addBands(ndwi_masked.rename('NDWI_masked'))


# function to convert all Images of ImageCollection to datatype Float32
def convert_float32(image):
    return image.toFloat()


# function to mask brightness values which are most likely not snow/ice
def remove_extremes(image):
    ndwi = image.select('NDWI_masked')
    ndwi_rcl = ndwi.updateMask(ndwi.gte(-1).And(ndwi.lte(1)))
    nsir = image.select('NSIR_masked')
    nsir_rcl = nsir.updateMask(nsir.gte(0.4).And(nsir.lte(122)))
    return image.addBands(ndwi_rcl, overwrite=True).addBands(nsir_rcl, overwrite=True)


# function for vertical binning of DEM
def elevation_binning(image, width):
    image_binned = image.expression(
        'floor(DEM / bin) * bin', {'DEM': image, 'bin': width}
    ).rename('BIN')
    return image_binned


# function to retrieve image properties
def properties_to_feature(image):
    return ee.Feature(None, {
        'time_start': image.get('system:time_start'),
        'sat_origin': image.get('system:sat_origin')
    })

########################################################################################################################
########################################################################################################################



# Threshold functions section ##########################################################################################
########################################################################################################################

### OTSU function for NSIR raster
def otsu_ratio(histogram, image):
    counts = ee.Array(ee.Dictionary(histogram).get('histogram'))
    means = ee.Array(ee.Dictionary(histogram).get('bucketMeans'))
    size = means.length().get([0])
    total = counts.reduce(ee.Reducer.sum(), [0]).get([0])
    sum_total = means.multiply(counts).reduce(ee.Reducer.sum(), [0]).get([0])
    mean = sum_total.divide(total)

    indices = ee.List.sequence(1, size)

    def compute_bss(i):
        i = ee.Number(i)
        a_counts = counts.slice(0, 0, i)
        a_count = a_counts.reduce(ee.Reducer.sum(), [0]).get([0])
        a_means = means.slice(0, 0, i)
        a_mean = a_means.multiply(a_counts).reduce(ee.Reducer.sum(), [0]).get([0]).divide(a_count)

        b_count = total.subtract(a_count)
        b_mean = sum_total.subtract(a_count.multiply(a_mean)).divide(b_count)

        return a_count.multiply(a_mean.subtract(mean).pow(2)).add(b_count.multiply(b_mean.subtract(mean).pow(2)))

    bss = indices.map(compute_bss)

    # Return the mean value corresponding to the maximum BSS
    otsu_th = means.sort(bss).get([-1])

    update_image = image.where(image.lt(otsu_th), 0).where(image.gte(otsu_th), 1)
    update_image = update_image.rename(['SUBMASK'])
    update_image = update_image.copyProperties(image, properties=['system:time_start', 'system:date_start',
                                                                          'system:sat_origin'])

    return update_image.set('system:nsir_th', otsu_th)


# function to calculate Bhattacharyya distance from input
def bhatt_distance(mean_1, mean_2, variance_1, variance_2):
    mean_diff = mean_1.subtract(mean_2)
    term1 = (variance_2.divide(variance_1).add(variance_1.divide(variance_2)).add(2)).multiply(0.25).log().multiply(
        0.25)
    term2 = mean_diff.pow(2).divide(variance_2.add(variance_1)).multiply(0.25)
    return term1.add(term2)


# function to calculate elevation change correction factor, input is dhdt raster (m/a) and time difference (float years)
def elevation_correction(image, image_elevation, aoi_elevation, dhdt_map, date_difference):
    # mask snow line elevation bin (with some additional vertical buffer for small bins)
    masked_elevation = image_elevation.updateMask(image_elevation.gte(ee.Number(aoi_elevation).subtract(10)).And(image_elevation.lte(ee.Number(aoi_elevation).add(10))))

    # mask change map to target bin and calculate mean dhdt of target bin
    change_bin = dhdt_map.updateMask(masked_elevation)
    mean_change_bin = change_bin.reduceRegion(
        reducer=ee.Reducer.mean(),
        geometry=image.geometry(),
        scale=100, # dhdt maps have 100 m spatial resolution
        maxPixels=1e13
    ).get('DHDT')
    mean_change_bin = ee.Number(mean_change_bin)

    # check if a meaningful value was returned
    valid_change = ee.Algorithms.IsEqual(mean_change_bin, None)
    mean_change_bin = ee.Algorithms.If(valid_change, None, mean_change_bin.multiply(date_difference))

    return mean_change_bin

########################################################################################################################
########################################################################################################################





# Export functions section #############################################################################################
########################################################################################################################

# function to create raster snow mask based on snow line elevation value
def create_shape(image, elevation, snow_line_elevation):
    # clip DEM to image geometry and mask to snow line elevation
    elevation_mask = elevation.clip(image.geometry())
    elevation_mask = elevation_mask.gte(ee.Number(snow_line_elevation))

    # create image with all cells = 1 using original image geometry
    shape_mask = image.unmask(1).multiply(0).add(1)

    # mask created image with elevation mask
    shape_mask = shape_mask.updateMask(elevation_mask)
    shape_mask = shape_mask.copyProperties(image) # append image meta data again

    return shape_mask


# function to reshape raster snow mask collections to multi-band export files
def rename_as_bands(image):
    # get snow mask properties
    time_start = ee.String(image.get('time_start')) # image acquisition
    date_start = ee.Date(image.get('time_start')).format('YYYYMMdd') # image acquisition
    sat_id = ee.String(image.get('sat_origin')) # acquiring satellite

    new_name = time_start.cat(ee.String('_')).cat(date_start).cat(ee.String('_')).cat(sat_id) # new band name

    return image.rename(new_name)

########################################################################################################################
########################################################################################################################


print('... Passed')