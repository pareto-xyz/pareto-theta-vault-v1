"""
Arbitrage function
"""

import scipy
import numpy as np
from scipy import optimize

EPSILON = 1e-8


def arbitrageExactly(market_price, pool):
    """
    Arbitrage the difference *exactly* at the time of the call to the function.
    Uses results from the following paper: https://arxiv.org/abs/2012.08040

    Params:

    reference_price (float):
        the reference price of the risky asset, denominated in the riskless asset
    Pool (AMM object):
        an AMM object, for example a CoveredCallAMM class, with some current state and reserves
    """
    gamma = 1 - pool.fee
    R1 = pool.reserves_risky
    R2 = pool.reserves_riskless
    K = pool.K
    k = pool.invariant
    sigma = pool.sigma
    tau = pool.tau

    # Marginal price of selling epsilon risky
    # price_sell_risky = gamma*K*norm.pdf(norm.ppf(1 - R1) - sigma*np.sqrt(tau))*quantilePrime(1 - R1)
    price_sell_risky = pool.getMarginalPriceSwapRiskyIn(0)
    # Marginal price of buying epsilon risky
    price_buy_risky = pool.getMarginalPriceSwapRisklessIn(0)

    # Market price
    m = market_price

    # If the risky reserves are almost empty
    if R1 < EPSILON:
        return
    # or if the riskless reserves are almost empty
    elif R2 < EPSILON or (K + k - R2) / gamma < EPSILON:
        return

    # or if the risky reserves are almost full
    elif 1 - R1 < EPSILON:
        return

    # or if the riskless reserves are almost full
    elif K - R2 < EPSILON:
        return

    # In any of the above cases, we do nothing, this ensures that the bracketing for the root finding will always test a positive amount in.

    # If the price of selling epsilon of the risky asset is above the market price, we buy the optimal amount of the risky asset on the market and immediately sell it on the CFMM = **swap amount in risky**.
    elif price_sell_risky > m + 1e-8:
        # Solve for the optimal amount in
        def func(amount_in):
            return pool.getMarginalPriceSwapRiskyIn(amount_in) - m

        # If the sign is the same for the bounds of the possible trades, this means that the arbitrager can empty the pool while maximizing his profit (the profit may still be negative, even though maximum)
        if (np.sign(func(EPSILON)) != np.sign(func(1 - R1 - EPSILON))):
            optimal_trade = scipy.optimize.brentq(func, EPSILON, 1 - R1 - EPSILON)
        else:
            optimal_trade = 1 - R1
        assert optimal_trade >= 0
        amount_out, _ = pool.virtualSwapAmountInRisky(optimal_trade)
        # The amount of the riskless asset we get after making the swap must be higher than the value in the riskless asset at which we obtained the amount in on the market
        profit = amount_out - optimal_trade * m
        if profit > 0:
            _, _ = pool.swapAmountInRisky(optimal_trade)

    # If the price of buying epsilon of the risky asset is below the market price, we buy the optimal amount of the risky asset in the CFMM and immediately sell it on the market = **swap amount in riskless** in the CFMM.
    elif price_buy_risky < m - 1e-8:
        def func(amount_in):
            return m - pool.getMarginalPriceSwapRisklessIn(amount_in)

        # If the sign is the same for the bounds of the possible trades, this means that the arbitrager can empty the pool while maximizing his profit (the profit may still be negative, even though maximum)
        if (np.sign(func(EPSILON)) != np.sign(func((K + k - R2) / gamma - EPSILON))):
            optimal_trade = scipy.optimize.brentq(func, EPSILON, (K + k - R2) / gamma - EPSILON)
        else:
            optimal_trade = K - R2
        assert optimal_trade >= 0
        amount_out, _ = pool.virtualSwapAmountInRiskless(optimal_trade)
        # The amount of risky asset we get out times the market price must result in an amount of riskless asset higher than what we initially put in the CFMM
        profit = amount_out * m - optimal_trade
        if profit > 0:
            _, _ = pool.swapAmountInRiskless(optimal_trade)
