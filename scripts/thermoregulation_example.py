#! /usr/bin/env py

# Python imports
import os
import sys
import logging

# Module imports
import matplotlib as mpl
import matplotlib.pyplot as plt
import h5py

# Local imports
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
from src import solve_system_parallel

logger = logging.getLogger(__file__)


def main():
    """Main script for solving the system."""

    # Iterates over a range of temperatures to observe thermoregulation effects
    for variable in ('t_cr', 't_sk'):

        t_min, t_max, step = (36.8, 37.8, 0.1) if variable == 't_cr' else (24, 34, 1)

        t_list = [
            x / 100
            for x in range(
                    int(t_min * 100), int(t_max * 100), int(step * 100)
            )
        ]
        t_min = min(t_list)
        t_max = max(t_list)
        param_list = [
            {"thermal_system": {variable: x}} for x in t_list
        ]

        sol_list = solve_system_parallel(param_list)

        # Effect on Tricuspid valve flow
        t_key = 'Time (s)'
        for key in sol_list[0].keys():
            if key == t_key:
                continue

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

            # Setting up a colormap that's a simple transtion
            mymap = mpl.colors.LinearSegmentedColormap.from_list(
                'mycolors', ['blue', 'red'],
            )

            # Using contourf to provide my colorbar info, then clearing the figure
            CS3 = plt.contourf([[0, 0], [0, 0]], t_list, cmap=mymap)
            plt.clf()

            for i, sol in enumerate(sol_list):
                z = param_list[i]['thermal_system'][variable]
                r = (float(z) - t_min)/(t_max - t_min)
                g = 0
                b = 1 - r
                plt.plot(
                    sol[t_key],
                    sol[key],
                    color=(r, g, b),
                )
            plt.colorbar(
                CS3,
                ax=plt.gca(),
            )
            plt.xlabel(t_key)
            plt.ylabel(f"{var} {unit}")
            plt.title((
                f"{key} with varrying "
                f"{'core' if variable == 't_cr' else 'skin'} temperature"
            ))
            plt.savefig(f"analysis/figures/varried_{variable}_{key.replace(' ', '_')}.png")

        # Save the data to hdf5 file
        file_name = os.path.join(
            os.getcwd(), "scripts", f"thermoregulation_{variable}_output.hdf5"
        )
        with h5py.File(file_name, "w") as _:
            pass
        with h5py.File(file_name, "a") as f:
            for i, sol in enumerate(sol_list):
                grp = f.create_group(str(param_list[i]['thermal_system'][variable]))
                for key in list(sol.keys()):
                    grp.create_dataset(key, data=sol[key])



if __name__ == "__main__":
    main()
