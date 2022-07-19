import json
import time 
import numpy as np
from tqdm import tqdm
from pathlib import Path
from datetime import datetime
from rmms import optimize_fee

# Script used to map a tuple of (volatility, drift, strike price) to the optial
# fee to choose for the pool, i.e. the fee that minimizes the max of the mean 
# square error and the terminal square error. 

# Currently for the case of 30 days to maturity with 1 hour tau update / arbitrage 
# intervals.

# Initial time to maturity in years
INITIAL_TAU = 0.0191781 #7 days
# Time horizon of the GBM in years
TIME_HORIZON = 0.0191781 #7 days
# Time step size of the GBM in years =
# tau update frequency = arbitrage frequency
TIME_STEPS_SIZE = 0.000114155 #1 hours
# Arbitrary strike price, what matters is the difference between 
# initial price and strike price
STRIKE = 2000

# Array storing set of parameters to explore: volatility, drift, 
# initial price distance from strike price*
# *for example if the strike priced is K, a parameter of 0.8 will
# start the simulation with an initial price of 0.8*K

min_vol = 0.5
max_vol = 2.0
min_drift = 1
max_drift = 1
min_distance = 0.5
max_distance = 2.0
N_vol = 20
N_drift = 1
N_distance = 20

parameters = [
    np.linspace(min_vol, max_vol, N_vol),
    np.linspace(min_drift, max_drift, N_drift),
    np.linspace(min_distance, max_distance, N_distance)
]
optimal_fee_array = [
    [
        [0 for i in range(len(parameters[2]))] for i in range(len(parameters[1]))
    ] for i in range(len(parameters[0]))
]

start = time.time()
pbar = tqdm(
    total=len(parameters[0])*len(parameters[1])*len(parameters[2]),
    position=0,
    leave=True,
)
for i in range(len(parameters[0])): 
    for j in range(len(parameters[1])):
        for m in range(len(parameters[2])):
            volatility = parameters[0][i]
            drift = parameters[1][j]
            strike_proportion = parameters[2][m]
            initial_price = STRIKE*strike_proportion

            optimal_fee = optimize_fee.findOptimalFee(
                INITIAL_TAU,
                TIME_STEPS_SIZE,
                TIME_HORIZON,
                volatility,
                drift,
                STRIKE,
                STRIKE * strike_proportion,
            )
            optimal_fee_array[i][j][m] = optimal_fee

            pbar.set_postfix({
                'sigma': volatility,
                'drift': drift,
                'strike': strike_proportion,
                'fee': optimal_fee,
                'time': time.time() - start,
            })
            pbar.update()
pbar.close()

data = {}
data['parameters'] = [
    parameters[0].tolist(),
    parameters[1].tolist(),
    parameters[2].tolist(),
]
data['optimal_fees'] = optimal_fee_array
now = datetime.now()
dt_string = now.strftime("%d-%m-%Y_%H-%M-%S")
filename = 'optimization_results_'+ dt_string + '.dat'
Path('optimization_results').mkdir(parents=True, exist_ok=True)

with open('optimization_results/'+filename, 'w+') as f:
    json.dump(data, f)
