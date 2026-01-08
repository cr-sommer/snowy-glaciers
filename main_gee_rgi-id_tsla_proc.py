### Header file >>> satellite data load and tsla estimate
### glacier selection by RGI-IDs


# USER INPUT REQUIRED:
# L.35: project_id -> Name of USER cloud project (https://developers.google.com/earth-engine/guides/access?hl=de)
# L.36: service_account -> Name of USER service account (https://developers.google.com/earth-engine/guides/service_account?hl=de)
# L.37: key_path -> local path to USER json-key
# L.46-47: specify names for processing and output (any name can be used but NO capital letters allowed)
# L.50: select RGI-IDs you want to process (IDs must be RGI7.0 format !)
# L.53-59: OPTIONAL - select survey periods, satellite image parameters
# L.66-68: OPTIONAL - turn on/off reflectance filters
# L.72-75: OPTIONAL - change results export settings
# ...
# ...


### system environment
#import sys
import ee
#import geetools
from google.cloud import storage
from google.cloud.storage.constants import PUBLIC_ACCESS_PREVENTION_ENFORCED
from datetime import datetime

### source main functions LIB
import functions

### source satellite mission periods LIB
import satellites


### global project variables
print('... Initialize Earth Engine Service Account')
project_id = 'ndsi-scaf' # this is the main name of the project (set by USER)
service_account = 'ndsi-scaf@ndsi-scaf.iam.gserviceaccount.com' # insert service account of USER
key_path = '/home/qo78vomo/storage/ee_snow_lines/ndsi-scaf-cba8190d8371.json' # insert earth engine json key of USER
print(project_id)
print(key_path)
credentials = ee.ServiceAccountCredentials(service_account, key_path)
ee.Initialize(credentials = credentials, project = project_id) # start earth engine link


### region and time-series processing variables
print('... Load Processing Variables')
region_ID = '11_ceu' # Name of processing region (e.g. String ID of RGI region)
bucket_ID = 'output_' + region_ID # Name of output bucket in gcs (will be created if not available)

# select RGI-IDs you want to process
RGI_IDs = ['RGI2000-v7.0-G-11-00757', 'RGI2000-v7.0-G-11-02596', 'RGI2000-v7.0-G-11-03664']

# select satellite data to process
START_DATE = '1982-01-01' # START time-series; date format = 'YYYY-MM-DD'
END_DATE = '2025-12-31' # END time-series; date format = 'YYYY-MM-DD'
MIN_MONTH = 4 # Earliest month to apply processing (=1 for full year), NOTE: given value is INCLUDED in selection
MAX_MONTH = 11 # Latest month to apply processing (=12 for full year), NOTE: given value is INCLUDED in selection
MAX_CLOUD_COVER = 75 # Landsat4-9 / Sentinel-2 maximum allowed cloud cover fraction (%) per image (higher number = more images)
EXPORT_RESOLUTION = 60 # approximate export resolution in meters at CRS ORIGIN, ONLY RELEVANT IF export_images=1
EXPORT_PROJECTION = 'EPSG:3857' # respective CRS ORIGIN, ONLY RELEVANT IF export_images=1

print(region_ID)
print('time-series of', START_DATE, 'and', END_DATE, 'with month range from', MIN_MONTH, 'to', MAX_MONTH)


# filter settings (should be all =1)
mask_snowy_cells = 1 # remove pixels which are neither snow nor ice =1
mask_terrain_shadow = 1 # calculate and delete shaded terrain pixels based on DEM ? =1
regional_minmax = 1 # mask brightness to valid value margins =1


# data export settings (export_results=1 should be always selected to retrieve TSLA + quality statistics)
export_results = 1 # export snow line elevations as tabular (csv) output >>> all numeric statistics, MAIN OUTPUT
export_shapes = 0 # export snow line elevations as raster masks (= area above TSLA)
export_DEM = 0 # OPTIONAL - export DEM and DHDT raster ?
export_meta = 1 # OPTIONAL - export all meta data ?


### (!) NO CHANGES BELOW (!) ###


########################################################################################################################
########################################################################################################################
###### (0) CREATE PROCESSING ENVIRONMENT
########################################################################################################################
########################################################################################################################
print('(0) CREATE SNOW LINE PROCESSING ENVIRONMENT')

## load glacier geometries from RGI collection
print('... selecting AOI glacier geometries', RGI_IDs)
# https://gee-community-catalog.org/projects/rgi/
glacier_aoi = ee.FeatureCollection("projects/sat-io/open-datasets/RGI/RGI_VECTOR_MERGED_V7") # load RGI

assets_aoi = glacier_aoi.filter(ee.Filter.inList('rgi_id', RGI_IDs)) # select by rgi_id attribute
assets_aoi_count = assets_aoi.size().getInfo()

print("... Input Geometry Count =", assets_aoi_count)
assets_aoi_area = assets_aoi \
    .map(lambda feature: feature.set('area', feature.geometry().area())) \
    .reduceColumns(ee.Reducer.sum(), ['area']) \
    .get('sum') \
    .getInfo()
print("... Input Geometry Area =", assets_aoi_area / 1000000, 'sqkm')

print(assets_aoi.first().propertyNames().getInfo()) # geometry attribute table

# check if all IDs were found
rgi_ids_found = assets_aoi.aggregate_array('rgi_id')
print('... Input Geometry Names Valid:', rgi_ids_found.getInfo())


## check if cloud storage output bucket exists (! existing buckets are deleted !)
storage_client = storage.Client.from_service_account_json(key_path)

if storage_client.bucket(bucket_ID).exists():
    print('... Overwrite Cloud Storage Bucket =', bucket_ID)

    # delete all contents and then bucket
    bucket = storage_client.bucket(bucket_ID)
    blobs = storage_client.list_blobs(bucket_ID)
    for blob in blobs:
        print(f"Deleting {blob.name}")
        blob.delete()
    bucket.delete() # delete existing old bucket !

print('... Create Cloud Storage Bucket =', bucket_ID)

# create new bucket in cloud storage
bucket = storage_client.bucket(bucket_ID)
bucket.storage_class = "STANDARD"
bucket.retention_period = None
bucket.soft_delete_policy.retention_duration_seconds = None
bucket.iam_configuration.public_access_prevention = (
    PUBLIC_ACCESS_PREVENTION_ENFORCED
)
new_bucket = storage_client.create_bucket(bucket, location="us")
print(f'... >>> Bucket {bucket_ID} Created Successfully')

# optional - export grid processing meta files ?
if export_meta == 1:

    # export feature outlines
    task = ee.batch.Export.table.toCloudStorage(
        collection=assets_aoi,
        description='export_AOI-outline',
        bucket=bucket_ID,
        fileNamePrefix='aoi_outline',
        fileFormat='KML'
    ).start()

    # export time-series properties
    lut_timeseries = ee.Feature(None, {
        'start_date': START_DATE,
        'end_date': END_DATE,
        'cloud_threshold': MAX_CLOUD_COVER,
        'image_resolution': EXPORT_RESOLUTION,
        'image_projection': EXPORT_PROJECTION
    })

    task = ee.batch.Export.table.toCloudStorage(
        collection=ee.FeatureCollection([lut_timeseries]),
        description='export_PARAMS-meta',
        bucket=bucket_ID,
        fileNamePrefix='meta_TIMESERIES',
        fileFormat='CSV',
        selectors=['start_date', 'end_date', 'cloud_threshold', 'image_resolution', 'image_projection']
    ).start()

print('(0) CREATE SNOW LINE PROCESSING ENVIRONMENT ... PASSED')
########################################################################################################################
########################################################################################################################
########################################################################################################################





########################################################################################################################
########################################################################################################################
###### (1) READ REFERENCE SURFACE ELEVATION DATA [DEM]
########################################################################################################################
########################################################################################################################
print('(1) READ REFERENCE SURFACE ELEVATION DATA [DEM]')

## load surface elevation >>> NASADEM
# https://developers.google.com/earth-engine/datasets/catalog/NASA_NASADEM_HGT_001?hl=de
print('... Surface Elevation [DEM]')
dem_date = ee.Date('2000-02-16') # median date of SRTM
dem = ee.Image('NASA/NASADEM_HGT/001').select('elevation')
dem = dem.resample('bilinear')
dem = dem.toFloat().rename('DEM')

# apply waterbody mask >>> NASADEM
print('... Waterbody Mask [DEM]')
wbm = ee.Image('NASA/NASADEM_HGT/001').select('swb')
wbm = wbm.toFloat().rename('WBM')
dem = dem.updateMask(wbm.eq(0))  # remove water pixels

## create binned elevation from DEM (this is used to estimate raw snow line elevation)
print('... Create Binned Elevation [DEM]')
bin_size = 10 # vertical binning distance
dem_bin = functions.elevation_binning(dem, bin_size)

# clip to glaciers
dem = dem.clip(assets_aoi) # this masks full raster to exact polygons of asset
dem_bin = dem_bin.clip(assets_aoi) # this masks full raster to exact polygons of asset

## load glacier change rate map of Hugonnet et al. >>> dh/dt correction factor
print('... Surface elevation change [DHDT]')
# https://gee-community-catalog.org/projects/glacier/#citation
dhdt = ee.ImageCollection("projects/sat-io/open-datasets/GLOBAL-GLACIER-MASS-LOSS/elevation-change")
dhdt = dhdt.filter(ee.Filter.eq('time_period', '0020')).filterBounds(assets_aoi.geometry()) # select 20 yrs elevation change rates
dhdt = dhdt.map(functions.resample_bilin)
dhdt = dhdt.mosaic().rename('DHDT').set('system:id', dhdt.get('system:id')) # mosaic dhdt maps
dhdt = dhdt.clip(assets_aoi) # clip to glaciers

## optional - export lookup table of elevation data
if export_meta == 1:

    lut_elevation = ee.Feature(None, {
        'DEM_name': dem.get('system:id'),
        'DEM_date': dem_date.format('YYYY-MM-dd'),
        'DEM_bin_m': bin_size,
        'DHDT_name' : dhdt.get('system:id')
    })

    task = ee.batch.Export.table.toCloudStorage(
        collection=ee.FeatureCollection([lut_elevation]),
        description='export_DEM-meta',
        bucket=bucket_ID,
        fileNamePrefix='meta_DEM',
        fileFormat='CSV',
        selectors=['DEM_name', 'DEM_date', 'DEM_bin_m', 'DHDT_name']
    ).start()

# optional - export region elevation raster of [DEM] and [DHDT]
if export_DEM == 1:
    print('... Export Surface Elevation Maps')

    # elevation of DEM
    exp_name = 'ref_elv_DEM_' + region_ID
    print(f"Exporting image: {exp_name}")
    task = ee.batch.Export.image.toCloudStorage(
        image=dem,
        description='export_DEM-map',
        bucket=bucket_ID,
        fileNamePrefix=exp_name,
        region=assets_aoi.geometry(),
        scale=EXPORT_RESOLUTION,
        crs=EXPORT_PROJECTION,
        maxPixels=1e13,
        fileFormat='GeoTIFF'
    ).start()

    # binned elevation of DEM
    exp_name = 'ref_elv_BIN_' + region_ID
    print(f"Exporting image: {exp_name}")
    task = ee.batch.Export.image.toCloudStorage(
        image=dem_bin,
        description='export_BIN-map',
        bucket=bucket_ID,
        fileNamePrefix=exp_name,
        region=assets_aoi.geometry().bounds(),
        scale=EXPORT_RESOLUTION,
        crs=EXPORT_PROJECTION,
        maxPixels=1e13,
        fileFormat='GeoTIFF'
    ).start()

    # glacier elevation change rates
    exp_name = 'ref_elv_DHDT_' + region_ID
    print(f"Exporting image: {exp_name}")
    task = ee.batch.Export.image.toCloudStorage(
        image=dhdt,
        description='export_DHDT-map',
        bucket=bucket_ID,
        fileNamePrefix=exp_name,
        region=assets_aoi.geometry(),
        scale=EXPORT_RESOLUTION,
        crs=EXPORT_PROJECTION,
        maxPixels=1e13,
        fileFormat='GeoTIFF'
    ).start()


## calculate glacier-specific elevation stats
print('... Calculate Geometry [Glacier] Elevation MinMax')

dem_stats = dem.reduceRegions( # glacier elevation MinMax range from DEM
    collection=assets_aoi,
    reducer=ee.Reducer.min().combine(
        reducer2=ee.Reducer.median(), sharedInputs=True).combine(
        reducer2=ee.Reducer.max(), sharedInputs=True),
    scale=30
).select(['rgi_id', 'min', 'median', 'max'])

task = ee.batch.Export.table.toCloudStorage(
    collection=dem_stats,
    description='export_DEM-stats',
    bucket=bucket_ID,
    fileNamePrefix='feature_elevation_DEM',
    fileFormat='CSV',
    selectors=['rgi_id', 'min', 'median', 'max']
).start()

print('(1) READ REFERENCE SURFACE ELEVATION DATA [DEM] ... PASSED')
########################################################################################################################
########################################################################################################################
########################################################################################################################





########################################################################################################################
########################################################################################################################
###### (2) LOAD OPTICAL SATELLITE DATA COLLECTIONS
########################################################################################################################
########################################################################################################################
print('(2) LOAD OPTICAL SATELLITE IMAGES')

## create lists to store satellite viewing geometry (only used if mask_terrain_shadow==1 )
if mask_terrain_shadow == 1:
    solar_zenith_list = ee.List([]) # create empty list for solar zenith angles
    solar_azimuth_list = ee.List([]) # create empty list for solar azimuth angles


########################## SENTINEL-2 section
if datetime.strptime(START_DATE, '%Y-%m-%d') <= satellites.sentinel2_last and datetime.strptime(END_DATE, '%Y-%m-%d') >= satellites.sentinel2_first:

    print('Sentinel-2 BOA Level-1C, Harmonized')
    # https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2_SR_HARMONIZED
    sat_image_s2 = (
        ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
        .select(['B3', 'B8', 'B12', 'QA60'])
        .filterBounds(assets_aoi.geometry())
        .filterDate(ee.Date(START_DATE), ee.Date(END_DATE))
        .filter(ee.Filter.calendarRange(MIN_MONTH, MAX_MONTH, 'month'))
        .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', MAX_CLOUD_COVER))
        .map(functions.apply_sentinel2_scale)
    )

    # optional - retrieve solar angles for shaded terrain mask creation
    if mask_terrain_shadow == 1:
        print('... Read Sensor Viewing Geometry')
        zenith_mean_s2 = ee.Number(sat_image_s2.aggregate_mean('MEAN_SOLAR_ZENITH_ANGLE'))
        azimuth_min_s2 = ee.Number(sat_image_s2.aggregate_min('MEAN_SOLAR_AZIMUTH_ANGLE'))
        azimuth_max_s2 = ee.Number(sat_image_s2.aggregate_max('MEAN_SOLAR_AZIMUTH_ANGLE'))
        solar_zenith_list = solar_zenith_list.add(zenith_mean_s2)
        solar_azimuth_list = solar_azimuth_list.add(azimuth_min_s2).add(azimuth_max_s2)

    # optional - export all sat image names and footprints ?
    if export_meta == 1:
        sat_names_s2 = sat_image_s2.map(functions.collect_image_id)

        task = ee.batch.Export.table.toCloudStorage(
            collection=sat_names_s2,
            description='export_IMAGE-ids',
            bucket=bucket_ID,
            fileNamePrefix='image_list_S2',
            fileFormat='KML',
            selectors=['system:time_start', 'system:id']
        ).start()

    # add satellite ID to image properties
    sat_image_s2 = sat_image_s2.map(functions.satellite_name)

    # NSIR band ratio
    sat_image_s2 = sat_image_s2.map(functions.add_s2_nsir)

    # NDWI band ratio
    sat_image_s2 = sat_image_s2.map(functions.add_s2_ndwi)

    # NDSI band ratio and masking
    sat_image_s2 = sat_image_s2.map(functions.add_s2_ndsi)
    sat_image_s2 = sat_image_s2.map(functions.mask_ndsi)

    # mosaic NSIR, NDWI per day
    print('... Mosaic By Date')
    sat_image_s2 = ee.ImageCollection(
        sat_image_s2.select(['NSIR_masked', 'NDWI_masked'], ['NSIR_masked', 'NDWI_masked'])
    ) # select bands
    sat_image_s2 = sat_image_s2.map(functions.resample_bilin) # set resampling method flag
    sat_image_s2 = functions.mosaic_by_date(sat_image_s2) # create image mosaic per day
    count_s2 = sat_image_s2.size() # count number of days

else:

    sat_image_s2 = ee.ImageCollection([]) # empty collection if time series outside satellite mission period
    count_s2 = sat_image_s2.size() # empty count


########################## LANDSAT-4 section
if datetime.strptime(START_DATE, '%Y-%m-%d') <= satellites.landsat4_last and datetime.strptime(END_DATE, '%Y-%m-%d') >= satellites.landsat4_first:

    print('Landsat-4 BOA Level2, Collection2, Tier1')
    # https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LT04_C02_T1_L2?hl=de
    sat_image_l4 = (
        ee.ImageCollection('LANDSAT/LT04/C02/T1_L2')
        .filterBounds(assets_aoi.geometry())
        .filterDate(ee.Date(START_DATE), ee.Date(END_DATE))
        .filter(ee.Filter.calendarRange(MIN_MONTH, MAX_MONTH, 'month'))
        .filter(ee.Filter.lt('CLOUD_COVER', MAX_CLOUD_COVER))
        .map(functions.apply_landsat4_5_7_scale)
    )

    # optional - retrieve solar angles for shaded terrain mask creation
    if mask_terrain_shadow == 1:
        print('... Read Sensor Viewing Geometry')
        zenith_mean_l4 = ee.Number(sat_image_l4.aggregate_mean('SUN_ELEVATION'))
        azimuth_min_l4 = ee.Number(sat_image_l4.aggregate_min('SUN_AZIMUTH'))
        azimuth_max_l4 = ee.Number(sat_image_l4.aggregate_max('SUN_AZIMUTH'))
        solar_zenith_list = solar_zenith_list.add(zenith_mean_l4)
        solar_azimuth_list = solar_azimuth_list.add(azimuth_min_l4).add(azimuth_max_l4)


    # optional - export all sat image names and footprints ?
    if export_meta == 1:
        sat_names_l4 = sat_image_l4.map(functions.collect_image_id)

        task = ee.batch.Export.table.toCloudStorage(
            collection=sat_names_l4,
            description='export_IMAGE-ids',
            bucket=bucket_ID,
            fileNamePrefix='image_list_LT04',
            fileFormat='KML',
            selectors=['system:time_start', 'system:id']
        ).start()

    # add satellite ID to image properties
    sat_image_l4 = sat_image_l4.map(functions.satellite_name)

    # NSIR band ratio
    sat_image_l4 = sat_image_l4.map(functions.add_landsat4_5_7_nsir)

    # NDWI band ratio
    sat_image_l4 = sat_image_l4.map(functions.add_landsat4_5_7_ndwi)

    # NDSI band ratio and masking
    sat_image_l4 = sat_image_l4.map(functions.add_landsat4_5_7_ndsi)
    sat_image_l4 = sat_image_l4.map(functions.mask_ndsi)

    # mosaic NSIR, NDWI per day
    print('... Mosaic By Date')
    sat_image_l4 = ee.ImageCollection(
        sat_image_l4.select(['NSIR_masked', 'NDWI_masked'], ['NSIR_masked', 'NDWI_masked'])
    ) # select bands
    sat_image_l4 = sat_image_l4.map(functions.resample_bilin)  # set resampling method flag
    sat_image_l4 = functions.mosaic_by_date(sat_image_l4) # create image mosaic per day
    count_l4 = sat_image_l4.size() # count number of days

else:

    sat_image_l4 = ee.ImageCollection([]) # empty collection if time series outside satellite mission period
    count_l4 = sat_image_l4.size() # empty count


########################## LANDSAT-5 section
if datetime.strptime(START_DATE, '%Y-%m-%d') <= satellites.landsat5_last and datetime.strptime(END_DATE, '%Y-%m-%d') >= satellites.landsat5_first:

    print('Landsat-5 BOA Level2, Collection2, Tier1')
    # https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LT05_C02_T1_L2?hl=de
    sat_image_l5 = (
        ee.ImageCollection('LANDSAT/LT05/C02/T1_L2')
        .select(['SR_B2', 'SR_B4', 'SR_B7', 'QA_PIXEL', 'QA_RADSAT'])
        .filterBounds(assets_aoi.geometry())
        .filterDate(ee.Date(START_DATE), ee.Date(END_DATE))
        .filter(ee.Filter.calendarRange(MIN_MONTH, MAX_MONTH, 'month'))
        .filter(ee.Filter.lt('CLOUD_COVER', MAX_CLOUD_COVER))
        .map(functions.apply_landsat4_5_7_scale)
    )

    # optional - retrieve solar angles for shaded terrain mask creation
    if mask_terrain_shadow == 1:
        print('... Read Sensor Viewing Geometry')
        zenith_mean_l5 = ee.Number(sat_image_l5.aggregate_mean('SUN_ELEVATION'))
        azimuth_min_l5 = ee.Number(sat_image_l5.aggregate_min('SUN_AZIMUTH'))
        azimuth_max_l5 = ee.Number(sat_image_l5.aggregate_max('SUN_AZIMUTH'))
        solar_zenith_list = solar_zenith_list.add(zenith_mean_l5)
        solar_azimuth_list = solar_azimuth_list.add(azimuth_min_l5).add(azimuth_max_l5)

    # optional - export all sat image names and footprints ?
    if export_meta == 1:
        sat_names_l5 = sat_image_l5.map(functions.collect_image_id)

        task = ee.batch.Export.table.toCloudStorage(
            collection=sat_names_l5,
            description='export_IMAGE-ids',
            bucket=bucket_ID,
            fileNamePrefix='image_list_LT05',
            fileFormat='KML',
            selectors=['system:time_start', 'system:id']
        ).start()

    # add satellite ID to image properties
    sat_image_l5 = sat_image_l5.map(functions.satellite_name)

    # NSIR band ratio
    sat_image_l5 = sat_image_l5.map(functions.add_landsat4_5_7_nsir)

    # NDWI band ratio
    sat_image_l5 = sat_image_l5.map(functions.add_landsat4_5_7_ndwi)

    # NDSI band ratio and masking
    sat_image_l5 = sat_image_l5.map(functions.add_landsat4_5_7_ndsi)
    sat_image_l5 = sat_image_l5.map(functions.mask_ndsi)

    # mosaic NSIR, NDWI per day
    print('... Mosaic By Date')
    sat_image_l5 = ee.ImageCollection(
        sat_image_l5.select(['NSIR_masked', 'NDWI_masked'], ['NSIR_masked', 'NDWI_masked'])
    ) # select bands
    sat_image_l5 = sat_image_l5.map(functions.resample_bilin)  # set resampling method flag
    sat_image_l5 = functions.mosaic_by_date(sat_image_l5) # create image mosaic per day
    count_l5 = sat_image_l5.size() # count number of days

else:

    sat_image_l5 = ee.ImageCollection([]) # empty collection if time series outside satellite mission period
    count_l5 = sat_image_l5.size() # empty count


########################## LANDSAT-7 section
if datetime.strptime(START_DATE, '%Y-%m-%d') <= satellites.landsat7_last and datetime.strptime(END_DATE, '%Y-%m-%d') >= satellites.landsat7_first:

    print('Landsat-7 BOA Level2, Collection2, Tier1')
    # https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LE07_C02_T1_L2
    sat_image_l7 = (
        ee.ImageCollection('LANDSAT/LE07/C02/T1_L2')
        .select(['SR_B2', 'SR_B4', 'SR_B7', 'QA_PIXEL', 'QA_RADSAT'])
        .filterBounds(assets_aoi.geometry())
        .filterDate(ee.Date(START_DATE), ee.Date(END_DATE))
        .filter(ee.Filter.calendarRange(MIN_MONTH, MAX_MONTH, 'month'))
        .filter(ee.Filter.lt('CLOUD_COVER', MAX_CLOUD_COVER))
        .map(functions.apply_landsat4_5_7_scale)
    )

    # optional - retrieve solar angles for shaded terrain mask creation
    if mask_terrain_shadow == 1:
        print('... Read Sensor Viewing Geometry')
        zenith_mean_l7 = ee.Number(sat_image_l7.aggregate_mean('SUN_ELEVATION'))
        azimuth_min_l7 = ee.Number(sat_image_l7.aggregate_min('SUN_AZIMUTH'))
        azimuth_max_l7 = ee.Number(sat_image_l7.aggregate_max('SUN_AZIMUTH'))
        solar_zenith_list = solar_zenith_list.add(zenith_mean_l7)
        solar_azimuth_list = solar_azimuth_list.add(azimuth_min_l7).add(azimuth_max_l7)

    # optional - export all sat image names and footprints ?
    if export_meta == 1:
        sat_names_l7 = sat_image_l7.map(functions.collect_image_id)

        task = ee.batch.Export.table.toCloudStorage(
            collection=sat_names_l7,
            description='export_IMAGE-ids',
            bucket=bucket_ID,
            fileNamePrefix='image_list_LE07',
            fileFormat='KML',
            selectors=['system:time_start', 'system:id']
        ).start()

    # add satellite ID to image properties
    sat_image_l7 = sat_image_l7.map(functions.satellite_name)

    # NSIR band ratio
    sat_image_l7 = sat_image_l7.map(functions.add_landsat4_5_7_nsir)

    # NDWI band ratio
    sat_image_l7 = sat_image_l7.map(functions.add_landsat4_5_7_ndwi)

    # NDSI band ratio and masking
    sat_image_l7 = sat_image_l7.map(functions.add_landsat4_5_7_ndsi)
    sat_image_l7 = sat_image_l7.map(functions.mask_ndsi)

    # mosaic NSIR, NDWI per day
    print('... Mosaic By Date')
    sat_image_l7 = ee.ImageCollection(
        sat_image_l7.select(['NSIR_masked', 'NDWI_masked'], ['NSIR_masked', 'NDWI_masked'])
    ) # select bands
    sat_image_l7 = sat_image_l7.map(functions.resample_bilin)  # set resampling method flag
    sat_image_l7 = functions.mosaic_by_date(sat_image_l7) # create image mosaic per day
    count_l7 = sat_image_l7.size() # count number of days

else:

    sat_image_l7 = ee.ImageCollection([]) # empty collection if time series outside satellite mission period
    count_l7 = sat_image_l7.size() # empty count


########################## LANDSAT-8 section
if datetime.strptime(START_DATE, '%Y-%m-%d') <= satellites.landsat8_last and datetime.strptime(END_DATE, '%Y-%m-%d') >= satellites.landsat8_first:

    print('Landsat-8 BOA Level2, Collection2, Tier1')
    # https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LC08_C02_T1_L2
    sat_image_l8 = (
        ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
        .select(['SR_B3', 'SR_B5', 'SR_B7', 'QA_PIXEL', 'QA_RADSAT'])
        .filterBounds(assets_aoi.geometry())
        .filterDate(ee.Date(START_DATE), ee.Date(END_DATE))
        .filter(ee.Filter.calendarRange(MIN_MONTH, MAX_MONTH, 'month'))
        .filter(ee.Filter.lt('CLOUD_COVER', MAX_CLOUD_COVER))
        .map(functions.apply_landsat8_9_scale)
    )

    # optional - retrieve solar angles for shaded terrain mask creation
    if mask_terrain_shadow == 1:
        print('... Read Sensor Viewing Geometry')
        zenith_mean_l8 = ee.Number(sat_image_l8.aggregate_mean('SUN_ELEVATION'))
        azimuth_min_l8 = ee.Number(sat_image_l8.aggregate_min('SUN_AZIMUTH'))
        azimuth_max_l8 = ee.Number(sat_image_l8.aggregate_max('SUN_AZIMUTH'))
        solar_zenith_list = solar_zenith_list.add(zenith_mean_l8)
        solar_azimuth_list = solar_azimuth_list.add(azimuth_min_l8).add(azimuth_max_l8)

    # optional - export all sat image names and footprints ?
    if export_meta == 1:
        sat_names_l8 = sat_image_l8.map(functions.collect_image_id)

        task = ee.batch.Export.table.toCloudStorage(
            collection=sat_names_l8,
            description='export_IMAGE-ids',
            bucket=bucket_ID,
            fileNamePrefix='image_list_LC08',
            fileFormat='KML',
            selectors=['system:time_start', 'system:id']
        ).start()

    # add satellite ID to image properties
    sat_image_l8 = sat_image_l8.map(functions.satellite_name)

    # NSIR band ratio
    sat_image_l8 = sat_image_l8.map(functions.add_landsat8_9_nsir)

    # NDWI band ratio
    sat_image_l8 = sat_image_l8.map(functions.add_landsat8_9_ndwi)

    # NDSI band ratio and masking
    sat_image_l8 = sat_image_l8.map(functions.add_landsat8_9_ndsi)
    sat_image_l8 = sat_image_l8.map(functions.mask_ndsi)

    # mosaic NSIR, NDWI per day
    print('... Mosaic By Date')
    sat_image_l8 = ee.ImageCollection(
        sat_image_l8.select(['NSIR_masked', 'NDWI_masked'], ['NSIR_masked', 'NDWI_masked'])
    ) # select bands
    sat_image_l8 = sat_image_l8.map(functions.resample_bilin)  # set resampling method flag
    sat_image_l8 = functions.mosaic_by_date(sat_image_l8) # create image mosaic per day
    count_l8 = sat_image_l8.size() # count number of days

else:

    sat_image_l8 = ee.ImageCollection([]) # empty collection if time series outside satellite mission period
    count_l8 = sat_image_l8.size() # empty count


########################## LANDSAT-9 section
if datetime.strptime(START_DATE, '%Y-%m-%d') <= satellites.landsat9_last and datetime.strptime(END_DATE, '%Y-%m-%d') >= satellites.landsat9_first:

    print('Landsat-9 BOA Level2, Collection2, Tier1')
    # https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LC09_C02_T1_L2
    sat_image_l9 = (
        ee.ImageCollection('LANDSAT/LC09/C02/T1_L2')
        .select(['SR_B3', 'SR_B5', 'SR_B7', 'QA_PIXEL', 'QA_RADSAT'])
        .filterBounds(assets_aoi.geometry())
        .filterDate(ee.Date(START_DATE), ee.Date(END_DATE))
        .filter(ee.Filter.calendarRange(MIN_MONTH, MAX_MONTH, 'month'))
        .filter(ee.Filter.lt('CLOUD_COVER', MAX_CLOUD_COVER))
        .map(functions.apply_landsat8_9_scale)
    )

    # optional - retrieve solar angles for shaded terrain mask creation
    if mask_terrain_shadow == 1:
        print('... Read Sensor Viewing Geometry')
        zenith_mean_l9 = ee.Number(sat_image_l9.aggregate_mean('SUN_ELEVATION'))
        azimuth_min_l9 = ee.Number(sat_image_l9.aggregate_min('SUN_AZIMUTH'))
        azimuth_max_l9 = ee.Number(sat_image_l9.aggregate_max('SUN_AZIMUTH'))
        solar_zenith_list = solar_zenith_list.add(zenith_mean_l9)
        solar_azimuth_list = solar_azimuth_list.add(azimuth_min_l9).add(azimuth_max_l9)

    # optional - export all sat image names and footprints ?
    if export_meta == 1:
        sat_names_l9 = sat_image_l9.map(functions.collect_image_id)

        task = ee.batch.Export.table.toCloudStorage(
            collection=sat_names_l9,
            description='export_IMAGE-ids',
            bucket=bucket_ID,
            fileNamePrefix='image_list_LC09',
            fileFormat='KML',
            selectors=['system:time_start', 'system:id']
        ).start()

    # add satellite ID to image properties
    sat_image_l9 = sat_image_l9.map(functions.satellite_name)

    # NSIR band ratio
    sat_image_l9 = sat_image_l9.map(functions.add_landsat8_9_nsir)

    # NDWI band ratio
    sat_image_l9 = sat_image_l9.map(functions.add_landsat8_9_ndwi)

    # NDSI band ratio and masking
    sat_image_l9 = sat_image_l9.map(functions.add_landsat8_9_ndsi)
    sat_image_l9 = sat_image_l9.map(functions.mask_ndsi)

    # mosaic NSIR, NDWI per day
    print('... Mosaic By Date')
    sat_image_l9 = ee.ImageCollection(
        sat_image_l9.select(['NSIR_masked', 'NDWI_masked'], ['NSIR_masked', 'NDWI_masked'])
    )
    sat_image_l9 = sat_image_l9.map(functions.resample_bilin)  # set resampling method flag
    sat_image_l9 = functions.mosaic_by_date(sat_image_l9) # create image mosaic per day
    count_l9 = sat_image_l9.size() # count number of days

else:

    sat_image_l9 = ee.ImageCollection([]) # empty collection if time series outside satellite mission period
    count_l9 = sat_image_l9.size() # empty count

print('(2) LOAD OPTICAL SATELLITE IMAGES ... PASSED')
########################################################################################################################
########################################################################################################################
########################################################################################################################





########################################################################################################################
########################################################################################################################
###### (3) CREATE FILTERED SATELLITE IMAGE TIME SERIES
########################################################################################################################
########################################################################################################################
print('(3) CREATE FILTERED SATELLITE IMAGE TIME SERIES')

## merge image collections
print('... Combine Image Mosaics')
sat_image_mrg = sat_image_s2.merge(sat_image_l4).merge(sat_image_l5).merge(sat_image_l7).merge(sat_image_l8).merge(sat_image_l9)
sat_image_mrg = sat_image_mrg.sort('system:time_start') # sort by date

sat_image_mrg = sat_image_mrg.map(functions.convert_float32) # set datatype of all images > only relevant if raster data is exported

## merge image collection counts
print('... Combine Image Mosaic Counts')
sat_count_mrg = count_s2.add(count_l4).add(count_l5).add(count_l7).add(count_l8).add(count_l9)
#print(sat_count_mrg.getInfo())

## optional - export number of daily mosaics per satellite ?
if export_meta == 1:
    print('... Export Image Mosaic Summary')

    # image count per satellite
    sat_count_dict = ee.Dictionary({
        'S2_count': count_s2,
        'LT04_count': count_l4,
        'LT05_count': count_l5,
        'LE07_count': count_l7,
        'LC08_count': count_l8,
        'LC09_count': count_l9
    })
    feature = ee.Feature(None, sat_count_dict)

    task = ee.batch.Export.table.toCloudStorage(
        collection=ee.FeatureCollection([feature]),
        description='export_mosaic_count',
        bucket=bucket_ID,
        fileNamePrefix='mosaic_list',
        fileFormat='CSV',
        selectors=['LT04_count', 'LT05_count', 'LE07_count', 'LC08_count', 'LC09_count', 'S2_count']
    ).start()

    # mosaic properties: date & acquiring satellite
    sat_image_props = sat_image_mrg.map(functions.properties_to_feature)
    task = ee.batch.Export.table.toCloudStorage(
        collection=sat_image_props,
        description='export_mosaic_properties',
        bucket=bucket_ID,
        fileNamePrefix='mosaic_properties',
        fileFormat='CSV',
        selectors=['time_start', 'sat_origin']
    ).start()

## optional - mask terrain shaded pixels
if mask_terrain_shadow == 1:
    print('... Create Terrain Shadow Mask')

    # estimate global terrain shadow illumination
    solar_zenith_mean = solar_zenith_list.reduce(ee.Reducer.mean())
    solar_azimuth_min = solar_azimuth_list.reduce(ee.Reducer.min())
    solar_azimuth_max = solar_azimuth_list.reduce(ee.Reducer.max())

    # create static terrain shadow mask based on multi-looking
    shaded_terrain_mask = functions.terrain_shadow(elevation=dem, azimuth_min=solar_azimuth_min, azimuth_max=solar_azimuth_max, zenith_mean=solar_zenith_mean)

    # convert raster mask to feature mask
    print('... Update Valid Glacier Area With Terrain Shadow Mask')
    shaded_glacier_mask = shaded_terrain_mask.reduceToVectors(
        geometryType='polygon',
        reducer=ee.Reducer.countEvery(),
        scale=60,
        geometry=assets_aoi.geometry(), # mask glacier areas by terrain shadow
        maxPixels=1e13,
        tileScale=4
    )
    shaded_glacier_mask = shaded_glacier_mask.map(lambda f: f.simplify(60)) # reduce feature complexity
    sat_image_mrg = sat_image_mrg.map(lambda image: image.clipToCollection(shaded_glacier_mask))

## optional - estimate valid range of NSIR values
if regional_minmax == 1:
    print('... Constrain Valid Brightness Values Range')

    sat_image_mrg = sat_image_mrg.map(functions.remove_extremes) # mask NSIR and NDWI bands to valid range


print('(3) CREATE FILTERED SATELLITE IMAGE TIME SERIES ... PASSED')
########################################################################################################################
########################################################################################################################
########################################################################################################################





########################################################################################################################
########################################################################################################################
###### (4) CALCULATE IMAGE BRIGHTNESS THRESHOLDS PER GEOMETRY
########################################################################################################################
########################################################################################################################
print('(4) CALCULATE IMAGE BRIGHTNESS THRESHOLDS PER GEOMETRY')

# thresholding per glacier and per image
print('... Calculate Snow Line Thresholds')

def process_geometry(polygon):
    feature = ee.Feature(polygon) # extract target feature (=glacier) from inventory file
    feature_geometry = feature.geometry() # feature (=glacier) outline
    feature_area = feature.geometry().area() # total feature (=glacier) area

    def process_image(image):
        ## NSIR band thresholding (using OTSU threshold)
        full_image_nsir = image.select('NSIR_masked')
        crop_image_nsir = full_image_nsir.clip(feature_geometry)

        # get SDEV of NSIR band
        sdev_nsir = crop_image_nsir.reduceRegion(
            reducer=ee.Reducer.stdDev(),
            geometry=feature_geometry,
            scale=30,
            maxPixels=1e13
        ).get('NSIR_masked')

        # get Histogram of NSIR band
        hist_nsir = crop_image_nsir.reduceRegion(
            reducer=ee.Reducer.histogram(),
            geometry=feature_geometry,
            scale=30,
            maxPixels=1e13
        ).get('NSIR_masked')

        # image segmentation (using OTSU threshold)
        valid_hist_nsir = ee.Algorithms.IsEqual(hist_nsir, None)  # check if histogram reducer returns any values
        otsu_image_nsir = ee.Algorithms.If(valid_hist_nsir, crop_image_nsir.multiply(0), functions.otsu_ratio(hist_nsir, crop_image_nsir)) # enter OTSU estimation


        ## NDWI band thresholding (using FIXED threshold)
        full_image_ndwi = image.select('NDWI_masked')
        crop_image_ndwi = full_image_ndwi.clip(feature_geometry)

        # get SDEV of NDWI band
        sdev_ndwi = crop_image_ndwi.reduceRegion(
            reducer=ee.Reducer.stdDev(),
            geometry=feature_geometry,
            scale=30,
            maxPixels=1e13
        ).get('NDWI_masked')

        # ndwi constant threshold
        ndwi_th = ee.Number(0.1)
        mask_image_ndwi = crop_image_ndwi.where(crop_image_ndwi.lte(ndwi_th), 1).where(crop_image_ndwi.gte(ndwi_th), 0)
        mask_image_ndwi = mask_image_ndwi.rename(['SUBMASK'])
        mask_image_ndwi = mask_image_ndwi.copyProperties(full_image_ndwi, properties=['system:time_start', 'system:date_start', 'system:sat_origin'])
        mask_image_ndwi = mask_image_ndwi.set('system:ndwi_th', ndwi_th)

        ## merge image masks by pixelwise sums (0 = ice !, 1 = maybe snow ?, 2 = snow !)
        mask_image = ee.Image([otsu_image_nsir, mask_image_ndwi])
        mask_image = mask_image.reduce(ee.Reducer.sum()) # pixelwise sum
        mask_image = mask_image.rename(['MASK'])


        ## calculate Bhattacharyya distance between class division
        mask_ice = mask_image.lte(1) # ice mask
        mask_ice_nsir = crop_image_nsir.updateMask(mask_ice) # mask NSIR image to ice area
        stat_ice_nsir = mask_ice_nsir.reduceRegion(
            reducer=ee.Reducer.mean().combine(
                reducer2=ee.Reducer.variance(), sharedInputs=True),
            geometry=feature_geometry,
            scale=30,
            maxPixels=1e13
        )

        # NSIR mean of ice
        mean_ice_nsir = stat_ice_nsir.getNumber("NSIR_masked_mean")
        mean_ice_nsir = ee.Algorithms.If(ee.Algorithms.IsEqual(mean_ice_nsir, None), 0, mean_ice_nsir)
        mean_ice_nsir = ee.Number(mean_ice_nsir)

        # NSIR variance of ice
        variance_ice_nsir = stat_ice_nsir.getNumber("NSIR_masked_variance")
        variance_ice_nsir = ee.Algorithms.If(ee.Algorithms.IsEqual(variance_ice_nsir, None), 0, variance_ice_nsir)
        variance_ice_nsir = ee.Number(variance_ice_nsir)

        mask_snow = mask_image.eq(2) # snow mask
        mask_snow_nsir = crop_image_nsir.updateMask(mask_snow)  # mask NSIR image to snow area
        stat_snow_nsir = mask_snow_nsir.reduceRegion(
            reducer=ee.Reducer.mean().combine(
                reducer2=ee.Reducer.variance(), sharedInputs=True),
            geometry=feature_geometry,
            scale=30,
            maxPixels=1e13
        )

        # NSIR mean of snow
        mean_snow_nsir = stat_snow_nsir.getNumber("NSIR_masked_mean")
        mean_snow_nsir = ee.Algorithms.If(ee.Algorithms.IsEqual(mean_snow_nsir, None), 0, mean_snow_nsir)
        mean_snow_nsir = ee.Number(mean_snow_nsir)

        # NSIR variance of snow
        variance_snow_nsir = stat_snow_nsir.getNumber("NSIR_masked_variance")
        variance_snow_nsir = ee.Algorithms.If(ee.Algorithms.IsEqual(variance_snow_nsir, None), 0, variance_snow_nsir)
        variance_snow_nsir = ee.Number(variance_snow_nsir)

        # Bhattacharyya distance
        bhatt_distance_nsir = functions.bhatt_distance(mean_snow_nsir, mean_ice_nsir, variance_snow_nsir, variance_ice_nsir)

        ## append image statistics to binary mask
        mask_image = mask_image.set(
            'time_start', image.get('system:time_start'),
            'date_start', image.get('system:date_start'),
            'sat_origin', image.get('system:sat_origin'),
            'th_ndwi', ee.Image(mask_image_ndwi).get('system:ndwi_th'),
            'sd_ndwi', sdev_ndwi,
            'th_nsir', ee.Image(otsu_image_nsir).get('system:nsir_th'),
            'sd_nsir', sdev_nsir,
            'area_geometry', feature_area,
            #'system:variance_low', variance_ice_nsir,
            #'system:variance_above', variance_snow_nsir,
            #'system:mean_low', mean_ice_nsir,
            #'system:mean_above', mean_snow_nsir,
            'bhatt_dist', bhatt_distance_nsir
        )
        #return mask_image # activate to return ALL inputs from ALL dates (also empty entries)
        return ee.Algorithms.If(valid_hist_nsir, None, mask_image) # return only entries with actual data coverage


    # apply otsu processing across input image collection
    sat_image_otsu = sat_image_mrg.map(process_image, dropNulls=True)
    return sat_image_otsu

# split geometry featureCollection to single features (= glaciers)
geometry_list = assets_aoi.toList(assets_aoi.size())

# iterate thresholding for each geometry and each image
sat_image_mask = geometry_list.map(process_geometry, dropNulls=True)  # this returns list of imageCollection, each element is an imageCollection clipped to a geometry


## snow cover properties
print('... Calculate Snow Cover Properties')

def calculate_area_fraction(image_list):
    image_collection = ee.ImageCollection(image_list)

    def compute_fraction(image):
        # calculate area of all valid cells of full satellite image
        global_area = image.gte(0).multiply(ee.Image.pixelArea())
        global_area = global_area.reduceRegion(
            reducer=ee.Reducer.sum(),
            geometry=image.geometry(),
            scale=30,
            maxPixels=1e13,
            bestEffort=False
        ).getNumber('MASK')

        # calculate area of cells classified as snow BY OTSU THRESHOLD VALUE AND NDWI THRESHOLD VALUE
        snow_class_area = image.eq(2).multiply(ee.Image.pixelArea())
        snow_class_area = snow_class_area.reduceRegion(
            reducer=ee.Reducer.sum(),
            geometry=image.geometry(),
            scale=30,
            maxPixels=1e13,
            bestEffort=False
        ).getNumber('MASK')


        ## Calculate snow line altitude [NSIR & NDWI]
        image_mask_ones = image.eq(2) # value "2" refers to snow values
        masked_dem = dem_bin.updateMask(image_mask_ones)  # mask DEM to snow covered area

        # get lowest 10% percentile elevation of masked pixels => TSLA
        per_elevation = masked_dem.reduceRegion(
            reducer=ee.Reducer.percentile([10]),
            geometry=image.geometry(),
            scale=30,
            maxPixels=1e13,
            bestEffort=False
        ).get('BIN')
        per_elevation = ee.Number(per_elevation)


        ## estimate elevation change rate of snow line bin
        valid_elevation = ee.Algorithms.IsEqual(per_elevation, None) # check if there is a valid snow line elevation value
        image_mask_valid = image.gte(0)  # mask glacier area valid cells
        masked_dem_valid = dem_bin.updateMask(image_mask_valid) # DEM masked to all valid glacier cells

        image_date = ee.Date(image.get('time_start')) # get acquisition date of image of origin
        years_diff = image_date.difference(dem_date, 'year') # calculate time difference (decimal years) between DEM and image

        # estimate elevation correction factor (mean dhdt * years difference)
        mean_change = ee.Algorithms.If(valid_elevation,
                                       None,
                                       functions.elevation_correction(
                                           image=image,
                                           image_elevation=masked_dem_valid,
                                           aoi_elevation=per_elevation,
                                           dhdt_map=dhdt,
                                           date_difference=years_diff)
                                       )
        mean_change = ee.Number(mean_change)


        ## calculate corrected elevation value
        valid_correction = ee.Algorithms.IsEqual(mean_change, None)  # check if elevation correction factor is valid
        cor_elevation = ee.Algorithms.If(valid_elevation, per_elevation, ee.Algorithms.If(valid_correction, per_elevation, per_elevation.add(mean_change)))
        cor_elevation = ee.Number(cor_elevation)


        ## create snow cover mask based on TSLA value
        image = ee.Algorithms.If(valid_elevation, image, functions.create_shape(image=image, elevation=dem_bin, snow_line_elevation=cor_elevation))
        image = ee.Image(image)


        return image.set(
            'area_valid', global_area,
            'area_class', snow_class_area,
            'tsla_otsu', per_elevation,
            'elev_corr', mean_change,
            'delta_years', years_diff,
            'tsla_corr', cor_elevation
        )

    image_area_collection = image_collection.map(compute_fraction)
    return image_area_collection

sat_image_class = sat_image_mask.map(calculate_area_fraction)


print('(4) CALCULATE IMAGE BRIGHTNESS THRESHOLDS PER GEOMETRY ... PASSED')
########################################################################################################################
########################################################################################################################
########################################################################################################################





########################################################################################################################
########################################################################################################################
###### (5) EXPORT SNOW LINE OBSERVATIONS PER GLACIER
########################################################################################################################
########################################################################################################################
print('(5) EXPORT SNOW LINE OBSERVATIONS')

## export TSLA tabular results >>> this creates one csv per glacier with TSLA and all numeric statistics
if export_results == 1:
    print('... Export TSLA Numeric Results')

    # enter batch export loop
    for i in range(assets_aoi_count):
        exp_file = ee.FeatureCollection(sat_image_class.get(i))
        aoi_name = ee.Feature(geometry_list.get(i)).get('rgi_id')
        exp_name = region_ID + '_' + str(aoi_name.getInfo())
        print(f"Exporting table: {exp_name}")

        # set up batch job
        export_task = ee.batch.Export.table.toCloudStorage(
            collection=exp_file,
            description='csv_table_export',
            bucket=bucket_ID,
            fileFormat='CSV',
            fileNamePrefix=exp_name,
            selectors=['time_start',
                       'date_start',
                       'sat_origin',
                       'area_geometry',
                       'area_valid',
                       'area_class',
                       'sd_nsir',
                       'sd_ndwi',
                       'th_nsir',
                       'th_ndwi',
                       'bhatt_dist',
                       'delta_years',
                       'tsla_otsu',
                       'elev_corr',
                       'tsla_corr']
        )
        export_task.start()


## export TSLA spatial shapes >>> this creates one (Geotiff) mask per glacier based on TSLA value
## Note: This is ! NOT ! a mask of cells which where classified as snow based on their reflectance but solely based on elevation values above TSLA
if export_shapes == 1:
    print('... Export TSLA Spatial Shapes')

    # enter batch export loop
    for i in range(assets_aoi_count):
        exp_file = ee.ImageCollection(sat_image_class.get(i))
        aoi_file = ee.Feature(geometry_list.get(i))
        aoi_name = aoi_file.get('rgi_id')

        # create export file (one Geotiff per glacier, each band is a different date)
        exp_file = exp_file.map(functions.rename_as_bands)
        exp_file = exp_file.toBands()

        # create export file name
        exp_name = ee.Feature(geometry_list.get(i)).get('rgi_id')
        exp_name = region_ID + '_' + str(exp_name.getInfo())
        print(f"Exporting shape: {exp_name}")

        # set up batch job
        export_task = ee.batch.Export.image.toCloudStorage(
            image=exp_file,
            description='export_image',
            bucket=bucket_ID,
            fileNamePrefix=exp_name,
            region=aoi_file.geometry(),
            scale=EXPORT_RESOLUTION,
            crs=EXPORT_PROJECTION,
            maxPixels=1e13,
            fileFormat='GeoTIFF'
        )
        export_task.start()



print('(5) EXPORT SNOW LINE OBSERVATIONS ... PASSED')
########################################################################################################################
########################################################################################################################
########################################################################################################################







print('END OF SCRIPT')