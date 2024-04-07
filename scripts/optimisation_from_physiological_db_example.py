#! /usr/bin/env python
"""Sequentially optimisation entries from a database."""

# Python imports
import sys
import logging
import argparse
import multiprocessing as mp
import sqlite3

# Module imports
import numpy as np
import pandas as pd
from tqdm import tqdm

# Local imports
from src import solve_system, Optimiser

logger = logging.getLogger(__file__)


def main(num_workers=None, node=None, max_node=None, replace_table=False):
    """Main script for optimisation against csv records. """

    # Sets up the parallel optimisation
    num_cores = mp.cpu_count() - 1
    num_workers = min(
        num_cores,
        num_workers if num_workers is not None else num_cores
    )

    node = node if node is not None else 1
    max_node = max_node if max_node is not None else 1

    # Loads the data
    db_path = "physiological.db"
    con = sqlite3.connect(db_path)
    cursor = con.cursor()
    col_names = (
        "row_names", "hr", "sex", "age", "sbp", "dbp", "height", "weight"
    )
    table = 'literature_relations'
    out_table_name = 'lumped_model_outputs'

    if max_node > 1:
        cursor.execute(f"SELECT COALESCE(MAX(row_names)+1, 0) FROM {table}")
        num_rows = cursor.fetchone()[0]
        min_row = int(node / max_node * num_rows)
        max_row = int((node + 1) / max_node * num_rows)

        cursor.execute(
            f"SELECT {', '.join(col_names)} FROM {table} "
            f"WHERE row_names >= {min_row} AND row_names < {max_row}"
        )

    else:
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
            num_workers=num_workers,
            multi_objective=True,
            tol=1e-3,
            pbar=False,
        )

        best_params = opt.run(sbp=row['sbp'], dbp=row['dbp'])

        #####################
        # Saves the results #
        #####################

        frames = []
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
            frames.append(pd.DataFrame([outputs]))


        if replace_table:
            if_exists = 'replace'
        else:
            if_exists = 'append'
        
        best_df = pd.concat(frames, ignore_index=True, sort=False)
        db_write_sucessful = False

        while not db_write_sucessful:
            try:
                best_df.to_sql(
                    out_table_name, con, if_exists=if_exists, index=False,
                )
            except sqlite3.OperationalError:
                pass



        tqdm._instances.clear()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Optimises against a physiological database'
    )

    parser.add_argument(
        '--num_workers',
        type=int,
        help='Number of workers for the multi-objective optimisation',
    )

    parser.add_argument(
        '--node',
        type=int,
        help='Current node index (for HPC optimisation).',
    )

    parser.add_argument(
        '--max_node',
        type=int,
        help='Maximum node index (for HPC optimisation).',
    )
    parser.add_argument(
        "--replace_table",
        help="Replaces the existing SQLite3 table.",
        action="store_true")

    args = parser.parse_args()

    main(
        num_workers=args.num_workers,
        node=args.node,
        max_node=args.max_node,
        replace_table=args.replace_table,
    )
