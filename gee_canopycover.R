#Data for Google Earth Engine and Graphs

packages <- c("RJSONIO","rgdal","tidycensus","sf","geojsonio","sqldf","tidyft",'dplyr','stringr') #make a list of needed packages

#Install any needed packages
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}
lapply(packages, require, character.only = TRUE)#load the needed packages

#change this to your working directory
setwd("C:/Users/maxwo/OneDrive/Desktop/STAT598/UT")

state = "UT" #choose state code of interest

data(fips_codes)
(stateFIPS = fips_codes[fips_codes$state ==state,2][1])
(stateNAME=sub(" ", "_",toupper(fips_codes[fips_codes$state ==state,3][1])))


## Get FIA data

#See https://apps.fs.usda.gov/fia/datamart/CSV/datamart_csv.html
filelist = c("plot", "POP_PLOT_STRATUM_ASSGN", "POP_EVAL")

options(timeout=200)
for (i in filelist){
  #assign(i,read.csv(paste("http://apps.fs.usda.gov/fia/datamart/CSV/", state, "_", i,".csv", sep="")))
  assign(i,read.csv(paste(state,"_",i,".csv",sep="")))
}

#save the files for later
#for (i in filelist){
  #write.csv(get(i),paste(state,"_",i,".csv",sep=""),row.names=F)
#}

#choose the EVALID you want:
eval = strtoi(stateFIPS) * 10000 + 1700

ppsa = POP_PLOT_STRATUM_ASSGN
filtered = filter(ppsa, EVALID == eval)
filtered = rename(filtered, ppsaCN = CN)
plot_renamed = rename(plot,PLT_CN = CN)
plot_joined = left_join(filtered, plot_renamed, by = c('PLT_CN'))

gee_data <- plot_joined %>% select(PLT_CN,LAT,LON,PLOT_NONSAMPLE_REASN_CD)

#write.csv(gee_data, paste(state,"_gee_data.csv",sep=""),row.names=FALSE)


## do GEE stuff now to attach FIA plots to geo layer


## After GEE

plot_gee <- read.csv(paste(state,"_gee_canopycover.csv",sep=""))

colnames(plot_gee)[2] <- "canopy"
plot_gee$canopy <- as.numeric(as.character(plot_gee$canopy))

length(which(is.na(plot_gee$canopy)))
nrow(plot_gee)

#set NA sample reason to sampled (0)
plot_gee$PLOT_NONSAMPLE_REASN_CD[which(is.na(plot_gee$PLOT_NONSAMPLE_REASN_CD))] = 0

#make nonresponse column
#look at all nonresponse to see if there are differences
plot_gee$nonresponse <- 0
for(i in 1:length(plot_gee$PLOT_NONSAMPLE_REASN_CD)) {
  if(plot_gee$PLOT_NONSAMPLE_REASN_CD[i]==0) {
    plot_gee$nonresponse[i]=0
  } else {
    plot_gee$nonresponse[i]=1
  }
}

plot_gee$nonresponse <- as.factor(plot_gee$nonresponse)


#get state name with space
stname <- sub("_"," ", stateNAME)
stname <- str_to_title(stname)


#Boxplot with canopy cover
boxplot(plot_gee$canopy ~ plot_gee$nonresponse, main=paste("Nonresponse Status vs Percentage of Canopy Cover in",stname),
        xlab = "Status",ylab = "Canopy Cover (%)",names=c("Sampled","Nonresponse"))


#Kernel density with canopy cover
samp_canopy <- plot_gee %>% filter(nonresponse==0)
samp_canopy <- samp_canopy$canopy
nonresponse_canopy <- plot_gee %>% filter(nonresponse==1) 
nonresponse_canopy <- nonresponse_canopy$canopy
  
samp_density <- density(samp_canopy, na.rm=T)
nonresponse_density <- density(nonresponse_canopy, na.rm=T)

# Kernel density plot
plot(samp_density,lwd = 2, main = paste("Kernel Density of Nonresponse vs Sampled Plots in",stname), xlab="Percentage Canopy Cover")
lines(nonresponse_density, lwd = 2, col="red")
legend("topright", legend=c("Sampled", "Nonresponse"),
       col=c("black", "red"), lwd=2, cex=0.8)
