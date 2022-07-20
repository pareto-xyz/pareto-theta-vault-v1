import json
import matplotlib.pyplot as plt
import numpy as np


def main(args):
    with open(args.results_file) as fp:
        data = json.load(fp)
        parameters = data['parameters']
        optimal_fees = data['optimal_fees']

    x = parameters[0]
    y = parameters[2]

    x, y = np.meshgrid(x, y)
    z = np.array(optimal_fees)[:, 0, :]
    z_min, z_max = np.abs(z).min(), np.abs(z).max()

    c = plt.imshow(
        z,
        cmap='Blues',
        vmin=z_min,
        vmax=z_max,
        extent=[x.min(), x.max(), y.min(), y.max()],
        interpolation='nearest', 
        origin='lower', 
        aspect='auto'
    )

    plt.colorbar(c)
    plt.xlabel("Volatility")
    plt.ylabel("Initial price as fraction of strike")
    plt.title("Optimal fees for different parameters \n" + r'Drift = 1, 7 days, 1H $d\tau$')
    plt.savefig(args.save_file)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('results_file')
    parser.add_argument('save_file')
    args = parser.parse_args()

    main(args)
