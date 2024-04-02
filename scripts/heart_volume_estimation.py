#! /usr/bin/env python
"""Explores the relationship between various heart volume parameters."""

# Python imports
import logging

# Module imports
import matplotlib as mpl
import matplotlib.pyplot as plt

# Local imports
from src import solve_system_parallel

logger = logging.getLogger(__file__)


def main():
    """Main script for sensitivity analysis"""

    # Iterates over a range of heart volume variables
    vars = {
        "height": range(120, 180, 5),
        "weight": range(40, 120, 5),
        "age": range(20, 90, 5),
        "sex": (0, 1),
    }

    for variable in vars.keys():

        v_list = vars[variable]

        param_list = [
            {"generic_params": {variable: x}} for x in v_list
        ]

        sol_list = solve_system_parallel(param_list)

        match variable.lower():
            case "height":
                v_unit = "(cm)"
            case "weight":
                v_unit = "(kg)"
            case "age":
                v_unit = "(years)"
            case _:
                v_unit = ""

        # Effect on all parameters
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
            CS3 = plt.contourf([[0, 0], [0, 0]], v_list, cmap=mymap)
            plt.clf()

            for i, sol in enumerate(sol_list):
                z = param_list[i]['generic_params'][variable]
                r = (float(z) - min(v_list))/(max(v_list) - min(v_list))
                g = 0
                b = 1 - r
                plt.plot(
                    sol[t_key],
                    sol[key],
                    color=(r, g, b),
                    label=str(z)
                )

            if len(v_list) > 2:
                plt.colorbar(
                    CS3,
                    ax=plt.gca(),
                    label=f"{variable.title()} {v_unit}",
                )
            else:
                plt.legend(title=variable.title())
            plt.xlabel(t_key)
            plt.ylabel(f"{var} {unit}")
            plt.title((f"{key} with varying {variable}"))
            plt.savefig(
                f"analysis/figures/varried_{variable}_{key.replace(' ', '_')}"
                ".png"
            )


if __name__ == '__main__':
    main()
