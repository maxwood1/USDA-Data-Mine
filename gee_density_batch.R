#Final batch GEE canopy cover graph generator


##### Install python before running #####



#####  Code you need to edit  ######

# Change this to your main working directory (subfolders for each state will be created)
wd <- "C:/Users/maxwo/OneDrive/Desktop/STAT598"
setwd(wd)

statelist <- c("NY","NH") # Choose states, ~5 min per state

variable <- "percent_tree_cover" # Choose variable

noremote = TRUE
#TRUE = remove remotely sensed plots
#FALSE = include all plots



#####  Install Packages  #####

packages <- c("tidycensus","tidyft",'dplyr','stringr','reticulate','rgee','sf','googledrive') #make a list of needed packages
if (length(setdiff(packages, rownames(installed.packages()))) > 0) { #Install any needed packages
  install.packages(setdiff(packages, rownames(installed.packages())))  
}
lapply(packages, require, character.only = TRUE) #load the needed packages
data(fips_codes)

#If the rgee package doesn't load try running this

#system('pip3 install --upgrade pyasn1-modules') 
#rstudioapi::restartSession()
#require(rgee)



#####  Google Earth Engine Set Up  #####

ee_install() #connect to your account: say yes to prompts, it'll take about 2 minutes
ee_check() 

#Stop here to make sure everything says OK

ee_clean_pyenv() 
ee_Initialize(drive=TRUE) #this will open a browser window - accept the terms, copy the code, and input it in the console




#####  Run everything after this together  #####


nofiadata = FALSE
#TRUE = first time running for these states (no data)
filelist = c("plot", "POP_PLOT_STRATUM_ASSGN", "POP_EVAL")
for(state in statelist) {
  setwd(wd)
  #check if state's folder exists
  if(!dir.exists(state)) {
    dir.create(state)
  }
  setwd(paste(wd, state, sep="/"))
  for (i in filelist){
    if(!file.exists(paste(state,"_",i,".csv",sep=""))){
      nofiadata=TRUE
    }
  }
}


#####  GEE code section  #####

dataset <- ee$ImageCollection('USGS/NLCD_RELEASES/2016_REL')

#Filter the collection to the 2016 product.
nlcd2016 <- dataset$filter(ee$Filter$eq('system:index', '2016'))$first()

#Select the land cover band.
pctTC <- nlcd2016$select(variable)

#Here I'm masking out water on the NLCD landcover map. This will cause the summary functions to ignore water pixels
datamask <- nlcd2016$select('landcover')$gt(12) 
pctTCmask <- pctTC$updateMask(datamask) #This converts the water pixels to masked, so in theory shouldn't use them in focal calculations

#Define a boxcar or low-pass kernel
boxcar <- ee$Kernel$circle(radius=1609, units='meters', normalize=TRUE)  #this is the 1 mile radius circle; you can change this..

#Smooth the image by convolving with the boxcar kernel. This is using the "window" (the kernel) and calculating the average within the window
#so in our case, we're using a circle with a 1 mile radius, ignoring 0 values of canopy cover in NLCD water pixels

smoothMask <- pctTCmask$convolve(boxcar) #This is the layer I"m doing calculations on. If I choose not to use the water masking
#I need to either rename smoothMask below or simply call smoothMask the layer.

smoothIC <- ee$ImageCollection(smoothMask)

#function to map over the FeatureCollection
mapfunc <- function(feat) {
  #get feature geometry
  geom <- feat$geometry()
  #function to iterate over the ImageCollection; I only have 1 layer, but can do it for more.
  # the initial object for the iteration is the feature
  addProp <- function(img, f) {
    # cast Feature
    newf <- ee$Feature(f)
    # get date as string
    date <- img$date()$format()
    # extract the value in the feature
    value <- img$reduceRegion(ee$Reducer$first(), geom, 30)$get('percent_tree_cover')
    # if the value is not null, set the values as a property of the feature. The name of the property will be the date
    ee$Feature(ee$Algorithms$If(value,
                                newf$set(date, ee$String(value)),
                                newf$set(date, ee$String('No data'))))
  }
  newfeat <- ee$Feature(smoothIC$iterate(addProp, feat))
  return(newfeat)
}




#####  Back to R  #####


#gets FIA data, saves it for later use, then does merge in GEE
getdata <- function(state, nofiadata) {
  #go to folder where state's data is
  setwd(paste(wd, state, sep="/"))
  
  stateFIPS = fips_codes[fips_codes$state ==state,2][1]
  stateNAME=sub(" ", "_",toupper(fips_codes[fips_codes$state ==state,3][1]))
  
  #Set what FIA data files you want
  filelist = c("plot", "POP_PLOT_STRATUM_ASSGN", "POP_EVAL")
  
  if (nofiadata) {
    options(timeout=200)
    for (i in filelist){
      assign(i,read.csv(paste("http://apps.fs.usda.gov/fia/datamart/CSV/", state, "_", i,".csv", sep=""))) #read files from website
    }
    for (i in filelist){
      write.csv(get(i),paste(state,"_",i,".csv",sep=""),row.names=F) #save files for later use
    }
  } else {
    for (i in filelist){
      assign(i,read.csv(paste(state,"_",i,".csv",sep=""))) #read files from folder
    }
  }
  
  #choose the EVALID you want:
  eval = as.numeric(stateFIPS) * 10000 + 1700
  
  ppsa = POP_PLOT_STRATUM_ASSGN
  filtered = filter(ppsa, EVALID == eval)
  filtered = rename(filtered, ppsaCN = CN)
  plot_renamed = rename(plot,PLT_CN = CN)
  plot_joined = left_join(filtered, plot_renamed, by = c('PLT_CN'))
  
  gee_data <- plot_joined %>% select(PLT_CN, LAT, LON, PLOT_NONSAMPLE_REASN_CD, SAMP_METHOD_CD)

  
  #Now do layer connection using GEE through R
  
  #change NA to -1 for smooth transition to GEE
  gee_data[is.na(gee_data)] <- -1
  
  #set asset id
  id <- paste(ee_get_assethome(), "/", state, "_gee_data", sep="")
  
  #convert gee data to shapefile
  gee_sf <- st_as_sf(gee_data, coords=c("LON","LAT"), crs=4326)
  
  #add gee data as an asset
  pts <- sf_as_ee(gee_sf, via="getInfo_to_asset", assetId = id) #could look into removing temp file if it's too much memory
  
  #merge with GEE data here
  newft <- pts$map(mapfunc)
  
  #delete file on drive if it exists already
  file = paste(state,"_gee_",variable,".csv",sep="")
  d <- drive_find(file)
  if(nrow(d) > 0) {
    drive_trash(file)
  }
  
  #extract data from gee object to Google Drive
  exportTask <- ee_table_to_drive(newft, folder="DataMine", fileNamePrefix=paste(state,"_gee_",variable,sep=""), fileFormat="CSV", timePrefix = FALSE)
  exportTask$start()
  
  #track task
  ee_monitoring()
  
  #download from Google Drive and save as csv in state's folder
  drive_download(file, overwrite=TRUE) #follow prompts and check box to allow it to read and edit files
}



#####  This uses above function to get FIA data and merge with GEE data  #####

for(state in statelist) {
  getdata(state, nofiadata)
}




#####  If you're re-running and have the csv from GEE just run the rest after package loading  #####


#plots density graph
plotdensity <- function(state, noremote) {
  #go to folder where data is
  setwd(paste(wd, state, sep="/"))
  
  plot_gee <- read.csv(paste(state,"_gee_",variable,".csv",sep=""))
  
  if(noremote) {
    plot_gee <- plot_gee %>% filter(SAMP_METHOD_CD != 2)
  }
  
  index <- which(substr(colnames(plot_gee),1,2)=="X2")
  colnames(plot_gee)[index] <- "canopy"
  plot_gee$canopy <- as.numeric(as.character(plot_gee$canopy))
  
  plot_gee[is.na(plot_gee)] <- -1
  #sampled in PLOT_NONSAMPLE_REASN_CD is -1
  
  #make nonresponse column (all nonresponse)
  plot_gee$nonresponse <- 0
  for(i in 1:length(plot_gee$PLOT_NONSAMPLE_REASN_CD)) {
    if(plot_gee$PLOT_NONSAMPLE_REASN_CD[i]==-1) {
      plot_gee$nonresponse[i]=0
    } else {
      plot_gee$nonresponse[i]=1
    }
  }
  plot_gee$nonresponse <- as.factor(plot_gee$nonresponse)
  
  #get state name with space
  stateFIPS = fips_codes[fips_codes$state ==state,2][1]
  stateNAME=sub(" ", "_",toupper(fips_codes[fips_codes$state ==state,3][1]))
  stname <- sub("_"," ", stateNAME)
  stname <- str_to_title(stname)
  
  #Kernel density with canopy cover
  samp_canopy <- plot_gee %>% filter(nonresponse==0)
  samp_canopy <- samp_canopy$canopy
  nonresponse_canopy <- plot_gee %>% filter(nonresponse==1) 
  nonresponse_canopy <- nonresponse_canopy$canopy
  
  samp_density <- density(samp_canopy, na.rm=T, from=0, to=100)
  nonresponse_density <- density(nonresponse_canopy, na.rm=T, from=0, to=100)
  
  maxnr <- max(nonresponse_density$y)
  maxsamp <- max(samp_density$y)
  if(maxnr >= maxsamp) {
    maxy <- maxnr
    i <- nonresponse_density$x[which.max(nonresponse_density$y)]
  } else {
    maxy <- maxsamp
    i <- samp_density$x[which.max(samp_density$y)]
  }
  
  if(i >= 50) {
    loc = "topleft"
  } else {
    loc = "topright"
  }
  
  title <- paste("Kernel Density of Nonresponse vs Sampled Plots in",stname)
  if (noremote) {
    title <- paste(title, "(No Remotely Sensed)")
  }
  
  # Kernel density plot
  plot(samp_density, lwd = 2, main = title, xlab="Percentage Canopy Cover", ylim=c(0, 1.1*maxy))
  lines(nonresponse_density, lwd = 2, col="red")
  legend(loc, legend=c("Sampled", "Nonresponse"),
         col=c("black", "red"), lwd=2, cex=0.8)
  abline(v = median(samp_canopy, na.rm=T), col="black")
  abline(v = median(nonresponse_canopy, na.rm=T), col="red")
}



##### This uses above function to make plots #####

for(state in statelist) {
  plotdensity(state, noremote)
}

