import numpy as np
import matplotlib.pyplot as plt

# Definition of a string to number converter, it will try to convert to an integer first, and if
# it fails (becuase there's a decimal point), it will then convert it into a float
def number_conversion(s):
    if(s=='NA' or s=='NA\n'):
        return -1
    try:
        return int(s)
    except ValueError:
        return float(s)

# Change these to be whichever state you're working on
state = "IN"
# fullState = "West Virginia"
fullState = "Indiana"
# fullState = "Texas"

#Plot num of houses, population density, median age vs. %denied access

# This reads in the data files as Max has output them (subject to change)
# If the file format is changed, just change the number(s) to the column(s) you want
init_num_plots = [] #Column 0
init_pct_denied = [] #Column 2
init_tot_pop = [] #Column 3
init_num_houses = [] #Column 6
init_tot_area = [] #Column 7
init_med_age = [] #Column 8
# Change this line to be the file path pointing to where you store the data
with open("/Users/michael/Desktop/Forestry/Make Plots/"+state+"_summarized_1.csv") as file:
    # The first three columns are some string identifiers that I don't want right now
    headers = file.readline().split(",")[3:] #Header row
    # Read in the first line of data
    line = file.readline().split(",")[3:]
    # This loop splits each line in the file into the data you want
    # It stops when there aren't any more lines to read
    while line:
        # This line splits the string into its quantities and converts those
        # into floats or ints, depending on if they have a decimal point
        line_data = list(map(number_conversion,line))
        init_num_plots.append(line_data[0])
        init_pct_denied.append(line_data[2])
        init_tot_pop.append(line_data[3])
        init_num_houses.append(line_data[6])
        init_tot_area.append(line_data[7])
        init_med_age.append(line_data[8])
        line = file.readline().split(",")[3:]

# When reading the data in, they are a List, which just stores the data.
# We want the data in a NumPy array, which we can do math on.
num_plots = np.array(init_num_plots)
pct_denied = np.array(init_pct_denied)
tot_pop = np.array(init_tot_pop)
num_houses = np.array(init_num_houses)
tot_area = np.array(init_tot_area)
med_age = np.array(init_med_age)

# Calculate the population density using the NumPy arrays
pop_dens = tot_pop/tot_area * 1000**2

# Since this is a log plot, we need to make sure none of the values on the log
# axis are below 0 (will give an error, because taking the log of anything <= 0
# is undetermined.)
# Since we only care if the population density is below 0, we filter all the other
# variables on the population density, to make sure all the data matches through
# all the arrays.
mask_pop = pop_dens[pop_dens>0]
mask_den = pct_denied[pop_dens>0]
mask_plt = num_plots[pop_dens>0]

# Make a scatter plot of population density
# The s= statement changes the size of the points based on the sqrt of how many
# plots are in each tract.
plt.scatter(mask_pop,mask_den,alpha=0.5,s=5*np.sqrt(mask_plt-0.5))
# Change the scale of the x-axis to be a log scale
plt.xscale("log")
# Set the y- and x-axis labels to their corresponding values
plt.xlabel("Population Density ($population/km^2$)")
plt.ylabel("Percentage of Non-response")
# Set the title of the plot (and change it according to which state you're working on)
plt.title("Percentage of Non-response vs. Population Density per Census tract in "+fullState)
# Change this file path to where you want the plots to be saved.
# The "bbox_inches" cuts down the whitespace around the plot
# "DPI" changes the resolution of the saved plot (300 is a good value for normal
# print size, higher is better resolution).
plt.savefig('/Users/michael/Desktop/Forestry/Make Plots/pop_dens_'+state+'.png', bbox_inches='tight',dpi=300)
# Clear the figure area for the next plot
plt.clf()


plt.scatter(num_houses,pct_denied,alpha=0.5,s=5*np.sqrt(num_plots-0.5))
plt.xlabel("Number of houses")
plt.ylabel("Percentage of Non-response")
plt.title("Percentage of Non-response vs. Number of Houses per Census tract in "+fullState)
plt.savefig('/Users/michael/Desktop/Forestry/Make Plots/num_houses_'+state+'.png', bbox_inches='tight',dpi=300)
plt.clf()


plt.scatter(med_age,pct_denied,alpha=0.5,s=5*np.sqrt(num_plots-0.5))
plt.xlabel("Median Age")
plt.ylabel("Percentage of Non-response")
plt.title("Percentage of Non-response vs. Median Age per Census tract in "+fullState)
plt.savefig('/Users/michael/Desktop/Forestry/Make Plots/med_age_'+state+'.png', bbox_inches='tight',dpi=300)
plt.clf()
