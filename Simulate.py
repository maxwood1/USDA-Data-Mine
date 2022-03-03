import numpy as np
import matplotlib.pyplot as plt
from sklearn.neighbors import KernelDensity
import matplotlib.colors as colors
import matplotlib.ticker as ticker
from progress.bar import Bar
import matplotlib.cm as cm

################################################################################
# This program reads in a GEE-generated csv file '[state]_gee_canopycover.csv'.
# This file must have the columns (in this order):
#   GEE Index, %Canopy cover, Nonsample reason, Plot CN, Sample Method
#
# It uses this data file to generate a canopy cover distributions of plots for 3
# populations: Physically visited plots, Remotely sensed plots, and Non-response
# plots. It then samples from these distributions to create an artificial
# dataset, where the user can specify the relative percentages of each
# population. It then calculates the canopy cover estimate by filling in values
# for the non-response plots. It writes these values to a file to be read and
# used by the Plot.py program.
#
# It current runs a nested loop that varies non-response rate and remotely
# sensed rate from 0-100% each (without the total going over 100%), to generate
# a 'triangle' of data, showing the whole gamut of potential situations.
################################################################################

# Change this prefix to be your file path.
file_path_prefix = "/Users/michael/Desktop/Forestry/Simulation plots/"

state='OR'

# This creates a numpy array from a text file. The 'missing_values' option specifies
# What string values mean there is no data there and should be filled with the value
# given by the 'filling_values' option.
data = np.genfromtxt(file_path_prefix+state+'_gee_canopycover.csv', skip_header=1, missing_values=('No data', 'NA'), filling_values=-1, usecols=(1,2,4),delimiter=',')

# This removes all the data points we don't have canopy cover data for.
have_data = data[data[:,0]>=0]

# This breaks our canopy cover data up into their respective populations.
visit = have_data[np.logical_and(have_data[:,2]==1,have_data[:,1]==-1)][:,0]
remote = have_data[have_data[:,2]==2][:,0]
non = have_data[have_data[:,1]==2][:,0]

temp = have_data[have_data[:,1]==2]
print(len(temp[temp[:,2]==2]), len(non))
print(len(have_data),len(visit),len(remote),len(non))

# This prints out the percent of total population each sub-population is
# e.g.: visited: 60%, remote: 30%, non-response: 10%.
# Note that these percentages should add up to 100%
print('Visited:',len(visit)/len(have_data))
print('Remote:',len(remote)/len(have_data))
print('Non-Response',len(non)/len(have_data))

# These lines estimate the probability density distribution for canopy cover for
# each of the three populations. The 'band' variable controls how wide the
# smoothing band is (i.e.: smaller value is more jagged)
band = 2
kdv = KernelDensity(kernel='gaussian', bandwidth=band).fit(visit.reshape(-1, 1))
kdr = KernelDensity(kernel='gaussian', bandwidth=band).fit(remote.reshape(-1, 1))
kdn = KernelDensity(kernel='gaussian', bandwidth=band).fit(non.reshape(-1, 1))

# This creates a sample population given inputs of density and how big you want
# the population to be. The density estimates do go below 0 (which cannot happen
# in reality, a negative canopy cover makes no sense), so there is a loop to
# ensure that it returns a population of the requested length with all positive
# values.
def sampler(kde, length):
    samp = -1*np.ones(length)
    ind_at = 0
    while len(samp[samp>=0])<length:
        temp = kde.sample(length-ind_at)
        good = temp[temp>=0]
        samp[ind_at:ind_at+len(good)] = good
        ind_at = ind_at + len(good)
    return samp

# These are parameters for the data generation/simulation.
# 'tot_amt': total number of plots in the population
# 'num_test': How many data points for the non-response and remotely sensed
#             grid. (e.g.: a 50x50 grid going from 0-1 for both the non-response
#             and remotely sensed rates)
# 'non_pcts': The list of non-response rates to test
# 'rem_pcts': The list of remotely sensed rates to test
# 'strats': An empty array to hold the estimates using stratification
# 'boths': An empty array to hold the estimates from stratifying without
#          remotely sensed plots
# 'num_mean': How many trials to run for each pair of non_pct and rem_pct (to
#             get a smoother and more accurate estimation)
# 'strat_pct': What percentage of canopy cover should be used for the
#              stratifcation breakpoint (i.e.: canopy cover below this value
#              will be put in the low stratum, and above in the high stratum)
tot_amt = 10000
num_test = 50
non_pcts = np.linspace(0,0.99,num=num_test)
rem_pcts = np.linspace(0,0.99,num=num_test)
strats = np.zeros((num_test,num_test))
boths = np.zeros((num_test,num_test))
num_mean = 50

strat_pct = 70

# This 'bar' is just a progress bar to help you know how the simulation is
# proceeding. So you know that your computer isn't just sitting there.
bar = Bar('Simulating', max=num_test*num_test)

# This loop contains the loops that go through each pair of the non-response and
# remotely sensed percentages and simulates canopy cover estimates.
for indn,non_pct in enumerate(non_pcts):
    for indr,rem_pct in enumerate(rem_pcts[:]):
        # Find the actual amount of each plot population, should add up to
        # be tot_amt
        v_amt = round((1-non_pct-rem_pct)*tot_amt+1)
        r_amt = round(rem_pct*tot_amt)
        n_amt = round(non_pct*tot_amt)
        # print(v_amt, r_amt, n_amt)
        # Make sure there's at least a few visited plots
        if v_amt <= 2:
            bar.next()
            continue
        # Create arrays to hold the results of each of the 'num_mean' attempts
        truths = np.zeros(num_mean)
        str_att = np.zeros(num_mean)
        bot_att = np.zeros(num_mean)
        # Redo the simulation and estimation 'num_mean' times to get a better
        # average value
        for attempts in range(num_mean):

            # Use the sampling function defined earlier to simulate a population
            # of plots
            v_samp = sampler(kdv, v_amt)
            r_samp = sampler(kdr, r_amt)
            n_samp = sampler(kdn, n_amt)

            # Break the simulated populations into their strata
            v_low  = v_samp[v_samp < strat_pct]
            v_high = v_samp[v_samp >= strat_pct]
            r_low  = r_samp[r_samp < strat_pct]
            r_high = r_samp[r_samp >= strat_pct]
            n_low  = n_samp[n_samp < strat_pct]
            n_high = n_samp[n_samp >= strat_pct]

            if(len(v_low))<1:
                v_low = [0]
            if(len(v_high))<1:
                v_high= [0]

            # Find the mean of the strata using both visited and remote plots
            # These estimates will be used to fill in non-response plots
            strat_l = np.mean(np.concatenate((v_low,  r_low)))
            strat_h = np.mean(np.concatenate((v_high, r_high)))

            # Find the mean of the strata using just visited plots
            both_l = np.mean(v_low)
            both_h = np.mean(v_high)

            # Calculate the true canopy cover, and estimates for stratification
            # with (str_att) and without (bot_att) for this estimate attempt
            truths[attempts] = (np.sum(v_samp)+np.sum(r_samp)+np.sum(n_samp))/(len(v_samp)+len(r_samp)+len(n_samp))
            str_att[attempts] =(np.sum(v_samp)+np.sum(r_samp)+np.mean(strat_l)*len(n_low)+np.mean(strat_h)*len(n_high))/(len(v_samp)+len(r_samp)+len(n_samp))
            bot_att[attempts] =(np.sum(v_samp)+np.sum(r_samp)+np.mean(both_l)*len(n_low)+np.mean(both_h)*len(n_high))/(len(v_samp)+len(r_samp)+len(n_samp))

        # This just tells the progress bar to progress.
        bar.next()
        # Calculate the mean of the mean square error of all of the attempts for
        # both estimation methods.
        strats[indn,indr]=np.mean((truths-str_att)**2)
        boths[indn,indr]=np.mean((truths-bot_att)**2)

# Tells the progress bar that it's done.
bar.finish()

# Create a 2d grid with x and y values, corresponsing to the non-response and
# remotely sense percentages that we simulated.
X,Y = np.meshgrid(non_pcts, rem_pcts)
# Save this to a file (that is not human readable, because I didn't want to deal
# with saving a 3d array to a file).
np.save(file_path_prefix+state+"_simulated_"+str(strat_pct)+".npy", [X,Y,strats,boths])

##########
# The following section plots the distributions for the three populations just
# to show and be able to explain what we're doing
##########

# This gets the probability estimate for canopy cover from 0-100% for each of
# the three populations
x = np.linspace(0,100)
v = np.exp(kdv.score_samples(x.reshape(-1,1)))
r = np.exp(kdr.score_samples(x.reshape(-1,1)))
n = np.exp(kdn.score_samples(x.reshape(-1,1)))

# Generate data for the explanatory plots that follow
v_samp = sampler(kdv, 1000)
r_samp = sampler(kdr, 1000)
n_samp = sampler(kdn, 1000)

# These next three code blocks plot a histogram of the true plot distribution, a
# histogram of the newly sampled plot distribution, and a line showing the
# estimated probability density (kde). This is done for each of the three
# populations (visited, remote, non-response)
bin = 40
plt.hist(visit, bins=bin,density=True)
plt.hist(v_samp, bins=bin,density=True, alpha=0.5)
plt.plot(x,v)
plt.xlabel('Percent Canopy Cover')
plt.ylabel('Probability Density')
plt.title('Distribution of Canopy Cover\nfor Visited Plots in '+state)
plt.savefig(file_path_prefix+state+'_dist_Vis.png', bbox_inches='tight',dpi=300)
plt.close()

plt.hist(remote, bins=bin,density=True)
plt.hist(r_samp, bins=bin,density=True, alpha=0.5)
plt.plot(x,r)
plt.xlabel('Percent Canopy Cover')
plt.ylabel('Probability Density')
plt.title('Distribution of Canopy Cover\nfor Remote Plots in '+state)
plt.savefig(file_path_prefix+state+'_dist_Rem.png', bbox_inches='tight',dpi=300)
plt.close()

plt.hist(non, bins=bin,density=True)
plt.hist(n_samp, bins=bin,density=True, alpha=0.5)
plt.plot(x,n)
plt.xlabel('Percent Canopy Cover')
plt.ylabel('Probability Density')
plt.title('Distribution of Canopy Cover\nfor Non-Response Plots in '+state)
plt.savefig(file_path_prefix+state+'_dist_Non.png', bbox_inches='tight',dpi=300)
plt.close()
