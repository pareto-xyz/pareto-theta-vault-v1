"""
Fit a linear regressor on top of the fee simulation data.
"""
import json
import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression


def main(args):
    with open(args.results_file) as fp:
        data = json.load(fp)
        parameters = data['parameters']
        optimal_fees = data['optimal_fees']

    x, y = np.meshgrid(parameters[0], parameters[2])
    z = np.array(optimal_fees)[:, 0, :]

    inputs = np.vstack([x.flatten(), y.flatten()]).T
    targets = z.flatten()[..., np.newaxis]

    model = LinearRegression()
    model.fit(inputs, targets)

    output = {
        'coef_': [float(v) for v in model.coef_[0]], 
        'intercept_': float(model.intercept_[0]),
    }
    with open(args.save_file, 'w') as fp:
        json.dump(output, fp)

    def predictor(x):
        w1, w2 = output['coef_']
        b = output['intercept_']
        return w1 * x[:, 0] + w2 * x[:, 1] + b

    preds = predictor(inputs)
    assert np.sum(preds != model.predict(inputs)[:, 0]) == 0, \
        "Unexpected prediction"

    shape = int(np.sqrt(preds.shape[0]))
    z_preds = preds.reshape(shape, shape)
    z_preds = np.maximum(z_preds, np.zeros_like(z_preds))
    z_min, z_max = np.abs(z).min(), np.abs(z).max()

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
    plt.title("Reconstructed fees for different parameters \n" + r'Drift = 1, 7 days, 1H $d\tau$')
    plt.savefig(args.image_file)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('results_file')
    parser.add_argument('save_file')
    parser.add_argument('image_file')
    args = parser.parse_args()

    main(args)