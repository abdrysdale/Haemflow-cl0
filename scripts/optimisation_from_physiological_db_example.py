#! /usr/bin/env python
"""Sequentially optimisation entries from a database."""

# Python imports
import sys
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

    db_path = "../ADAN56_SPD_analysis/physiological.db"
    con = sqlite3.connect(db_path)
    cursor = con.cursor()
    col_names = (
        "row_names", "hr", "sex", "age", "sbp", "dbp", "height", "weight"
    )
    table = 'literature_relations'
    out_table_name = 'lumped_model_outputs'

    cursor.execute(f"SELECT {', '.join(col_names)} FROM {table}")
    df = pd.DataFrame(cursor.fetchall(), columns=col_names)

    for i in tqdm(range(df.shape[0]), position=0, file=sys.stdout, leave=True):

        ########################
        # Sets up model inputs #
        ########################

        row = df.iloc[i]

        default_inputs = {
            'generic_params': {
                'period': 60/row['hr'],
                'est_h_vol': True,
                'height': row['height'],
                'weight': row['weight'],
                'age': row['age'],
                'sex': 0 if row['sex'] == 'Male' else 1,
            },
            'ecg': {  # These ECGs are fixed and scaled from a sample patient.
                "t1": 0.044 * 76 / row['hr'],
                "t2": 0.184 * 76 / row['hr'],
                "t3": 0.500 * 76 / row['hr'],
                "t4": 0.588 * 76 / row['hr'],
            },
        }

        ###################################################
        # Optimises for blood pressure and stroke volume  #
        ###################################################

        inputs = default_inputs

        params = {
            "generic_params": {
                "r_scale": [0.1, 10, 1],
                "c_scale": [0.1, 10, 1],
                'e_scale': [0.9, 1.1, 1],
            },
        }

        opt = Optimiser(
            optimiser="TwoPointsDE",
            inputs=inputs,
            params=params,
            budget=1000,
            num_workers=16,
            multi_objective=True,
            tol=1e-3,
            pbar=False,
        )

        best_params = opt.run(sbp=row['sbp'], dbp=row['dbp'])

        #####################
        # Saves the results #
        #####################

        for j, best_p in enumerate(best_params):
            sol = solve_system(**best_p)

            systolic, diastolic = opt.get_systemic_sysdia_pres(sol)
            sv = opt.get_stroke_volume(sol)
            loss = (
                np.abs(systolic - row['sbp']) / row['sbp']
                + np.abs(diastolic - row['dbp']) / row['dbp']
            )

            outputs = {
                'row_names': row['row_names'],
                'sys': systolic,
                'sys_target': row['sbp'],
                'dia': diastolic,
                'dia_target': row['dbp'],
                'sv': sv,
                'loss': loss,
                **opt.flat_inputs_raw,
                **opt.recommendation[j],
            }

            if i == 0 and j == 0:
                pd.DataFrame([outputs]).to_sql(
                    out_table_name, con, if_exists='replace', index=False,
                )

            else:
                pd.DataFrame([outputs]).to_sql(
                    out_table_name, con, if_exists='append', index=False,
                )

        tqdm._instances.clear()


if __name__ == '__main__':
    main()
