# Readme/Report of the USDA FIA Purdue DataMine project of 2021-2022

**##Team Members **

Michael Carlson

Simarjot Dhaliwah

Amanda Jacobucci

Vidya Vuppala

Rohan Wadhwa

Max Woodbury 


## Background

The USDA’s Forest Service's Forest Inventory and Analysis branch (FIA) is responsible for collecting, analyzing, and reporting information about America’s forests to allow others to make “science based decisions, backed by forest data”. Field crew workers are sent to randomly sampled plots throughout the Nation, to collect a variety of core measurements, which are used to obtain overall measurements of the Nation’s forests. 

In order to obtain the measurements, FIA divides their plots into various categories. **Visited Plots** are sampled plots, field crew members are able to physically access and obtain actual measurements from. **Remotely Sensed Plots** are plots where a human interpreter of high-resolution imagery determines if the plot is a “non-forest” plot based on the percentage of canopy cover. If canopy cover is less than 10%, the plot is labeled as “sampled'', however, field crew members do not physically visit the plot. Instead,satellite imagery enables FIA to collect some information on the plot such as land cover and use.  

The challenge FIA faces is that they are not able to physically visit every sampled plot. Plots are either deemed “hazardous”, which means the land is too dangerous to go on, or they are labeled “denied-access”, meaning the landowners did not allow them on their land. Therefore, both hazardous and denied-access plots are thrown into the pool of **Non-Response Plots**. FIA is still expected to provide unbiased estimates, regardless of the missing data. During our research, we wanted to work to find the best way to incorporate non-response plots into FIA’s estimations.    

  
## Motivation

<img src="https://github.com/maxwood1/USDA-Data-Mine/blob/main/Images/FIA_plot_types.png"
     alt="Plots Example"
     width=400px
     height=auto />

To answer this question, we first need to understand how FIA estimates are created. The traditional method that FIA uses assumes that the non-response plots have the same characteristics as all sampled plots, which contains both visited and remotely sensed. The issue with this assumption is that the remotely sensed plots have no chance of being non-response, since their values are obtained from satellite data. So, the Purdue method we are proposing assumes instead that non-response plots more closely resemble the visited plots.

The reasoning for this can be seen in the two graphs listed below, which compare the distribution of canopy cover for the different plot types. The left graph compares the distribution of all sampled plots to non-response, and this tests the traditional method's assumption. While the right graph compares the distribution of visited plots to non-response, which tests the Purdue method's assumption. Both methods assume that the red and black lines in each graph are the same. In this case, the traditional method's assumption is likely incorrect since the lines are very different, while the Purdue method's assumption is likely met since the lines are close together. This empirically shows why the Purdue method may be better.


<img src="https://github.com/maxwood1/USDA-Data-Mine/blob/main/Images/Purdue_method.png"
     alt="Purdue Method"
     width=45%
     height=auto
     float:left />
<img src="https://github.com/maxwood1/USDA-Data-Mine/blob/main/Images/Traditional_method.png"
     alt="Traditional Method"
     width=45%
     height=auto
     float:left />

                             
## Stratification

In the context of forest inventory, stratification is a statistical method used to improve estimates by taking advantage of information contained in maps to assign plots to homogeneous groups and provide weights to a weighted averaging procedure. In our example below, a canopy cover map in which each pixel is labeled for its percent tree canopy can be classified into 2 classes: forest and non-forest. Canopy cover percent between 0% to 20% are regarded as non-forest, Canopy cover percent between 20% to 100% are regarded as forest. FIA uses post stratification to improve the precision of estimates.

<img src="https://github.com/maxwood1/USDA-Data-Mine/blob/main/Images/Stratification.png"
     alt="Stratification Example"
     width=75%
     height=auto />
     
## Simulation

We simulated plot populations with different proportions of visited, non-response, and remotely sensed plots. We calculated mean canopy cover values for each of two nonresponse mitigation methods (top row: Purdue method; second row: Traditional FIA  method) with these simulated populations, varying stratification threshold (columns), proportion of plots that are remotely sensed (x axis) and nonresponse rate (y axis). We also compared the errors between the two estimation methods (bottom row). The error comparison (bottom row) shows where the Purdue method outperforms the traditional method (the blue regions), and where the traditional method performs better (the red regions). 

<img src="https://github.com/maxwood1/USDA-Data-Mine/blob/main/Images/Screen%20Shot%202022-04-12%20at%202.25.02%20PM.png"
     alt="Stratification Example"
     width=75%
     height=auto />

## Conclusion 

The Purdue method of filling the non-response plots with only the mean value of the visited plots, is generally more accurate and produces less bias than the traditional method. That being said, the traditional method gives better estimations for a small subset of factor combinations, but has much higher error when both the proportions of remotely sensed plots and non-response plots are high. 

## Future Works 

The analysis we performed, dealt with instances where the entire plot was labeled non-response. An extension to this could analyze instances where only part of the plots are non-response. Additionally, we focused on Indiana for our analysis, but it would be beneficial to look at other states or on a more cohesive level. Lastly, for our simulation, we stratified by canopy cover percentage values; it would be useful to stratify based on other variables, as canopy cover acts slightly different than most, with is being a relative frequency, instead of a counting variable. 

## Acknowledgments   

**Corporate Partner Mentors:** Andrew Lister and Gretchen Moisen

**USDA Contributor:** Rachel Riemann

**Contributor Speaker:** Kelly McConville

**Corporate Partner TA:** Patrick Todjalla

**DataMine Staff:** Shuennhow Chang 


## List of files in the github

[Useful_Census_Layers.csv](https://github.com/maxwood1/USDA-Data-Mine/blob/main/Useful_Census_Layers.csv)

A list of variables within the US tiger census that correlated interestingly with the FIA non-response data. This list also includes the short-hand lookup codes to find the variables within the census dataset.

[Census_FIA_joining.R](https://github.com/maxwood1/USDA-Data-Mine/blob/main/Census_FIA_joining.R)

This R code geospatially connects the Tiger census to the FIA plot dataset to correlate the different census variables to the FIA non-response rate. It downloads the census as well as the FIA plot data set off the internet for a specified state.

[Pop_dens_plotter.py](https://github.com/maxwood1/USDA-Data-Mine/blob/main/Pop_dens_plotter.py)

This python code reads a file created by Census_FIA_joining.R that has columns [Number of plots, Number of non-response plots, Percent of non-response plots, Total population, Number of houses, Total area, median age, population density, latitude, longitude]. Each row of this file corresponds to a different census tract. It then creates scatter plots of these census variables vs. the percent of non-response in each census tract.

[gee_canopycover.R](https://github.com/maxwood1/USDA-Data-Mine/blob/main/gee_canopycover.R)

This R code has two parts, the first part sets files up to put FIA plot data into Google Earth Engine. The second part takes the files created from the Google Earth Engine Analysis (done with the gee_code.txt file) and does analyses on the canopy cover data that is now connected to the FIA plot-level data.

[gee_code.txt](https://github.com/maxwood1/USDA-Data-Mine/blob/main/gee_code.txt)

This is JS code that is meant to be copied into the Google Earth Engine code editor. It takes the file that was created by the first part of gee_canopycover.R and connects the FIA plot data contained within that file to the Canopy cover data in the Landsat data set within the Google Earth Engine data library. It then exports a summary file to one’s google drive account for download.

[gee_density_batch.R](https://github.com/maxwood1/USDA-Data-Mine/blob/main/gee_density_batch.R)

This R file is a combination of the gee_canopycover.R and gee_code.txt files. It connects and analyzes FIA plot data with Landsat canopy cover data. It has also been modified to be able to perform this work over multiple states in one run.

[Simulate.py](https://github.com/maxwood1/USDA-Data-Mine/blob/main/Simulate.py)

This Python file imports the canopy cover data file created by gee_code.txt to simulate FIA plot populations that follow different distributions of non-response and remote sensing. This allows us to study how these factors affect the accuracy of different methods of estimation to fill in the data missing because of non-response plots. This file runs two estimation methods, one that keeps remotely sensed plots in the estimation process and one that uses only physically visited plots in the estimation. Both methods use a perfect stratification that bins the plots according to percent of canopy cover. The threshold for this stratification is contained in a variable. This program then finds the error of each estimator, compared with the true simulated value of each population. It outputs a file containing this error data to be read and visualized by Plot.py.

[Plot.py](https://github.com/maxwood1/USDA-Data-Mine/blob/main/Plot.py)

This python code imports the data file created by Simulate.py and creates a graphic of the data. It visually compares the accuracy of the different estimation methods as well as the different stratification thresholds. The code is separated in this way so that one does not need to run the simulation each time the plot needs to be changed (as the simulation can take up to half an hour depending on the desired data resolution).
