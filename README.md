# snowy-glaciers
SNOWY-GLACIERS provides analysis code to retrieve time-varying snow line altitudes (SLA) on glaciers.

## Output
...

## Project setup
The main workflow is based on the Google Earth Engine Python API. Running the code requires an Earth Engine service accout and cloud project. Detailed information on the initialization and authorization of Earth Engine and required python packages can be found here: [python-api](https://developers.google.com/earth-engine/tutorials/community/intro-to-python-api); [Authentication](https://developers.google.com/earth-engine/guides/auth); [Service-Accounts](https://developers.google.com/earth-engine/guides/service_account)\
Results are exported to a Google Cloud Storage bucket: [Cloud-Storage](https://cloud.google.com/storage)

## Input data
SLA processing is based on the following datasets:
* Glacier areas from global inventory: Randolph Glacier Inventory 7.0 (RGI Consortium 2023)[^1]
* Surface reflectance products of optical satellite missions: Landsat 4-9 (USGS)[^2], Sentinel-2 (ESA)[^3]
* Surface elevations of digital elevation model (DEM): NASADEM (NASA JPL 2020)[^4]
* Glacier surface elevation change: DEM-differencing maps of mean elevation change per year (Hugonnet et al. 2021)[^5]

All input remote sensing datasets are accessed directly via the Earth Engine Data Catalogue. Users can select glaciers to be processed by providing RGI-IDs.



[^1]: RGI Consortium, (2023). Randolph Glacier Inventory - A Dataset of Global Glacier Outlines, Version 7 [Data Set]. Boulder,
Colorado USA. National Snow and Ice Data Center. [DOI](https://doi.org/10.5067/F6JMOVY5NAVZ). Date Accessed 01-04-2024.
[^2]: USGS. Landsat-4/5/7/8/9 image courtesy of the U.S. Geological Survey
[^3]: ESA. Copernicus Sentinel data [2017-2025]. Retrieved from Google Earth Engine [31.12.2025], processed by ESA.
[^4]: NASA JPL (2020). NASADEM Merged DEM Global 1 arc second V001 [Data set]. NASA EOSDIS Land Processes DAAC. Accessed 2020-12-30 from doi:10.5067/MEaSUREs/NASADEM/NASADEM_HGT.001.
[^5]: Hugonnet, R., McNabb, R., Berthier, E., Menounos, B., Nuth, C., Girod, L., Farinotti, D., Huss, M., Dussaillant, I., Brun, F., Kääb, A. (2021). Accelerated global glacier mass loss in the early twenty-first century. Nature 592, 726–731. [DOI](https://doi.org/10.1038/s41586-021-03436-z).
