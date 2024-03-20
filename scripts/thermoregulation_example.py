#! /usr/bin/env py

# Python imports
import os
import sys
import logging

# Module imports
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
    param_list = [{"thermal_system": {"t_cr": x/100}} for x in range(3730, 3760, 5)]
    sol_list = solve_system_parallel(param_list)

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
                label=f"{param_list[i]['thermal_system']['t_cr']}°C",
            )
        plt.xlabel("Time (s)")
        plt.ylabel(f"{var} {unit}")
        plt.title(f"{key} with varrying core temperature")
        plt.legend()
    plt.show()

    # Save the data to hdf5 file
    file_name = os.path.join(
        os.getcwd(), "scripts", "thermoregulation_output.hdf5"
    )
    with h5py.File(file_name, "w") as _:
        pass
    with h5py.File(file_name, "a") as f:
        for i, sol in enumerate(sol_list):
            grp = f.create_group(str(param_list[i]['thermal_system']['t_cr']))
            for key in list(sol.keys()):
                grp.create_dataset(key, data=sol[key])


if __name__ == "__main__":
    main()
