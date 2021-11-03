packages <- c("RJSONIO","rgdal","tidycensus", "sf","geojsonio", "sqldf", "tidyft",'dplyr','ggplot2','ggmap') #make a list of needed packages

#Install any needed packages
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}
lapply(packages, require, character.only = TRUE)#load the needed packages


#change this to your working directory
setwd("C:/Users/maxwo/OneDrive/Desktop/STAT598/WV")

#download the plot, cond, tree, and pop_plot_stratum_eval files for your state of interest from the FIA datamart. https://apps.fs.usda.gov/fia/datamart/CSV/datamart_csv.html
#Choose the state you want to work with
state = "WV" #choose state code of interest
data(fips_codes)
(stateFIPS = fips_codes[fips_codes$state ==state,2][1])
(stateNAME=sub(" ", "_",toupper(fips_codes[fips_codes$state ==state,3][1])))
featNAME = paste("ACS_2017_5YR_TRACT_",stateFIPS,"_",stateNAME,sep="")

dlGDB=paste("ACS_2017_5YR_TRACT_",stateFIPS,".gdb.zip",sep="")

(uzdlGDB = paste("ACS_2017_5YR_TRACT_",stateFIPS,"_",stateNAME,".gdb",sep=""))



filelist = c("plot", "POP_PLOT_STRATUM_ASSGN", "POP_EVAL")

options(timeout=200)
for (i in filelist){
  assign(i,read.csv(paste("http://apps.fs.usda.gov/fia/datamart/CSV/", state, "_", i,".csv", sep="")))
}

# #if it crashes, like for the state AS (American Samoa), try
# for (i in filelist){
#   download.file(paste("http://apps.fs.usda.gov/fia/datamart/CSV/", state, "_", i,".csv",sep=""),paste(state,"_",i,".csv",sep=""),method="libcurl",mode="wb")
#   assign(i,read.csv(paste(state, "_", i,".csv", sep="")))
#   
# }

#choose the EVALID you want:
eval = strtoi(stateFIPS) * 10000 + 1700


ppsa = POP_PLOT_STRATUM_ASSGN
filtered = filter(ppsa, EVALID == eval)
filtered = rename(filtered, ppsaCN = CN)
plot_renamed = rename(plot,PLT_CN = CN)
plot_joined = left_join(filtered, plot_renamed, by = c('PLT_CN'))

#now I have a file with just the plots in the EVALID I care about.
#now turn it into a geographic spatialpointsdataframe
p4stringFIA <- CRS("+init=epsg:4326")
names(plot_joined) #check what fields lon and lat are in.
plot_joined.SP  <- SpatialPointsDataFrame(plot_joined[,c(38,37)],plot_joined[,-c(38,37)],proj4string=p4stringFIA) #assuming field 38 is lon and 37 is lat


#only run this once to download census data
download.file(paste("https://www2.census.gov/geo/tiger/TIGER_DP/2017ACS/ACS_2017_5YR_TRACT_",stateFIPS,".gdb.zip",sep=""),dlGDB,method="libcurl",mode="wb")
unzip(dlGDB)

fcFeat <- as(st_read(dsn = uzdlGDB, layer = featNAME),"Spatial")
fcFeat@proj4string = plot_joined.SP@proj4string

layers = head(st_layers(uzdlGDB)$name,-2)
all_layers = st_layers(uzdlGDB)$name

#edited this to read all census layers
fcData <- as.data.frame(st_read(uzdlGDB, layer=layers[1]))
for(i in 1:(length(layers)-1)) {
  temp <- as.data.frame(st_read(uzdlGDB, layer=layers[i+1], quiet=T))
  fcData <- merge(fcData, temp)
}


full_names = as.data.frame(st_read(uzdlGDB, layer = all_layers[length(all_layers)-1]))
#don't need this
#for (ind in 2:length(colnames(fcData))){
  #sht_name = colnames(fcData)[ind]
  #colnames(fcData)[ind] = full_names[full_names$Short_Name==sht_name,]$Full_Name
#}

plot_joined.SP@data$GEOID = sp::over(plot_joined.SP, fcFeat[,"GEOID_Data"]) #now I have the GEOID attached to my plots, and I can join it to the values in fcData via the GEOID_Data field!

plotCensus=tidyft::left_join(plot_joined.SP@data,fcData,by="GEOID")

mapdata <- data.frame(plot_joined.SP)

#experiment with removing the remotely sensed plots - no chance of being denied access
plt_ct = summarize(group_by(plotCensus,GEOID), plots=sum(SAMP_METHOD_CD != 2), denied=sum(PLOT_NONSAMPLE_REASN_CD==2,na.rm=TRUE))
tract_filt = fcFeat
tract_filt@data = left_join(tract_filt@data,plt_ct, by=c('GEOID_Data'='GEOID'))
tract_filt = subset(tract_filt, plots>0)
tracts <- fortify(tract_filt, region ="GEOID_Data")
tracts = left_join(tracts,tract_filt@data, by=c('id'='GEOID_Data'))
tracts = mutate(tracts,pct_denied=denied/plots)

tract_data = left_join(tract_filt@data, fcData, by=c('GEOID_Data'='GEOID'))


#plot data with y=percentage denied and x=chosen variable

#data currently split by county and tract independently
#View(tract_data[c(65,302),1:20])

#merge by unique tract
test <- tract_data %>% group_by(NAMELSAD) %>% 
  summarize(num_plots=sum(plots), num_denied=sum(denied), pct_denied=sum(denied)/sum(plots), 
            total_pop=sum(B01001e1), pct_males=sum(B01001e2)/total_pop, pct_females=sum(B01001e26)/total_pop, 
            num_houses=sum(B25013e1), total_area=sum(ALAND), income=mean(B19001e1), age=mean(B01002e1),
            pct_unemployed=sum(B23025e5)/sum(B23025e1),
            pct_overhighschool=sum(B15003e19,B15003e20,B15003e21,B15003e22,B15003e23,B15003e24,B15003e25,
                                   B15003e3)/sum(B15003e1),
            pct_over65=sum(B01001e20,B01001e21,B01001e22,B01001e22,B01001e23,B01001e24,B01001e25,B01001e44,
                           B01001e45,B01001e46,B01001e47,B01001e48,B01001e49)/total_pop)


#Percentage of males
plot(test$pct_males, test$pct_denied)

#Percentage of females
plot(test$pct_females, test$pct_denied)

#Population density: Total population divided by total land area for scale
#aland and awater are in sq meters
area_sqkm = test$total_area / 1e6
density = test$total_pop / area_sqkm
plot(log(density), test$pct_denied, main=paste("Percentage of Denied Access vs Population Density Per Tract in", stateNAME),
     ylab="Percentage Denied")

#Logistic regression for percentage response
#cbind(successes, failures)
densitylogit <- glm(cbind(num_denied,num_plots-num_denied) ~ density, data=test, family="binomial")
summary(densitylogit)

#double checking logit
densitylogit1 <- glm(pct_denied ~ density, data=test, family="binomial", weight=num_plots)
summary(densitylogit1)


#Average Household Income per tract
plot(test$income, test$pct_denied)

incomelogit <- glm(cbind(num_denied,num_plots-num_denied) ~ income, data=test, family="binomial")
summary(incomelogit)

q <- quantile(test$income)
test <- test %>% mutate(income_bin=case_when(income < q[2] ~ 1,
                                             income >= q[2] & income < q[3] ~ 2,
                                             income >= q[3] & income < q[4] ~ 3,
                                             income >= q[4] ~ 4))

plot(test$income_bin, test$pct_denied)

#Average Age
plot(test$age, test$pct_denied)
agelogit <- glm(cbind(num_denied,num_plots-num_denied) ~ age, data=test, family="binomial")
summary(agelogit)

#Percent Unemployed 16 and older
unemployedlogit <- glm(cbind(num_denied,num_plots-num_denied) ~ pct_unemployed, data=test, family="binomial")
summary(unemployedlogit)

#Education - Percentage of Pop 25 years or older with more than high school / GED
overhighlogit <- glm(cbind(num_denied,num_plots-num_denied) ~ pct_overhighschool, data=test, family="binomial")
summary(overhighlogit)

#Percentage of Pop 65 years old and older
over65logit <- glm(cbind(num_denied,num_plots-num_denied) ~ pct_over65, data=test, family="binomial")
summary(over65logit)

#test full model
full_logit <- glm(cbind(num_denied,num_plots-num_denied) ~ density+income+age+pct_overhighschool+pct_over65, data=test, family="binomial")
summary(full_logit)
                               

plot_joined$PLOT_NONSAMPLE_REASN_CD[is.na(plot_joined$PLOT_NONSAMPLE_REASN_CD)] = 1

plot_pos = c(-72,41,-71,42.1)
map <- get_map(plot_pos, zoom=11)
# now create the map
ggmap(map) +
  geom_polygon(data=tracts, aes(x=long, y=lat, group=group,bg=pct_denied), color=alpha("black",0.5),alpha=0.25) +
  geom_point(data=mapdata, aes(x=LON, y=LAT, col=factor(plot_joined$PLOT_NONSAMPLE_REASN_CD)), alpha = 0.75, shape=1, size=0.4) +
#  coord_fixed() +
  scale_color_manual(name = "Plot type", values=c('blue','red','green'), labels = c("Sampled", "Denied", "Hazard")) +
#  scale_fill_viridis_c(option='magma')
  scale_fill_stepsn(colors=rainbow(12))
  

ggsave("ggPlots_RI.png",dpi = 1000)

ggplot()

# width <- tract_filt@bbox[3] - tract_filt@bbox[1]
# height <- tract_filt@bbox[4] - tract_filt@bbox[2]
# aspect <- height / width
# 
# png(filename = "Plots_RI.png", res = 600,width = 5, height = 5*aspect, units = 'in')
# par(mar = rep(0, 4), xaxs='i', yaxs='i')
# plot(tract_filt, col=tract_filt@data$plots)
# # plot(plot_joined.SP, pch = 1, cex = 0.5,col='black',add=TRUE)
# plot(plot_joined.SP, pch = 1, cex = 0.5,col=plot_joined$PLOT_NONSAMPLE_REASN_CD,add=TRUE)
# legend('topright', legend = c('Sampled','Denied','Hazardous'), col = c("black","red","green3"), pch = 1)
# dev.off()
