#! /usr/bin/env py

# Python imports
import os
import logging

# Module imports
import matplotlib.pyplot as plt
import h5py

# Local imports
from src import solve_system, Optimiser

logger = logging.getLogger(__file__)


def main():
    """Main script for solving the system."""

    # Iterates over a range of temperatures to observe thermoregulation effects
    inputs = {"thermal_system": {"t_cr": 38}}
    bps = [(100, 70), (120, 80), (150, 120)]
    sol_list = []
    for sys, dia in bps:
        logger.info(f"Optimising for a blood pressure of: {sys}/{dia}")
        opt = Optimiser(inputs=inputs, budget=100, num_workers=8)
        sol_list.append(solve_system(**opt.run(sbp=sys, dbp=dia)))

    # Effect on Tricuspid valve flow
    for k, key in enumerate(
            ("Systemic Artery Pressure", "Tricuspid Valve Flow")
    ):

        plt.subplot(2, 1, k + 1)
        var = key.split(" ")[-1]
        match var.lower():
            case "pressure":
                unit = "(mmHg)"
            case "flow":
                unit = "(ml/s)"
            case "volume":
                unit = "(ml)"
            case "status":
                unit = ""
            case "elastance":
                unit = "(mmHg/ml)"

        for i, sol in enumerate(sol_list):
            plt.plot(
                sol['Time (s)'],
                sol[key],
                label=f"{bps[i]}",
            )
        plt.xlabel("Time (s)")
        plt.ylabel(f"{var} {unit}")
        plt.title(f"{key} with varrying blood pressure")
        plt.legend()
    plt.show()

    # Save the data to hdf5 file
    file_name = os.path.join(
        os.getcwd(), "scripts", "optimisation_output.hdf5"
    )
    with h5py.File(file_name, "w") as _:
        pass
    with h5py.File(file_name, "a") as f:
        for i, sol in enumerate(sol_list):
            grp = f.create_group(str(bps[i]))
            for key in list(sol.keys()):
                grp.create_dataset(key, data=sol[key])


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARNING)
    main()
