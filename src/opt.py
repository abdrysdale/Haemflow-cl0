#! /usr/bin/env python
"""Optimiser script for the 0D closed loop solver"""

# Python imports
import logging
from typing import Optional
from collections.abc import MutableMapping
from concurrent import futures

# Module imports
import numpy as np
import nevergrad as ng
from tqdm import tqdm

# Local imports
from src import solve_system
from src.cl0 import _format_solver_inputs

logger = logging.getLogger(__name__)


def _flatten_dict(
        d: MutableMapping, parent_key: str = '', sep: str = '.'
) -> MutableMapping:
    """Takes a nested dictionary and returns a flattened year.

    Args:
        d (dict) : A nested dictionary.
        parent_key (str) : Key of the parent dictionary.
        sep (str, optional) : Separator to use for the flattened dictionary.
                Defaults to '.'.
    """
    items = []
    for k, v in d.items():
        new_key = parent_key + sep + k if parent_key else k
        if isinstance(v, MutableMapping):
            items.extend(_flatten_dict(v, parent_key=new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)


def _unflatten_dict(dictionary: dict, sep: str = '.') -> dict:
    """Unflattens a dictionary into a nested dictionary.

    Args:
        dictionary (dict) : Flattened dictionary.
        sep (str, optional) : Separator for the flattened dictionary.
    """
    rtn_dict = dict()
    for key, value in dictionary.items():
        parts = key.split(".")
        d = rtn_dict
        for part in parts[:-1]:
            if part not in d:
                d[part] = dict()
            d = d[part]
        d[parts[-1]] = value
    return rtn_dict


def load_default_params() -> dict:
    """Loads the default parameters for tuning.

    The default parameters is pretty much all of the parameters.
    It is HIGHLY recommended that you use this is a guide to see what
    optimisation parameters are available rather than as a sensible
    default. For example, all of the value parameters are included in
    the optimisation which isn't recommended.

    It's recommended that you decide what parameters you are interested in
    and restrict as much as possible to reduce the dimensionality of the
    minimisation problem.
    """

    generic_params = {}

    ecg = {}

    left_ventrical = {
        "emin": [0.05, 0.15, 0.1],
        "emax": [0.25, 0.75, 0.5],
        "vmin": [5, 15, 10],
        "vmax": [67, 203, 135],
    }

    left_atrium = {
        "emin": [0.07, 0.23, 0.15],
        "emax": [0.12, 0.38, 0.25],
        "vmin": [1, 5, 3],
        "vmax": [13, 41, 27],
    }

    right_ventrical = {
        "emin": [0.05, 0.15, 0.1],
        "emax": [0.46, 1.38, 0.92],
        "vmin": [27, 83, 55],
        "vmax": [90, 270, 180],
    }

    right_atrium = {
        "emin": [0.07, 0.23, 0.15],
        "emax": [0.12, 0.38, 0.25],
        "vmin": [8, 26, 17],
        "vmax": [20, 60, 40],
    }

    systemic = {
        "scale_R": [0.35, 1.05, 0.7],
        "scale_C": [0.4, 1.2, 0.8],
    }

    pulmonary = {
        "scale_R": [0.5, 1.5, 1],
        "scale_C": [0.5, 1.5, 1],
    }

    aortic_valve = {
        "aeffmax": [1, 3, 2],
        "kvc": [0.006, 0.018, 0.012],
        "kvo": [0.006, 0.018, 0.012],
    }

    mitral_valve = {
        "aeffmax": [4, 12, 7.7],
        "kvc": [0.015, 0.045, 0.03],
        "kvo": [0.02, 0.08, 0.04],
    }

    pulmonary_valve = {
        "aeffmax": [2, 7.5, 5],
        "kvc": [0.006, 0.018, 0.012],
        "kvo": [0.006, 0.018, 0.012],
    }

    tricuspid_valve = {
        "aeffmax": [4, 12, 8],
        "kvc": [0.015, 0.045, 0.03],
        "kvo": [0.02, 0.08, 0.04],
    }

    thermal_system = {
        "q_sk_basal": [3, 10, 6.3],
        "k_dil": [37, 113, 75],
        "k_con": [0.25, 0.75, 0.5],
    }

    defaults = {
        "generic_params": generic_params,
        "ecg": ecg,
        "left_ventrical": left_ventrical,
        "left_atrium": left_atrium,
        "right_ventrical": right_ventrical,
        "right_atrium": right_atrium,
        "systemic": systemic,
        "pulmonary": pulmonary,
        "aortic_valve": aortic_valve,
        "mitral_valve": mitral_valve,
        "pulmonary_valve": pulmonary_valve,
        "tricuspid_valve": tricuspid_valve,
        "thermal_system": thermal_system,
    }

    return defaults


class Optimiser:

    def __init__(
            self,
            optimiser: Optional[str] = None,
            inputs: Optional[dict] = None,
            params: Optional[dict] = None,
            pbar: bool = True,
            pbar_pos: int = 0,
            tol: float = 0.0,
            **kwargs,
    ):
        """Initialises the optimiser

        All unrecognised keyword arguments are passed to the optimser.

        Args:
                optimiser (str, optional) : Nevergrad optimiser to use.
                        If None (default), will use "NGOpt"
                inputs (dict, optional) : Static inputs in the same format as
                        passed to solve_system.
                params (dict, otpional) : Parameters to optimise for, same
                        format as passed to solve system. True will consider
                        the parameter for optimisation, False will disable
                        optimisation for that parameter.  If a list is provided
                        first item will be taken as lower, second as upper and
                        third as initial parameter guess.
                pbar (bool, optional) : If True will display a progress bar.
                        Defaults to True.
                pbar_pos (int, optional) : Position of the progress bar.
                        Defaults to 0.
                tol (float, optional) : Percentage tolerance for the optimiser.
                        Defaults to 0.0,
        """

        self.flat_inputs_raw = _flatten_dict(inputs)
        inputs = dict() if inputs is None else inputs
        self.inputs = _format_solver_inputs(**inputs)
        self.flat_inputs = _flatten_dict(self.inputs)

        # Loads the default parameters
        params = params if params is not None else load_default_params()
        self.opt_params = dict()
        limits = ('lower', 'upper', 'init')
        for key, value in _flatten_dict(params).items():
            scalar_kwargs = dict()
            if hasattr(value, '__len__'):
                for i, val in enumerate(value):
                    scalar_kwargs[limits[i]] = val

            self.opt_params[key] = ng.p.Scalar(**scalar_kwargs)

        # Sets up optimiser
        opt = optimiser if optimiser is not None else "NGOpt"
        if opt not in ng.optimizers.registry.keys():
            logger.critical(f"{optimiser} not found in nevergrad registry.")
            logger.debug(
                "Currently supported optimisers:\n"
                f"{ng.optimizers.registry.keys()}"
            )
            raise NotImplementedError(
                "Optimiser not found in nevergrad registry"
            )
        instrum = ng.p.Instrumentation(**self.opt_params)
        self.optimiser = ng.optimizers.registry[opt](
            parametrization=instrum, **kwargs,
        )

        # If 'num_workers' > 1 then switch to optimisation to parallel mode
        self.parallel = bool(kwargs.get("num_workers", 1) - 1)

        # Registers early stopping (if tolerance > 0)
        if tol > 0:
            early_stopping = ng.callbacks.EarlyStopping(
                lambda opt: opt.current_bests["minimum"].mean < tol
            )
            self.optimiser.register_callback("ask", early_stopping)

        # Registers progress bar
        self.loss = np.inf
        if pbar:
            pbar = tqdm(total=kwargs.get("budget", None), position=pbar_pos)

            def _update_pbar(*args, **kwargs):
                pbar.update(1)
                pbar.set_description(f"Tol: {self.loss:.3f}")

            self.optimiser.register_callback("tell", _update_pbar)

        # Placeholder for recommendation
        self.recommendation = None

    def solve_system(self, **flat_params) -> dict:
        """Solves the system.

        Essentially, wraps around the Fortran solver code and returns the
        solution dictionary.

        For more information about the solver, look at the function:
        solve_system in cl0 (closed-loop-0D) module.
        """
        flat_inputs = self.flat_inputs
        for key, value in flat_params.items():
            flat_inputs[key] = value
        params = _unflatten_dict(flat_inputs)
        return solve_system(**params)

    def get_systemic_sysdia_pres(self, sol: dict) -> tuple:
        """Returns the systemic systolic  and diastolic pressure.

        Args:
            sol (dict) : Solution dictionary - output from cl0.solve_system.

        Returns:
            (sys, dia) : Systemic systolic and diastolic pressure in mmHg.
        """
        sys = np.max(sol["Systemic Artery Pressure"])
        dia = np.min(sol["Systemic Artery Pressure"])
        return (sys, dia)

    def get_cardiac_output(self, sol: dict) -> float:
        """Returns the cardiac output.

        Args:
            sol (dict) : Solution dictionary - output from cl0.solve_system.

        Returns:
            co (float) : Cardiac output in L/min.
        """
        co = (
            1000 * np.sum(sol["Aortic Valve Flow"])
            * 60 / (sol['Time (s)'][-1] - sol['Time (s)'][0])
        )
        return co

    def get_stroke_volume(self, sol: dict) -> float:
        """Returns the stroke volume

        Args:
            sol (dict) : Solution dictionary - output from cl0.solve_system.

        Returns:
            sv (float) : Stroke volume in mL.
        """
        dt = np.diff(sol['Time (s)'])
        dt = np.concatenate((np.zeros(1) + dt[0], dt))
        return np.sum(sol["Aortic Valve Flow"] * dt)

    def get_total_peripheral_resistance(self, sol: dict) -> float:
        """Returns the total peripheral resistance.

        TPR = MAP / CO

        TPR = Total peripheral resistance.
        MAP = Mean arterial pressure.
        CO = Cardiac Output.

        Args:
            sol (dict) : Solution dictionary - output from cl0.solve_system.
        Returns:
            tpr (float) : Total peripheral resistance (in Ohms).
        """
        co = self.get_cardiac_output(sol)
        _map = np.mean(sol['Systemic Artery Pressure'])
        return _map / co

    def get_total_arterial_compliance(self, sol: dict) -> float:
        """Returns the total arterial compliance.

        TAC = SV / (SYS - DIA)

        TAC = Total arterial compliance.
        SV = Stroke Volume (mL).
        SYS = Systemic systolic blood pressure (mmHg).
        DIA = Systemic diastolic blood pressure (mmHg).

        Args:
            sol (dict) : Solution dictionary - output from cl0.solve_system.
        Returns:
            tac (float) : Total arterial compliance.
        """
        sv = self.get_stroke_volume(sol)
        sys, dia = self.get_systemic_sysdia_pres(sol)
        return (sv / (sys - dia))

    def run(
            self,
            sbp: Optional[float] = None,
            dbp: Optional[float] = None,
            co: Optional[float] = None,
            sv: Optional[float] = None,
            tpr: Optional[float] = None,
            tac: Optional[float] = None,
            **kwargs
    ) -> dict:
        """Runs the optimiser.

        All other keyword arguments are passed to the optimiser.

        Args:
                sbp (float, optional) : Systemic artery systolic pressure in
                        mmHg. If None, will not be included in optimisation.
                        Defaults  to None.
                dbp (float, optional) : Systemic artery diastolic pressure
                        in mmHg. If None, will not be included in optimisation.
                        Defaults to None.
                co (float, optional) : Cardiac output (L/min).
                        If None, will not be included in optimisation.
                        Defaults to None.
                sv (float, optional) : Stroke volume (mL).
                        If None, will not be included in optimisation.
                        Defaults to None.
                tpr (float, optional) : Total peripheral resistance.
                        If None, will not be included in optimisation.
                        Defaults to None.
                tac (float, optional) : Total arterial compliance.
                        If None, will not be included in optimisation.
                        Defaults to None.
        """

        logger.info(
            f"Optimisation started with {self.optimiser.dimension} parameters."
        )

        if not any([
                False if m is None else True for m in
                (sbp, dbp, co, sv, tpr, tac)
        ]):
            logger.critical("You haven't set anything to optimise for?!\n")
            raise ValueError('No optimisation criteria specified.')

        if co is not None and sv is not None:
            logger.warning(
                "You have set to optimise for both stroke volume and cardiac "
                "output. These two metrics are related.\n"
                "I'll assume you want to do this "
                "and you know what you're doing."
            )

        # Minimisation function
        def minimise(*args, **kwargs):
            sol = self.solve_system(*args, **kwargs)

            loss = 0

            # Systemic Systolic and Diastolic Blood Pressure
            if sbp is not None or dbp is not None:
                sys, dia = self.get_systemic_sysdia_pres(sol)
                if sbp is not None:
                    loss += np.abs(sys - sbp) / sbp
                if dbp is not None:
                    loss += np.abs(dia - dbp) / dbp

            # Cardiac Output
            if co is not None:
                cardiac_output = self.get_cardiac_output(sol)
                loss += np.abs(cardiac_output - co) / co

            # Stroke Volume
            if sv is not None:
                stroke_volume = self.get_stroke_volume(sol)
                loss += np.abs(stroke_volume - sv) / sv

            # Total peripheral resistance
            if tpr is not None:
                total_peripheral_R = self.get_total_peripheral_resistance(sol)
                loss += np.abs(total_peripheral_R - tpr) / tpr

            # Total arterial compliance
            if tac is not None:
                total_arterial_C = self.get_total_arterial_compliance(sol)
                loss += np.abs(total_arterial_C - tac) / tac

            self.loss = loss

            return loss

        # Optimisation
        # Whether to run parallel or not is determined if num_workers > 1.
        # Which is specified during initialisation.
        if self.parallel:
            with futures.ThreadPoolExecutor(
                    max_workers=self.optimiser.num_workers
            ) as executor:
                recommendation = self.optimiser.minimize(
                    minimise, executor=executor, batch_mode=False, **kwargs
                )
        else:
            recommendation = self.optimiser.minimize(minimise, **kwargs)

        self.recommendation = dict(recommendation[1].value.items())
        logger.info(self.recommendation)

        # Recombines optimised values into a full parameter dictionary
        full_recommendation = self.flat_inputs
        for key in list(self.recommendation.keys()):
            full_recommendation[key] = self.recommendation[key]
        return _unflatten_dict(full_recommendation)
