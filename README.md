# snowy-glaciers
This repository provides code to retrieve timevaring snow line altitudes (SLA) on glaciers. 

The main workflow is based on the Google Earth Engine Python API. Running the code requires an Earth Engine service accout and cloud project. Detailed information on the initialization and authorization of Earth Engine and required python packages can be found here:

https://developers.google.com/earth-engine/tutorials/community/intro-to-python-api;

https://developers.google.com/earth-engine/guides/auth;

https://developers.google.com/earth-engine/guides/service_account;

Results are exported to a Google Cloud Storage bucket:

https://cloud.google.com/storage
