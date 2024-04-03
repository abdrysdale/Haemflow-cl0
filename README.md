# Closed Loop Lumped

This a 0D cardiovascular model for the venous and arterial systems based of Korakianitis and Shi's 2006 paper "A concentrated parameter model for the human cardiovascular system including heart valve dynamics and atrioventricular interaction".

The model is implemented in Fortran but supplied with a Python wrapper.

## Notable Changes From Korakianitis and Shi

- Able to supply heart elastance curves based on ECG timings.
- Thermoregulation model adjusts systemic capillary resistance based of core and skin temperature.
- Packaged with an (multi-objective) optimiser to optimise for stroke volume, systolic and diastolic blood pressure, total arterial resistance and total peripheral compliance.
- Able to specify heart volume from age, weight, height and sex.

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

There are example scripts in `scripts/`, run it to test everything works.

```sh
python thermoregulation_example.py
```

### Docker/Singularity run script

1. Clone this repository:

```sh
git clone git@gitlab.com:abdrysdale/closed_loop_lumped.git
```

2. Build the container.

```sh
chmod +x run.sh
./run.sh -b
```

3. Run the code.

There are example scripts in `scripts/` but to test everything works, run the main script:

```sh
./run.sh src/cl0.py
```

alternatively to run the Fortran code directly:

```sh
./run.sh -e ./closed_loop_lumped
```

If you don't wish to use the `run.sh` script, inspect its contents to see the default docker/singularity commands.


## Usage

This module provides the functions:

- `solve_system`
- `solve_system_parallel`
- `load_defaults`
- `load_default_params`

Along with an optimisation class:
- `Optimiser`

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
    left_ventricle={'vmin': 20, 'vmax': 150} # Sets the minimum and maximum volume
    thermal_system={'k_dil': 0, 'k_con': 0}, # Disables thermoregulation
    )
```

Heart volume can be specified by height, weight, age and sex
```python
sol = solve_system(
    generic_params={
        'est_h_vol': True,
        'height': 160,  # Height (cm)
        'weight': 80,   # Weight (kg)
        'age': 32,      # Age (years)
        'sex': 1,       # Sex (1 for female, 0 for male)
    }
)
```

Note that setting 'est_h_vol' to 'True' in the above enables the calculation of the heart volume from
height, weight, age and sex. If heart chamber volumes are specified, they will be overwritten by the
estimated heart volume.

For instance:
```python
sol_1 = solve_system(
    generic_params={
        'est_h_vol': True,
        'height': 160,  # Height (cm)
        'weight': 80,   # Weight (kg)
        'age': 32,      # Age (years)
        'sex': 1,       # Sex (1 for female, 0 for male)
    }
    )
    
sol_2 = solve_system(
    generic_params={
        'est_h_vol': True,
        'height': 160,  # Height (cm)
        'weight': 80,   # Weight (kg)
        'age': 32,      # Age (years)
        'sex': 1,       # Sex (1 for female, 0 for male)
    left_ventricle={'vmin': 20, 'vmax': 150} # Sets the minimum and maximum volume
    }
    )

# sol_1 and sol_2 will yield exactly the same result.
```

Some points to consider if using the heart volume estimations:

- The heart volume estimation is based off mostly white Europeans. If data from other ethnicities becomes available I will update the heart volume estimation ASAP.
- The heart volume is typically over estimated as the estimator was tuned for 2D measurements.
- The heart volume estimation is based off healthy participants and will not be accurate for people with heart defects or abnormalities.
- The original data includes no trans people so may not be accurate for trans people.
- Right ventricle volume estimation is not provided and estimated from the other chamber volume estimation.
- For more information on the implementation, see the `update_heart_vol` subroutine in `src/elastance.f90`.
- For more information on the heart volume estimation see https://doi.org/10.1161/CIRCIMAGING.113.000690

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

`load_default_params` provides the default parameters to use for optimisation.

Each parameter to be optimised is provided with a minimum, maximum and initial value.

The `Optimiser`, is used to tune the network to yield certain physiological responses which can be any of:

- Systolic blood pressure (`sbp`).
- Diastolic blood pressure (`dbp`).
- Cardiac Output (`co`).
- Stroke Volume (`sv`).
- Total peripheral resistance (`tpr`).
- Total arterial compliance (`tac`).

Any optimiser included with [nevergrad](https://facebookresearch.github.io/nevergrad/index.html) should work fine.

When using multiple objectives, it is recommended to use a multi-objective optimisation algorithm.
A good choice for this problem is the `TwoPointsDE` algorithm due to the cheap computational cost of the 
solver.

When using a multi-objective optimiser, the Pareto frontier is returned rather than the single best result.

A full example script highlighting this is [scripts/optimisation_from_db_example.py](scripts/optimisation_from_db_example.py)
which performs multi-objective optimisation for each row in a SQLite database.

```python
from src import Optimiser, solve_system

hr = 89         # Heart Rate in BPM

pr = 0.142      # PR interval (s)
qrs = 0.08      # QRS interval (s)
qt = 0.38       # QT interval (s)

core = 37.48    # Core temperature (°C)
core_ref = 36.8 # Reference core temperature (°C)
skin = 24.23    # Skin temperature (°C)
skin_ref = 34.1 # Reference skin temperature (°C)

# These inputs will be fixed for the optimisation.
inputs = {
    'generic_params': {
        'period': 60/hr,
    },
    'ecg': {
        "t1": pr / 3,
        "t2": pr + qrs/2,
        "t3": pr + qrs + 0.75 * (qt - qrs),
        "t4": pr + qt,
    },
    'thermal_system': {
        't_cr': core,
        't_cr_ref': core_ref,
        't_sk': skin,
        't_sk_ref': skin_ref,
    },
}

# These inputs will be allowed to change for the optimisation.
params = {
    "generic_params": {
        "r_scale": [0.1, 10, 1],
        "c_scale": [0.1, 10, 1],
        'e_scale': [0.25, 4, 1],
    },
    "thermal_system": {
        "k_dil": [37, 113, 75],
        "k_con": [0.25, 0.75, 0.5],
    },
}

# Sets up the optimiser
opt = Optimiser(
    optimiser="TwoPointsDE",
    inputs=inputs,
    params=params,
    budget=1000,
    num_workers=16,
    multi_objective=True,   # This flag is really important!
    tol=1e-3,
    pbar=True,              # This shows a progress bar for the optimisation.
    pbar_pos=1,             # The position of the progress bar can be specified with this option.
)

# Runs the optimiser optimising for stroke volume, diastolic blood pressure and systolic blood pressure
best_params = opt.run(sbp=133, dbp=67, sv=49)

# best_params will be a list of the input parameters on the Pareto frontier.
print(best_params)

# This can also be accessed with:
print(opt.flat_inputs_raw)  # For a list of flattened dictionaries.
print(opt.recommendation)   # For a list of nested dictionaries.
```

```python
from src import Optimiser, solve_system

opt = Optimiser(
    optimiser="NGOpt", # Nevergrad optimiser string
    inputs={"thermal_system": {"t_cr": 38}}, # Inputs passed to the solver.
    params={"thermal_system": {"k_con": [0.25, 0.75, 0.5]}}, # [lower, upper, initial] parameter values
    pbar=True, # Displays a progress bar
    tol=1e-3, # Tolerance for early stopping
    budget=100, # These keyword arguments are passed directly to the optimiser
    num_workers=16, # Specifying num_workers > 1 automatically enables parallelisation
)

best_inputs = opt.run(
    sbp=120,    # Systolic blood pressure (mmHg)
    dbp=80,     # Diastolic blood pressure (mmHg)
    co=4,       # Cardiac Output (L/min)
    sv=60,      # Stroke volume (mL)
)
# As tpr and tac are not specified, they won't be used in the optimisation.
# A minimum of 1 metric is needed for optimisation.

# To get the optimised solution, run
sol = solve_system(**best_inputs)
```

### Default Values

#### load_defaults

The parameters are split into 13 sections, each with its own dictionary.
These are:

- `"generic_params"`
- `"ecg"`
- `"left_ventricle"`
- `"left_atrium"`
- `"right_ventricle"`
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
        "nstep": 2000,          # Number of time steps.
        "period": 0.9,          # Cardiac period.
        "ncycle": 10,           # Number of cardiac cycles, only last is returned.
        "rk": 4,                # Runge-Kutta order (2 or 4).
        "rho": 1.06,            # Density of blood.
        "est_h_vol": True,      # Whether to estimate heart volume
        "height": 160,          # Height (cm)
        "weight": 80,           # Weight (kg)
        "age": 32,              # Age (years)
        "sex": 1,               # Sex (0 for male, 1 for female)
        "e_scale": 1,           # Scales all heart elastance
        "v_scale": 1,           # Scales all heart volume.
        "r_scale": 1,           # Scales all resistances.
        "c_scale": 1,           # Scales all compliances.
    }

    ecg = {
        "t1": 0,        # Time of P wave peak.
        "t2": 0.142,    # Time of R wave peak.
        "t3": 0.462,    # Time of T wave peak.
        "t4": 0.522,    # Time of end of T wave.
    }

    left_ventricle = {
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

    right_ventricle = {
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
