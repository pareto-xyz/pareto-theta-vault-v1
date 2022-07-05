# Test closed form solution to swap amounts for rebalancing.
# Author: Mike Wu, Pareto Labs

import math
import cvxpy as cp
import numpy as np
from tqdm import tqdm


def closed_form_solution(
    risky0,                 # amount of risky at start
    stable0,                # amount of stable at start
    risky_per_lp,           # between 0 and 1
    stable_per_lp,          # between 0 and 1
    risky_to_stable_price,  # oracle price for risky in stable token
):  
    """
    Solve for risky1 and stable1, the allocations of risky and stable tokens
    that are achievable via trades at price `risky_to_stable_price` and also
    satisfy the constraint `stable_per_lp * risky1 = risky_per_lp * stable1`
    that doubles as optimality conditions for LP-ing in a RMM-01 pool.

    The closed form expression is derived as the intersection of two 
    hyperplanes (or lines in 2D).

    Returns
    -------
    risky1: float - allocation to risky asset
    stable1: float - allocation to stable asset
    remainder: float - value remaining (and uncaptured) from swaps 
    """
    value0 = risky_to_stable_price * risky0 + stable0
    denominator = risky_per_lp * risky_to_stable_price + stable_per_lp

    risky1 = (risky_per_lp * value0) / denominator
    stable1 = (stable_per_lp * value0) / denominator

    # check the constraints
    value1 = risky_to_stable_price * risky1 + stable1
    assert risky1 >= 0 and stable1 >= 0, "x >= 0 constraint broken"
    assert math.isclose(
        stable_per_lp * risky1, risky_per_lp * stable1, abs_tol=0.001
    ), "Cx = d constraint broken"
    assert value1 <= value0, "Ax <= b constraint broken"

    return risky1, stable1, value1 - value0


def linear_program_solution(
    risky0,                 # amount of risky at start
    stable0,                # amount of stable at start
    risky_per_lp,           # between 0 and 1
    stable_per_lp,          # between 0 and 1
    risky_to_stable_price,  # oracle price for risky in stable token
):
    """
    Solve for risky1 and stable1 using cvxpy. This function is primarily 
    used as a way to double check the closed-form solution, as it is near
    impractical to deploy an optimization technique efficiently on Ethereum.

    Returns
    -------
    risky1: float - allocation to risky asset
    stable1: float - allocation to stable asset
    remainder: float - value remaining (and uncaptured) from swaps 
    """
    x = cp.Variable(2)
    x0 = np.array([risky0, stable0])
    A = np.array([risky_to_stable_price, 1])
    C = np.array([stable_per_lp, -risky_per_lp])
    value0 = A.T @ x0

    objective = cp.Maximize(A.T @ x)
    constraints = [
        x >= 0, 
        C.T @ x == 0,
        A.T @ x <= value0,
    ]
    prob = cp.Problem(objective, constraints)
    prob.solve(solver=cp.ECOS)

    x1 = np.array(x.value)
    value1 = A.T @ x1
    assert x1[0] >= 0 and x1[1] >= 0, "x >= 0 constraint broken"
    assert math.isclose(C.T @ x1, 0, abs_tol=0.001), \
        "Cx = d constraint broken"
    assert value1 <= value0, "Ax <= b constraint broken"

    return x1[0], x1[1], value1 - value0


def make_simulation(rs=None):
    """
    Randomly generate input values and pass to both closed-form and the 
    linear program to solve.
    """
    if rs is None:
        rs = np.random.RandomState(42)

    risky0 = rs.uniform(low=1000, high=10000)
    stable0 = rs.uniform(low=1000, high=10000)
    risky_per_lp = rs.rand()
    stable_per_lp = rs.rand()
    risky_to_stable_price = rs.uniform(low=1, high=1000)

    cvxpy_outputs = linear_program_solution(
        risky0,
        stable0,
        risky_per_lp,
        stable_per_lp,
        risky_to_stable_price,
    )
    our_outputs = closed_form_solution(
        risky0,
        stable0,
        risky_per_lp,
        stable_per_lp,
        risky_to_stable_price,
    )

    cvxpy_risky, cvxpy_stable, _ = cvxpy_outputs
    our_risky, our_stable, _ = our_outputs

    # decent amount of leeway here
    assert math.isclose(cvxpy_risky, our_risky, abs_tol=0.1)
    assert math.isclose(cvxpy_stable, our_stable, abs_tol=0.1)


if __name__ == "__main__":
    rs = np.random.RandomState(42)

    num_fail = 0
    for _ in tqdm(range(1000)):
        try:
            make_simulation(rs=rs)
        except:
            num_fail += 1

    pp = round(float(1000 - num_fail) / 1000. * 100, 1)
    print(f'Success rate: {1000-num_fail} out of 1000 ({pp}%)')
