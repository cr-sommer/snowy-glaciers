### THIS SCRIPT PROVIDES START/END OF SATELLITE MISSIONS

from datetime import datetime

print('... Loading Satellite Mission Period Lookup Table')


# SATELLITE OBSERVATION PERIOD PROPERTIES ##############################################################################
########################################################################################################################
# Note: Data periods are retrieved from earth engine catalogue
# Note: Sentinel-2 surface reflectance is only provided by ESA since 2017 !

# https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LT04_C02_T1_L2?hl=de
landsat4_first = datetime.strptime('1982-08-22', '%Y-%m-%d')
landsat4_last = datetime.strptime('1993-06-24', '%Y-%m-%d')

# https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LT05_C02_T1_L2?hl=de
landsat5_first = datetime.strptime('1984-03-16', '%Y-%m-%d')
landsat5_last = datetime.strptime('2012-05-05', '%Y-%m-%d')

# https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LE07_C02_T1_L2?hl=de
landsat7_first = datetime.strptime('1999-05-28', '%Y-%m-%d')
landsat7_last = datetime.strptime('2024-01-19', '%Y-%m-%d')

# https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LC08_C02_T1_L2?hl=de
landsat8_first = datetime.strptime('2013-03-18', '%Y-%m-%d')
landsat8_last = datetime.today().replace(hour=0, minute=0, second=0, microsecond=0) # ONGOING MISSION !

# https://developers.google.com/earth-engine/datasets/catalog/LANDSAT_LC09_C02_T1_L2?hl=de
landsat9_first = datetime.strptime('2021-10-31', '%Y-%m-%d')
landsat9_last = datetime.today().replace(hour=0, minute=0, second=0, microsecond=0) # ONGOING MISSION !

# https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2_SR_HARMONIZED?hl=de
sentinel2_first = datetime.strptime('2017-03-28', '%Y-%m-%d')
sentinel2_last = datetime.today().replace(hour=0, minute=0, second=0, microsecond=0) # ONGOING MISSION !

########################################################################################################################
########################################################################################################################


print('... Passed')