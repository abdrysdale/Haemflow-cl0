# Closed Loop Lumped

This a 0D cardiovascular model for the venous and arterial systems based of Korakianitis and Shi's 2006 paper "A concentrated parameter model for the human cardiovascular system including heart valve dynamics and atrioventricular interaction".

The model is implemented in Fortran but supplied with a Python wrapper.

## Notable Changes From Korakianitis and Shi

- Able to supply heart elastance curves based on ECG timings.
- Thermoregulation model adjusts systemic capillary resistance based of core and skin temperature.

## Installation

1. Clone this repository:

```sh
git clone git@gitlab.com:abdrysdale/closed_loop_lumped.git
```

2. Build the Fortran library.

```sh
./build.sh lib
```

`build.sh` without any arguments simply builds the Fortran executable, `lib` is used to specify to build the library.

3. Install dependencies.

Dependencies can be found in `shell.nix`, if you use [nix](https://nixos.org/), simply type `nix-shell`.

4. Run the example.

There is an example script in `scripts/`, run it to test everything works.

```sh
python thermoregulation_example.py
```

## Usage

This module provides three functions, `solve_system`, `solve_system_parallel` and `load_defaults`.

`load_defaults` loads the default parameter values in the correct format, if you would like to have a look at default parameters, run the `load_defaults` function.

If a parameter is not specified, it loads the default value.

```python
from src import load_defaults, solve_system

# If a parameter isn't specified, the defaults are loaded.
# Thus method 1 and method 2 have the same result.

# Method 1
params = load_defaults()
sol = solve_system(*params)

# Method 2
sol = solve_system()
```

Single, or multiple, parameters can be changed by passing part or all of the corresponding
parameter dictionary.

```python
sol = solve_system(
    generic_params={'period': 1}, # Cardiac period of 1s (60bpm)
    left_ventrical={'vmin': 20, 'vmax': 150} # Sets the minimum and maximum volume
    thermal_system={'k_dil': 0, 'k_con': 0}, # Disables thermoregulation
    )
```

`solve_system_parallel` provides a wrapper around the `solve_system` function but launches processes in parallel.

It expects a parameter list as an argument, whereby each item in the list is unpacked to the `solve_system` function, along with a `num_workers` which is the maximum number of processes to use.

As an example:

```python

# Method 1
param_list = [{"thermal_system": {"t_cr": x}} for x in range(34, 41)]
sol_list = solve_system_parallel(param_list)

# Method 2
sol_list = []
for t_cr in range(34, 41):
    sol_list.append(solve_system("thermal_system"={"t_cr": t_cr}))
    
# Methods 1 and 2 are identical in results but method 1 operates in parallel.
```


### Default Values

The parameters are split into 13 sections, each with its own dictionary.
These are:

- `"generic_params"`
- `"ecg"`
- `"left_ventrical"`
- `"left_atrium"`
- `"right_ventrical"`
- `"right_atrium"`
- `"systemic"`
- `"pulmonary"`
- `"aortic_valve"`
- `"mitral_valve"`
- `"pulmonary_valve"`
- `"tricuspid_valve"`
- `"thermal_system"`

The default values are as follows:

```python
    generic_params = {
        "nstep": 2000,  # Number of time steps.
        "period": 0.9,  # Cardiac period.
        "ncycle": 10,   # Number of cardiac cycles, only last is returned.
        "rk": 4,        # Runge-Kutta order (2 or 4).
        "rho": 1.06,    # Density of blood.
    }

    ecg = {
        "t1": 0,        # Time of P wave peak.
        "t2": 0.142,    # Time of R wave peak.
        "t3": 0.462,    # Time of T wave peak.
        "t4": 0.522,    # Time of end of T wave.
    }

    left_ventrical = {
        "emin": 0.1,    # Minimum elastance.
        "emax": 0.5,    # Maximum elastance.
        "vmin": 10,     # Minimum volume.
        "vmax": 135,    # Maximum volume.
    }

    left_atrium = {
        "emin": 0.15,
        "emax": 0.25,
        "vmin": 3,
        "vmax": 27,
    }

    right_ventrical = {
        "emin": 0.1,
        "emax": 0.92,
        "vmin": 55,
        "vmax": 180,
    }

    right_atrium = {
        "emin": 0.15,
        "emax": 0.25,
        "vmin": 17,
        "vmax": 40,
    }

    systemic = {
        "pini": 80,             # Initial pressure.
        "scale_R": 0.7,         # Resistance scaling term.
        "scale_C": 0.8,         # Compliance scaling term.
        "ras": 0.003,           # Aortic sinus resistance.
        "rat": 0.05,            # Artery resistance.
        "rar": 0.5,             # Arterioes resistance.
        "rcp": 0.52,            # Capillary resistance.
        "rvn": 0.075,           # Venous resistance.
        "cas": 0.008,           # Aortic sinus resistance.
        "cat": 1.6,             # Artery compliance.
        "cvn": 20.5,            # Venous compliance.
        "las": 6.2e-5,          # Aortic sinus inductance.
        "lat": 1.7e-3,          # Artery Inductance.
    }

    pulmonary = {
        "pini": 20,             # Initial pressure.
        "scale_R": 1,           # Resistance scaling term.
        "scale_C": 1,           # Compliance scaling term.
        "ras": 0.002,           # Pulmonary artery resistance.
        "rat": 0.01,            # Artery resistance.
        "rar": 0.05,            # Arterioes resistance.
        "rcp": 0.25,            # Capillary resistance.
        "rvn": 0.006,           # Venous resistance.
        "cas": 0.18,            # Pulmonary artery resistance.
        "cat": 3.8,             # Artery compliance.
        "cvn": 20.5,            # Venous compliance.
        "las": 5.2e-5,          # Pulmonary artery inductance.
        "lat": 1.7e-3,          # Artery Inductance.
    }

    aortic_valve = {
        "leff": 1,              # Effective inductance of the valve.
        "aeffmin": 1e-10,       # Minimum effective area of the valve.
        "aeffmax": 2,           # Maximum effective area of the valve.
        "kvc": 0.012,           # Valve closing paramater.
        "kvo": 0.012,           # Valve opening parameter.
    }

    mitral_valve = {
        "leff": 1,
        "aeffmin": 1e-10,
        "aeffmax": 7.7,
        "kvc": 0.03,
        "kvo": 0.04,
    }

    pulmonary_valve = {
        "leff": 1,
        "aeffmin": 1e-10,
        "aeffmax": 5,
        "kvc": 0.012,
        "kvo": 0.012,
    }

    tricuspid_valve = {
        "leff": 1,
        "aeffmin": 1e-10,
        "aeffmax": 8,
        "kvc": 0.03,
        "kvo": 0.04,
    }

    thermal_system = {
        "q_sk_basal": 6.3,      # Basal skin blood flow under neutral conditions (kg/m^2/hr)
        "k_dil": 75,            # Coefficient of vasodilation
        "t_cr": 36.8,           # Core temperature
        "t_cr_ref": 36.8,       # Core temperature under neutral conditions
        "k_con": 0.5,           # Coefficient of vasoconstriction
        "t_sk": 34.1,           # Skin temperature
        "t_sk_ref": 34.1,       # Skin temperature under neutral conditions
    }
```
