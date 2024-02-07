#! /usr/bin/env python
"""Wrapper for 0D closed loop solver in Fortran"""

# Python imports
import os
import ctypes as ct
import logging

# Module imports
import numpy as np

logger = logging.getLogger(__name__)

fortlib = ct.CDLL(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), 'closed_loop_lumped.so')
)


def load_defaults():
    """Loads all of the default dictionaries for solving the system."""

    generic_params = {
        "nstep": 2000,
        "period": 0.9,
        "ncycle": 10,
        "rk": 4,
        "rho": 1.06,
    }

    ecg = {
        "t1": 0,
        "t2": 0.142,
        "t3": 0.462,
        "t4": 0.522,
    }

    left_ventrical = {
        "emin": 0.1,
        "emax": 0.5,
        "vmin": 10,
        "vmax": 135,
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
        "pini": 80,
        "scale_R": 0.7,
        "scale_C": 0.8,
        "ras": 0.003,
        "rat": 0.05,
        "rar": 0.5,
        "rcp": 0.52,
        "rvn": 0.075,
        "cas": 0.008,
        "cat": 1.6,
        "cvn": 20.5,
        "las": 6.2e-5,
        "lat": 1.7e-3,
    }

    pulmonary = {
        "pini": 20,
        "scale_R": 1,
        "scale_C": 1,
        "ras": 0.002,
        "rat": 0.01,
        "rar": 0.05,
        "rcp": 0.25,
        "rvn": 0.006,
        "cas": 0.18,
        "cat": 3.8,
        "cvn": 20.5,
        "las": 5.2e-5,
        "lat": 1.7e-3,
    }

    aortic_valve = {
        "leff": 1,
        "aeffmin": 1e-10,
        "aeffmax": 2,
        "kvc": 0.012,
        "kvo": 0.012,
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
    }

    return defaults


def solve_system(
        generic_params=None,
        ecg=None,
        left_ventrical=None,
        left_atrium=None,
        right_ventrical=None,
        right_atrium=None,
        systemic=None,
        pulmonary=None,
        aortic_valve=None,
        mitral_valve=None,
        pulmonary_valve=None,
        tricuspid_valve=None,
):
    """Solves the lumped parameter closed loop system.

    If any of the dictionaries or keys are not provided or any keys default values will be used.

    Args:
    generic_params (dict, optional) : A dictionary containing: 'nstep' (number of time steps),
        'ncycle' (number of cardiac cycles), 'rk' (Runge-Kutta order - either 2 or 4),
        'period' (cardiac period in seconds) and 'rho' (density of blood).
    ecg (dict, optional) : A dictionary containing: 't1' (location of the P peak),
        't2' (location of the R peak), 't3' (location of the T peak)
        and 't4' (location of the end of the T peak - also called T offset).
    left_ventrical (dict, optional) : A dictionary containing 'emin' (minimum elastance),
        'emax' (maximum elastance), 'vmin' (minimum volume) and 'vmax' (maximum volume).
    left_atrium (dict, optional) : A dictionary containing 'emin' (minimum elastance),
        'emax' (maximum elastance), 'vmin' (minimum volume) and 'vmax' (maximum volume)
    right_ventrical (dict, optional) : A dictionary containing 'emin' (minimum elastance),
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
    """

    ###############
    # Load inputs #
    ###############
    input_dicts = {
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
            for key in list(defaults[idict].keys()):
                tmp_dict[key] = input_dicts[idict].get(key, defaults[idict][key])
                logger.debug(
                    f"Parameter {idict}: {key} not supplied, loading default."
                )
            inputs[idict] = tmp_dict

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
    rho = ct.c_double(inputs["generic_params"]["rho"])

    # Left ventrical
    lv_emin = ct.c_double(inputs["left_ventrical"]["emin"])
    lv_emax = ct.c_double(inputs["left_ventrical"]["emax"])
    lv_v01 = ct.c_double(inputs["left_ventrical"]["vmin"])
    lv_v02 = ct.c_double(inputs["left_ventrical"]["vmax"])

    # Left atrium
    la_emin = ct.c_double(inputs["left_atrium"]["emin"])
    la_emax = ct.c_double(inputs["left_atrium"]["emax"])
    la_v01 = ct.c_double(inputs["left_atrium"]["vmin"])
    la_v02 = ct.c_double(inputs["left_atrium"]["vmax"])

    # Right ventrical
    rv_emin = ct.c_double(inputs["right_ventrical"]["emin"])
    rv_emax = ct.c_double(inputs["right_ventrical"]["emax"])
    rv_v01 = ct.c_double(inputs["right_ventrical"]["vmin"])
    rv_v02 = ct.c_double(inputs["right_ventrical"]["vmax"])

    # Right atrium
    ra_emin = ct.c_double(inputs["right_atrium"]["emin"])
    ra_emax = ct.c_double(inputs["right_atrium"]["emax"])
    ra_v01 = ct.c_double(inputs["right_atrium"]["vmin"])
    ra_v02 = ct.c_double(inputs["right_atrium"]["vmax"])

    # Systemic system
    pini_sys = ct.c_double(inputs["systemic"]["pini"])
    scale_Rsys = ct.c_double(inputs["systemic"]["scale_R"])
    scale_Csys = ct.c_double(inputs["systemic"]["scale_C"])

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
    scale_Rpulm = ct.c_double(inputs["pulmonary"]["scale_R"])
    scale_Cpulm = ct.c_double(inputs["pulmonary"]["scale_C"])

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
        sol_out.ctypes.data_as(ct.POINTER(ct.c_double)),
    )

    return sol_out


if __name__ == "__main__":
    sol = solve_system()
    print(np.mean(sol))
