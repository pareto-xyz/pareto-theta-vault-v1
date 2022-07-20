"""
Make a plot using linear model over a wider range.
"""
import json
import numpy as np
import matplotlib.pyplot as plt


def main(args):
    with open(args.model_file, 'r') as fp:
        model = json.load(fp)

    def predictor(x):
        w1, w2 = model['coef_']
        b = model['intercept_']
        return w1 * x[:, 0] + w2 * x[:, 1] + b

    x, y = np.meshgrid( 
        np.linspace(0.5, 3.00, 100),
        np.linspace(0.5, 0.99, 100),
    )
    inputs = np.vstack([x.flatten(), y.flatten()]).T
    preds = predictor(inputs)

    # Make a new heatmap for new predictions
    z_preds = preds.reshape(x.shape[0], y.shape[1])
    z_min, z_max = np.abs(z_preds).min(), np.abs(z_preds).max()

    c = plt.imshow(
        z_preds,
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
    plt.title("Extrapolated fees for different parameters \n" + r'Drift = 1, 7 days, 1H $d\tau$')
    plt.savefig(args.save_file)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('model_file')
    parser.add_argument('save_file')
    args = parser.parse_args()

    main(args)