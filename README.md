# snowy-glaciers
SNOWY-GLACIERS provides analysis code to retrieve time-varying snow line altitudes (SLA) on glaciers.

# Output
...

# Project setup
The main workflow is based on the Google Earth Engine Python API. Running the code requires an Earth Engine service accout and cloud project. Detailed information on the initialization and authorization of Earth Engine and required python packages can be found here:

https://developers.google.com/earth-engine/tutorials/community/intro-to-python-api;

https://developers.google.com/earth-engine/guides/auth;

https://developers.google.com/earth-engine/guides/service_account;

Results are exported to a Google Cloud Storage bucket:

https://cloud.google.com/storage

# Input data
SLA processing is based on the following datasets:

*Glacier areas from global inventory: Randolph Glacier Inventory 7.0

*Surface reflectance products of optical satellite missions: Landsat 4-9, Sentinel-2 (depending on survey period)

*Surface elevations of digital elevation model (DEM): NASADEM

*Glacier surface elevation change: DEM-differencing maps of mean elevation change per year

All input remote sensing datasets are accessed directly via the Earth Engine Data Catalogue. Users can select glaciers to be processed by providing RGI-IDs.
