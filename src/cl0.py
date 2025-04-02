#! /usr/bin/env python
"""Wrapper for 0D closed loop solver in Fortran"""

# Python imports
import os
import ctypes as ct
import logging
from typing import Optional
import multiprocessing as mp

# Module imports
import numpy as np
import numpy.typing as npt

logger = logging.getLogger(__name__)

fortlib = ct.CDLL(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), 'closed_loop_lumped.so')
)


def load_defaults():
    """Loads all of the default dictionaries for solving the system."""

    generic_params = {
        "nstep": 2000,          # Number of time steps.
        "period": 0.9,          # Cardiac period.
        "ncycle": 10,           # Number of cardiac cycles, only last is returned
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
        "rar": 0.5,             # Arterioles resistance.
        "rcp": 0.52,            # Capillary resistance.
        "rvn": 0.075,           # Venous resistance.
        "cas": 0.008,           # Aortic sinus compliance.
        "cat": 1.6,             # Artery compliance.
        "cvn": 20.5,            # Venous compliance.
        "las": 6.2e-5,          # Aortic sinus inductance.
        "lat": 1.7e-3,          # Artery inductance.
    }

    pulmonary = {
        "pini": 20,             # Initial pressure.
        "scale_R": 1,           # Resistance scaling term.
        "scale_C": 1,           # Compliance scaling term.
        "ras": 0.002,           # Pulmonary artery sinus resistance.
        "rat": 0.01,            # Artery resistance.
        "rar": 0.05,            # Arterioles resistance.
        "rcp": 0.25,            # Capillary resistance.
        "rvn": 0.006,           # Venous resistance.
        "cas": 0.18,            # Pulmonary artery compliance.
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

    defaults = {
        "generic_params": generic_params,
        "ecg": ecg,
        "left_ventricle": left_ventricle,
        "left_atrium": left_atrium,
        "right_ventricle": right_ventricle,
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


def _format_solver_inputs(
        generic_params: Optional[dict] = None,
        ecg: Optional[dict] = None,
        left_ventricle: Optional[dict] = None,
        left_atrium: Optional[dict] = None,
        right_ventricle: Optional[dict] = None,
        right_atrium: Optional[dict] = None,
        systemic: Optional[dict] = None,
        pulmonary: Optional[dict] = None,
        aortic_valve: Optional[dict] = None,
        mitral_valve: Optional[dict] = None,
        pulmonary_valve: Optional[dict] = None,
        tricuspid_valve: Optional[dict] = None,
        thermal_system: Optional[dict] = None,
):
    input_dicts = {
        "generic_params": generic_params,
        "ecg": ecg,
        "left_ventricle": left_ventricle,
        "left_atrium": left_atrium,
        "right_ventricle": right_ventricle,
        "right_atrium": right_atrium,
        "systemic": systemic,
        "pulmonary": pulmonary,
        "aortic_valve": aortic_valve,
        "mitral_valve": mitral_valve,
        "pulmonary_valve": pulmonary_valve,
        "tricuspid_valve": tricuspid_valve,
        "thermal_system": thermal_system,
    }

    # Checks all input parameters, if a parameter is missing, load the default
    defaults = load_defaults()
    inputs = dict()
    for idict in list(input_dicts.keys()):
        if input_dicts[idict] is None:
            inputs[idict] = defaults[idict]
            logger.debug(
                f"Parameter dictionary {idict} not supplied, loading default."
            )
        else:
            tmp_dict = dict()
            for key in list(input_dicts[idict].keys()):
                if key not in list(defaults[idict].keys()):
                    logger.warning(
                        f"Key {key} not recognised and will be ignored."
                    )

            for key in list(defaults[idict].keys()):
                tmp_dict[key] = input_dicts[idict].get(key, defaults[idict][key])

                if key not in list(input_dicts[idict].keys()):
                    logger.debug(
                        f"{idict}: {key} not supplied, loading default."
                    )
            inputs[idict] = tmp_dict

    #####################
    # Warnings for user #
    #####################
    if (inputs["generic_params"]["est_h_vol"] and (
            inputs["left_atrium"]["vmin"] != defaults["left_atrium"]["vmin"] or
            inputs["left_atrium"]["vmax"] != defaults["left_atrium"]["vmax"] or
            inputs["left_ventricle"]["vmin"] != defaults["left_ventricle"]["vmin"] or
            inputs["left_ventricle"]["vmax"] != defaults["left_ventricle"]["vmax"] or
            inputs["right_atrium"]["vmin"] != defaults["right_atrium"]["vmin"] or
            inputs["right_atrium"]["vmax"] != defaults["right_atrium"]["vmax"] or
            inputs["right_ventricle"]["vmin"] != defaults["right_ventricle"]["vmin"] or
            inputs["right_ventricle"]["vmax"] != defaults["right_ventricle"]["vmax"]
    )):
        logger.warning(
            "You have manually set a heart chamber volume "
            "and specified to estimate the heart volume.\n"
            "The specified heart chamber volume will be overwritten by the estimate.\n"
            "If you do not want this, set est_h_vol to False."
        )

    return inputs


def solve_system(
        generic_params: Optional[dict] = None,
        ecg: Optional[dict] = None,
        left_ventricle: Optional[dict] = None,
        left_atrium: Optional[dict] = None,
        right_ventricle: Optional[dict] = None,
        right_atrium: Optional[dict] = None,
        systemic: Optional[dict] = None,
        pulmonary: Optional[dict] = None,
        aortic_valve: Optional[dict] = None,
        mitral_valve: Optional[dict] = None,
        pulmonary_valve: Optional[dict] = None,
        tricuspid_valve: Optional[dict] = None,
        thermal_system: Optional[dict] = None,
) -> npt.NDArray[np.float64]:
    """Solves the lumped parameter closed loop system.

    If any of the dictionaries or keys are not provided or any keys default values will be used.

    Args:
    generic_params (dict, optional) : A dictionary containing: 'nstep' (number of time steps),
        'ncycle' (number of cardiac cycles), 'rk' (Runge-Kutta order - either 2 or 4),
        'period' (cardiac period in seconds) and 'rho' (density of blood).
    ecg (dict, optional) : A dictionary containing: 't1' (location of the P peak),
        't2' (location of the R peak), 't3' (location of the T peak)
        and 't4' (location of the end of the T peak - also called T offset).
    left_ventricle (dict, optional) : A dictionary containing 'emin' (minimum elastance),
        'emax' (maximum elastance), 'vmin' (minimum volume) and 'vmax' (maximum volume).
    left_atrium (dict, optional) : A dictionary containing 'emin' (minimum elastance),
        'emax' (maximum elastance), 'vmin' (minimum volume) and 'vmax' (maximum volume)
    right_ventricle (dict, optional) : A dictionary containing 'emin' (minimum elastance),
        'emax' (maximum elastance), 'vmin' (minimum volume) and 'vmax' (maximum volume)..
    right_atrium (dict, optional) : A dictionary containing 'emin' (minimum elastance),
        'emax' (maximum elastance), 'vmin' (minimum volume) and 'vmax' (maximum volume).
    systemic (dict, optional) : A dictionary containing: 'pini' (initial pressure),
        'ras' (aortic sinus resistance), 'rat' (artery resistance),
        'rar' (arterioles resistance), 'rcp' (capillary resistance),
        'rvn' (venous resistance), 'cas' (aortic sinus compliance),
        'cat' (artery compliance), 'cvn' (venous compliance),
        'las' (aortic sinus inductance) and 'lat' (artery inductance).
    pulmonary (dict, optional) : A dictionary containing: 'pini' (initial pressure),
        'ras' (pulmonary sinus resistance), 'rat' (artery resistance),
        'rar' (arterioles resistance), 'rcp' (capillary resistance),
        'rvn' (venous resistance), 'cas' (pulmonary sinus compliance),
        'cat' (artery compliance), 'cvn' (venous compliance),
        'las' (pulmonary sinus inductance) and 'lat' (artery inductance).
    aortic_valve (dict, optional) : A dictionary containing:
        'leff' (effective inductance), 'aeffmin' (minimum effective area),
        'aeffmax' (maximum effective area), 'kvc' (valve closing parameter),
        'kvo' (valve opening parameter).
    mitral_valve (dict, optional) : A dictionary containing:
        'leff' (effective inductance), 'aeffmin' (minimum effective area),
        'aeffmax' (maximum effective area), 'kvc' (valve closing parameter),
        'kvo' (valve opening parameter).
    pulmonary_valve (dict, optional) : A dictionary containing:
        'leff' (effective inductance), 'aeffmin' (minimum effective area),
        'aeffmax' (maximum effective area), 'kvc' (valve closing parameter),
        'kvo' (valve opening parameter).
    tricuspid_valve (dict, optional) : A dictionary containing:
        'leff' (effective inductance), 'aeffmin' (minimum effective area),
        'aeffmax' (maximum effective area), 'kvc' (valve closing parameter),
        'kvo' (valve opening parameter).
    thermal_system (dict, optional) : A dictionary containing:
        'k_dil' (vasodilation coefficient), 't_cr' (core temperature),
        't_cr_ref' (core temperature under neutral conditions),
        'k_con' (vasoconstriction coefficient), 't_sk' (skin temperature),
        't_sk_ref' (skin temperature under neutral condtions).
    Returns:
        sol (dict) : A dictionary of all of the solutions for system.
    """

    ###############
    # Load inputs #
    ###############
    inputs = _format_solver_inputs(
        generic_params, ecg,
        left_ventricle, left_atrium, right_ventricle, right_atrium,
        systemic, pulmonary,
        aortic_valve, mitral_valve, pulmonary_valve, tricuspid_valve,
        thermal_system,
    )

    logger.info(f"Solving system with the following parameters:\n{inputs}\n")

    ####################
    # Formats the data #
    ####################

    # Generic parameters
    nstep = ct.c_int(inputs["generic_params"]["nstep"])
    period = ct.c_double(inputs["generic_params"]["period"])
    ncycle = ct.c_int(inputs["generic_params"]["ncycle"])
    ncycle = ct.c_int(inputs["generic_params"]["ncycle"])
    rk = ct.c_int(inputs["generic_params"]["rk"])
    est_h_vol = ct.c_bool(inputs["generic_params"]["est_h_vol"])
    height = ct.c_double(inputs["generic_params"]["height"])
    weight = ct.c_double(inputs["generic_params"]["weight"])
    age = ct.c_double(inputs["generic_params"]["age"])
    sex = ct.c_double(inputs["generic_params"]["sex"])
    rho = ct.c_double(inputs["generic_params"]["rho"])
    e_scale = inputs["generic_params"]["e_scale"]
    v_scale = inputs["generic_params"]["v_scale"]
    r_scale = inputs["generic_params"]["r_scale"]
    c_scale = inputs["generic_params"]["c_scale"]

    # Left ventricle
    lv_emin = ct.c_double(inputs["left_ventricle"]["emin"] * e_scale)
    lv_emax = ct.c_double(inputs["left_ventricle"]["emax"] * e_scale)
    lv_v01 = ct.c_double(inputs["left_ventricle"]["vmin"] * v_scale)
    lv_v02 = ct.c_double(inputs["left_ventricle"]["vmax"] * v_scale)

    # Left atrium
    la_emin = ct.c_double(inputs["left_atrium"]["emin"] * e_scale)
    la_emax = ct.c_double(inputs["left_atrium"]["emax"] * e_scale)
    la_v01 = ct.c_double(inputs["left_atrium"]["vmin"] * v_scale)
    la_v02 = ct.c_double(inputs["left_atrium"]["vmax"] * v_scale)

    # Right ventricle
    rv_emin = ct.c_double(inputs["right_ventricle"]["emin"] * e_scale)
    rv_emax = ct.c_double(inputs["right_ventricle"]["emax"] * e_scale)
    rv_v01 = ct.c_double(inputs["right_ventricle"]["vmin"] * v_scale)
    rv_v02 = ct.c_double(inputs["right_ventricle"]["vmax"] * v_scale)

    # Right atrium
    ra_emin = ct.c_double(inputs["right_atrium"]["emin"] * e_scale)
    ra_emax = ct.c_double(inputs["right_atrium"]["emax"] * e_scale)
    ra_v01 = ct.c_double(inputs["right_atrium"]["vmin"] * v_scale)
    ra_v02 = ct.c_double(inputs["right_atrium"]["vmax"] * v_scale)

    # Systemic system
    pini_sys = ct.c_double(inputs["systemic"]["pini"])
    scale_Rsys = ct.c_double(inputs["systemic"]["scale_R"] * r_scale)
    scale_Csys = ct.c_double(inputs["systemic"]["scale_C"] * c_scale)

    sys_ras = ct.c_double(inputs["systemic"]["ras"])
    sys_rat = ct.c_double(inputs["systemic"]["rat"])
    sys_rar = ct.c_double(inputs["systemic"]["rar"])
    sys_rcp = ct.c_double(inputs["systemic"]["rcp"])
    sys_rvn = ct.c_double(inputs["systemic"]["rvn"])

    sys_cas = ct.c_double(inputs["systemic"]["cas"])
    sys_cat = ct.c_double(inputs["systemic"]["cat"])
    sys_cvn = ct.c_double(inputs["systemic"]["cvn"])
    sys_las = ct.c_double(inputs["systemic"]["las"])
    sys_lat = ct.c_double(inputs["systemic"]["lat"])

    # Pulmonary system
    pini_pulm = ct.c_double(inputs["pulmonary"]["pini"])
    scale_Rpulm = ct.c_double(inputs["pulmonary"]["scale_R"] * r_scale)
    scale_Cpulm = ct.c_double(inputs["pulmonary"]["scale_C"] * c_scale)

    pulm_ras = ct.c_double(inputs["pulmonary"]["ras"])
    pulm_rat = ct.c_double(inputs["pulmonary"]["rat"])
    pulm_rar = ct.c_double(inputs["pulmonary"]["rar"])
    pulm_rcp = ct.c_double(inputs["pulmonary"]["rcp"])
    pulm_rvn = ct.c_double(inputs["pulmonary"]["rvn"])

    pulm_cas = ct.c_double(inputs["pulmonary"]["cas"])
    pulm_cat = ct.c_double(inputs["pulmonary"]["cat"])
    pulm_cvn = ct.c_double(inputs["pulmonary"]["cvn"])
    pulm_las = ct.c_double(inputs["pulmonary"]["las"])
    pulm_lat = ct.c_double(inputs["pulmonary"]["lat"])

    # Aortic Valve
    av_leff = ct.c_double(inputs["aortic_valve"]["leff"])
    av_aeffmin = ct.c_double(inputs["aortic_valve"]["aeffmin"])
    av_aeffmax = ct.c_double(inputs["aortic_valve"]["aeffmax"])
    av_kvc = ct.c_double(inputs["aortic_valve"]["kvc"])
    av_kvo = ct.c_double(inputs["aortic_valve"]["kvo"])

    # Mitral Valve
    mv_leff = ct.c_double(inputs["mitral_valve"]["leff"])
    mv_aeffmin = ct.c_double(inputs["mitral_valve"]["aeffmin"])
    mv_aeffmax = ct.c_double(inputs["mitral_valve"]["aeffmax"])
    mv_kvc = ct.c_double(inputs["mitral_valve"]["kvc"])
    mv_kvo = ct.c_double(inputs["mitral_valve"]["kvo"])

    # Pulmonary Valve
    pv_leff = ct.c_double(inputs["pulmonary_valve"]["leff"])
    pv_aeffmin = ct.c_double(inputs["pulmonary_valve"]["aeffmin"])
    pv_aeffmax = ct.c_double(inputs["pulmonary_valve"]["aeffmax"])
    pv_kvc = ct.c_double(inputs["pulmonary_valve"]["kvc"])
    pv_kvo = ct.c_double(inputs["pulmonary_valve"]["kvo"])

    # Tricuspid Valve
    tv_leff = ct.c_double(inputs["tricuspid_valve"]["leff"])
    tv_aeffmin = ct.c_double(inputs["tricuspid_valve"]["aeffmin"])
    tv_aeffmax = ct.c_double(inputs["tricuspid_valve"]["aeffmax"])
    tv_kvc = ct.c_double(inputs["tricuspid_valve"]["kvc"])
    tv_kvo = ct.c_double(inputs["tricuspid_valve"]["kvo"])

    # ECG timings
    t1 = ct.c_double(inputs["ecg"]["t1"])
    t2 = ct.c_double(inputs["ecg"]["t2"])
    t3 = ct.c_double(inputs["ecg"]["t3"])
    t4 = ct.c_double(inputs["ecg"]["t4"])

    # Thermal system
    q_sk_basal = ct.c_double(inputs["thermal_system"]["q_sk_basal"])
    k_dil = ct.c_double(inputs["thermal_system"]["k_dil"])
    t_cr = ct.c_double(inputs["thermal_system"]["t_cr"])
    t_cr_ref = ct.c_double(inputs["thermal_system"]["t_cr_ref"])
    k_con = ct.c_double(inputs["thermal_system"]["k_con"])
    t_sk = ct.c_double(inputs["thermal_system"]["t_sk"])
    t_sk_ref = ct.c_double(inputs["thermal_system"]["t_sk_ref"])

    # Solution
    sol_out = np.zeros(
        (31, inputs["generic_params"]["nstep"]),
        order='F',
        dtype=np.float64,
    )

    ################
    # Solve system #
    ################
    fortlib.solve_system(
        nstep, period, ncycle, rk, rho,
        lv_emin, lv_emax, lv_v01, lv_v02,
        la_emin, la_emax, la_v01, la_v02,
        rv_emin, rv_emax, rv_v01, rv_v02,
        ra_emin, ra_emax, ra_v01, ra_v02,
        est_h_vol, height, weight, age, sex,
        pini_sys, scale_Rsys, scale_Csys,
        sys_ras, sys_rat, sys_rar, sys_rcp, sys_rvn,
        sys_cas, sys_cat, sys_cvn, sys_las, sys_lat,
        pini_pulm, scale_Rpulm, scale_Cpulm,
        pulm_ras, pulm_rat, pulm_rar, pulm_rcp, pulm_rvn,
        pulm_cas, pulm_cat, pulm_cvn, pulm_las, pulm_lat,
        av_leff, av_aeffmin, av_aeffmax, av_kvc, av_kvo,
        mv_leff, mv_aeffmin, mv_aeffmax, mv_kvc, mv_kvo,
        pv_leff, pv_aeffmin, pv_aeffmax, pv_kvc, pv_kvo,
        tv_leff, tv_aeffmin, tv_aeffmax, tv_kvc, tv_kvo,
        t1, t2, t3, t4,
        q_sk_basal, k_dil, t_cr, t_cr_ref, k_con, t_sk, t_sk_ref,
        sol_out.ctypes.data_as(ct.POINTER(ct.c_double)),
    )

    sol = {
        'Aortic Valve Flow': sol_out[0, :],
        'Sinus Flow': sol_out[1, :],
        'Aortic Flow': sol_out[2, :],
        'Tricuspid Valve Flow': sol_out[3, :],
        'Pulmonary Valve Flow': sol_out[4, :],
        'Arterial Flow': sol_out[5, :],
        'Aterioles Flow': sol_out[6, :],
        'Mitral Valve Flow': sol_out[7, :],
        'Systemic Sinus Pressure': sol_out[8, :],
        'Systemic Artery Pressure': sol_out[9, :],
        'Systemic Venous Pressure': sol_out[10, :],
        'Pulmonary Sinus Pressure': sol_out[11, :],
        'Pulmonary Artery Pressure': sol_out[12, :],
        'Pulmonary Venous Pressure': sol_out[13, :],
        'Left Ventricular Volume': sol_out[14, :],
        'Left Atrial Volume': sol_out[15, :],
        'Right Ventricular Volume': sol_out[16, :],
        'Right Atrial Volume': sol_out[17, :],
        'Aortic Valve Status': sol_out[18, :],
        'Mitral Valve Status': sol_out[19, :],
        'Pulmonary Valve Status': sol_out[20, :],
        'Tricuspid Valve Status': sol_out[21, :],
        'Left Ventricular Pressure': sol_out[22, :],
        'Left Atrial Pressure': sol_out[23, :],
        'Right Ventricular Pressure': sol_out[24, :],
        'Right Atrial Pressure': sol_out[25, :],
        'Left Ventricular Elastance': sol_out[26, :],
        'Left Atrial Elastance': sol_out[27, :],
        'Right Ventricular Elastance': sol_out[28, :],
        'Right Atrial Elastance': sol_out[29, :],
        'Time (s)': sol_out[30, :],
    }

    return sol


def _solve_system(return_dict, idx, params):
    """Wrapper to solve system and store in a dictionary."""
    return_dict[idx] = solve_system(**params)
    return return_dict


def solve_system_parallel(
        param_list: list,
        num_workers: Optional[int] = None,
) -> list:
    """Solve the system with multiple sets of arguments in parallel.

    Args:
        param_list (list) : A list of parameters to be unpacked and passed
                to solve_system.
        num_workers (int, optional) : Maximum number of processes to use.

    Returns:
        sol_list (list) : A list of solution dictionaries.
    """

    num_workers = mp.cpu_count() - 1 if num_workers is None else num_workers
    num_workers = min(len(param_list), num_workers)
    logger.info(f"Solving {len(param_list)} systems using {num_workers} workerse.")

    manager = mp.Manager()
    return_dict = manager.dict()

    pool = mp.Pool(num_workers)
    for idx, param in enumerate(param_list):
        pool.apply_async(_solve_system, (return_dict, idx, param_list[idx]))
    pool.close()
    pool.join()
    return list(return_dict.values())


if __name__ == "__main__":
    sol = solve_system()
    print(np.mean([np.mean(sol[key]) for key in list(sol.keys())]))
