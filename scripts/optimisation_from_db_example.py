#! /usr/bin/env python
"""Sequentially optimisation entries from a database."""

# Python imports
import logging

# Module imports
import numpy as np
import pandas as pd
from tqdm import tqdm
import sqlite3

# Local imports
from src import solve_system, Optimiser

logger = logging.getLogger(__file__)


def main():
    """Main script for optimisation against csv records. """

    db_path = "../heat_response/data/exercise/processed_data.sqlite3"
    con = sqlite3.connect(db_path)
    cursor = con.cursor()
    col_names = (
        'id', 'temp', 't',
        'sv', 'sys', 'dia',
        'hr', 'pr', 'qrs', 'qt',
        'core', 'core_ref', 'skin', 'skin_ref',
    )
    cursor.execute(f"SELECT {', '.join(col_names)} FROM Model_Inputs")
    df = pd.DataFrame(cursor.fetchall(), columns=col_names)

    out_table_name = 'Model_Outputs'

    prev = {
        'id': None,
        'temp': None,
        't': 60,
        'e_scale': 1,
        'v_scale': 1,
        'r_scale': 1,
        'c_scale': 1,
    }

    for i in tqdm(range(df.shape[0]), position=0):

        ########################
        # Sets up model inputs #
        ########################

        row = df.iloc[i]
        if row['id'] != prev['id'] and row['temp'] != prev['temp']:
            prev = {
                'id': row['id'],
                'temp': row['temp'],
                't': row['t'],
                'e_scale': 1,
                'v_scale': 1,
                'r_scale': 1,
                'c_scale': 1,
            }

        else:
            # Diminishes the effect of the previous scale with time.
            # When only 60s has passed, current starting scale is
            # the same as the previous scale.
            # when 300s has passed the current starting scale is
            # 0.5 * previous scale + 0.5
            # when around 30 minutes has passed the current starting scale is
            # 0.005 * previous scale + 0.995
            dt = row['t'] - prev['t']
            alpha = np.exp(- np.log(2)/4 * (dt/60 - 1))
            for key in ('e_scale', 'v_scale', 'r_scale', 'c_scale'):
                prev[key] = alpha * prev[key] + (1 - alpha)

        inputs = {
            'generic_params': {
                'period': 60/row['hr'],
            },
            'ecg': {
                "t1": row['pr'] / 3,
                "t2": row['pr'] + row['qrs']/2,
                "t3": row['pr'] + row['qrs'] + 0.75 * (row['qt'] - row['qrs']),
                "t4": row['pr'] + row['qt'],
            },
            'thermal_system': {
                't_cr': row['core'],
                't_cr_ref': row['core_ref'],
                't_sk': row['skin'],
                't_sk_ref': row['skin_ref'],
            },
        }

        ###################################################
        # Optimises for blood pressure and stroke volume  #
        ###################################################

        params = {
            "generic_params": {
                "r_scale": [0.1, 10, prev['r_scale']],
                "c_scale": [0.1, 10, prev['c_scale']],
                'e_scale': [0.25, 4, prev['e_scale']],
                'v_scale': [0.5, 2, prev['v_scale']],
            },
            "thermal_system": {
                "k_dil": [37, 113, 75],
                "k_con": [0.25, 0.75, 0.5],
            },
        }

        opt = Optimiser(
            optimiser="NelderMead",
            inputs=inputs,
            params=params,
            budget=1000,
            num_workers=1,
            tol=1e-3,
            pbar=True,
            pbar_pos=1,
        )

        best_params = opt.run(sbp=row['sys'], dbp=row['dia'], sv=row['sv'])
        sol = solve_system(**best_params)

        prev['r_scale'] = best_params['generic_params']['r_scale']
        prev['c_scale'] = best_params['generic_params']['c_scale']
        prev['e_scale'] = best_params['generic_params']['e_scale']
        prev['v_scale'] = best_params['generic_params']['v_scale']

        #####################
        # Saves the results #
        #####################

        sys, dia = opt.get_systemic_sysdia_pres(sol)
        sv = opt.get_stroke_volume(sol)

        outputs = {
            'id': row['id'],
            'temp': row['temp'],
            't': row['t'],
            'sys': sys,
            'sys_target': row['sys'],
            'dia': dia,
            'dia_target': row['dia'],
            'sv': sv,
            'sv_target': row['sv'],
            **opt.flat_inputs_raw,
            **opt.recommendation,
        }

        if i == 0:
            pd.DataFrame([outputs]).to_sql(
                out_table_name, con, if_exists='replace', index=False,
            )

        else:
            pd.DataFrame([outputs]).to_sql(
                out_table_name, con, if_exists='append', index=False,
            )


if __name__ == '__main__':
    main()
