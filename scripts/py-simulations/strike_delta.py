# Test formula for deriving strike given fixed delta compared to 
# iterative solution used by Ribbon-v2.
# See: https://github.com/ribbon-finance/ribbon-v2/blob/master/contracts/utils/DeltaStrikeSelection.sol
# Author: Mike Wu, Pareto Labs

import math
import numpy as np
from tqdm import tqdm
from scipy.stats import norm  # for inverse cdf 


def closed_form_solution(delta, spot, sigma, tau):
    logit = tau * sigma**2 / 2. - sigma * np.sqrt(tau) * norm.ppf(delta)
    strike = float(spot * np.exp(logit))
    _delta = get_black_scholes_delta(strike, spot, sigma, tau)
    return strike, float(_delta)


def iterative_solution(delta, spot, sigma, tau, step = 100):
    """
    Clone of Ribbon v2's `_getStrikePrice` function converted to python.
    """
    strike = spot + (step - spot % step) + step
    target_delta = delta
    prev_delta = 1

    while True: 
        # use Black Scholes to derive beliefs on delta
        curr_delta = get_black_scholes_delta(strike, spot, sigma, tau)

        if (target_delta <= prev_delta) and (target_delta >= curr_delta):
            final_delta = _get_best_delta(prev_delta, curr_delta, target_delta)
            final_strike = _get_best_strike(final_delta, prev_delta, strike, step)

            return float(final_strike), float(final_delta)

        # prep for next iteration
        strike = strike + step
        prev_delta = curr_delta;


def _get_best_delta(prev_delta, curr_delta, target_delta):
    lower_bound = target_delta - curr_delta
    upper_bound = prev_delta - target_delta
    final_delta = curr_delta if (lower_bound <= upper_bound) else prev_delta
    return final_delta


def _get_best_strike(final_delta, prev_delta, strike, step):
    if (final_delta != prev_delta):
        return strike
    return strike - step


def get_black_scholes_delta(strike, spot, sigma, tau):
    vol = sigma * np.sqrt(tau)
    d1 = (np.log(spot / strike) + tau * sigma**2 / 2.) / vol
    delta = norm.cdf(d1)
    return float(delta)


def make_simulation(rs=None, tol=1e-3):
    """
    Randomly generate input values and pass to both the formula and iterative
    approach to compare answers.
    """
    if rs is None:
        rs = np.random.RandomState(42)

    delta = rs.uniform(low=0, high=1)
    spot = rs.uniform(low=1000, high=10000)
    sigma = rs.uniform(low=0, high=1)
    tau = rs.uniform(low=1000, high=10000)

    our_strike, our_delta = closed_form_solution(delta, spot, sigma, tau)
    iter_strike, iter_delta = iterative_solution(delta, spot, sigma, tau)

    outcome = math.isclose(our_strike, iter_strike, abs_tol=1)

    return {
        'success': outcome,
        'data': {
            'iter': {'strike': iter_strike, 'delta': iter_delta},
            'ours': {'strike': our_strike, 'delta': our_delta},
        }
    }


if __name__ == "__main__":
    rs = np.random.RandomState(42)

    num_fail = 0
    for _ in tqdm(range(1000)):
        results = make_simulation(rs=rs, tol=0.01)

        if not results['success']:
            num_fail += 1

    pp = round(float(1000 - num_fail) / 1000. * 100, 1)
    print(f'Success rate: {1000-num_fail} out of 1000 ({pp}%)')
