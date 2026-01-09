# snowy-glaciers
*SNOWY-GLACIERS* provides analysis code to retrieve time series of the *snow line altitude* (**SLA**) on glaciers. SLAs are measured using the surface reflectance of snow and ice in the infrared and visible spectra, based on medium-resolution optical remote sensing data. Automatic glacier surface classification is performed using image segmentation and Otsu's method[^1]. The elevation of the surface at the transition between bare ice and snow (i.e. the SLA) is estimated using a digital elevation model (DEM), to which a temporal correction is applied to account for changes in glacier elevation due to surface melt. A detailed overview of the applied methodology and SLA results of glaciers in the European Alps is presented here: ADD-PREPRINT-DOI

### Output
...

### Project setup
The main workflow is based on the Google Earth Engine Python API. Running the code requires an Earth Engine service accout and cloud project. Detailed information on the initialization and authorization of Earth Engine and required python packages can be found here: [python-api](https://developers.google.com/earth-engine/tutorials/community/intro-to-python-api); [Authentication](https://developers.google.com/earth-engine/guides/auth); [Service-Accounts](https://developers.google.com/earth-engine/guides/service_account)\
Results are exported to a Google Cloud Storage bucket: [Cloud-Storage](https://cloud.google.com/storage)

### Input data
The following datasets are used for SLA processing:
* Glacier areas from global inventory: Randolph Glacier Inventory 7.0 (RGI Consortium 2023)[^2]
* Surface reflectance products of optical satellite missions: Landsat 4-9 (USGS)[^3], Sentinel-2 (ESA)[^4]
* Surface elevations of DEM: NASADEM (NASA JPL 2020)[^5]
* Glacier surface elevation change (DHDT): DEM-differencing maps of mean elevation change per year (Hugonnet et al. 2021)[^6]

All input remote sensing datasets are accessed directly via the Earth Engine Data Catalogue. To process glaciers, users must provide glacier IDs in the format ***RGI2000-v7.0-G-99-99999*** (see "rgi_id" attribute of RGI version 7.0).

>[!WARNING]
>Please note that selecting glaciers that are far apart can drastically increase the processing time. Similarly, you should avoid selecting glaciers from different regions during the same processing session. If you are interested in single glaciers that are far apart, it may be more efficient to process each glacier individually.

### Snow line processing
The retrieval of glacier snow lines features the following main functions:
* Selection of satellite images (Landsat[^3] & Sentinel-2[^4]) acquired within supplied survey period and saturation filter
* Creation of daily mosaics of images acquired by the same sensor to avoid fragmentation of glacier areas
* Masking of image data to glacier outlines (RGI 7.0[^2])
* Filtering for pixels which are neither snow nor ice (e.g. clouds, rocks, debris, water, etc.)
* Filtering for pixels which are shaded by nearby terrain (based on DEM and satellite viewing geometry)
* Filtering for pixels with extreme low/high infrared reflectance (e.g. cloud artefacts, reflectance close to band saturation threshold)
* Two-step image thresholding based on ratios of near-infrared (*NIR*), shortwave-infrared (*SWIR*) and *GREEN* bands (performed for each glacier and each date)
* Creation of binary snow and ice masks, estimation of snow line elevation by masking vertically binned DEM[^5]
* Vertical correction of SLA for changes in glacier surface elevation (using glacier surface elevation change maps[^6])
* Export of SLA time series (one csv-table per glacier)
* Optional - Export of raster snow masks (one multi-band Geotiff per glacier)

All of the processing routines for the Earth Engine SLA are combined in the ***'main.py'***, ***'functions.py'*** and ***'satellites.py'*** files.

>[!Note]
>In order to process snow lines in Google Earth Engine, users must adjust the processing variables in the ***'main.py'*** header. In particular, the Earth Engine service account and key must be set, as well as your cloud project name, in order to authenticate (see *Project setup* section). Further variables specify the survey period and target glaciers (see the beginning of 'main.py' for detailed variable descriptions).\
>The additional scripts, ***'functions.py'*** and ***'satellites.py'***, provide raster processing functions and satellite mission periods, respectively. Both are sourced by 'main.py' and do not require any user changes.


### Snow line trend analysis
...


[^1]: Otsu, N. (1979): A Threshold Selection Method from Gray-Level Histograms, IEEE Trans. Syst., Man, Cybern., 9, 62–66, https://doi.org/10.1109/TSMC.1979.4310076.
[^2]: RGI Consortium, (2023). Randolph Glacier Inventory - A Dataset of Global Glacier Outlines, Version 7 [Data Set]. Boulder,
Colorado USA. National Snow and Ice Data Center. [DOI](https://doi.org/10.5067/F6JMOVY5NAVZ). Date Accessed 01-04-2024.
[^3]: USGS. Landsat-4/5/7/8/9 image courtesy of the U.S. Geological Survey
[^4]: ESA. Copernicus Sentinel data [2017-2025]. Retrieved from Google Earth Engine [31.12.2025], processed by ESA.
[^5]: NASA JPL (2020). NASADEM Merged DEM Global 1 arc second V001 [Data set]. NASA EOSDIS Land Processes DAAC. Accessed 2020-12-30 from doi:10.5067/MEaSUREs/NASADEM/NASADEM_HGT.001.
[^6]: Hugonnet, R., McNabb, R., Berthier, E., Menounos, B., Nuth, C., Girod, L., Farinotti, D., Huss, M., Dussaillant, I., Brun, F., Kääb, A. (2021). Accelerated global glacier mass loss in the early twenty-first century. Nature 592, 726–731. [DOI](https://doi.org/10.1038/s41586-021-03436-z).
