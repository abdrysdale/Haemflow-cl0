#! /usr/bin/env python
"""Sequentially optimisation entries from a database."""

# Python imports
import sys
import logging
import argparse
import multiprocessing as mp
import traceback
import sqlite3

# Module imports
import numpy as np
import pandas as pd
from tqdm import tqdm

# Local imports
from src import solve_system, Optimiser

logger = logging.getLogger(__file__)


def execute_sql_concurrently(db_path, query, fetchone=False, max_tries=0, timeout=10):
    """Executes an SQL command concurrently 

    Args:
        db_path (str) : Path to SQLite3 database.
        query (str) : Query to execute.
        fetchone (bool, optional) : If True, will return only the first result.
                Defaults to False.
        max_tries (int, optional) : Maximum number of retries for SQL connection.
                If 0, will perpetually retry. Defaults to 0.
        timeout (int, optional) : Timeout for SQLite connection.


    Returns:
        result (list) : Result from the SQL query.
    """

    db_opt_sucessful = False
    tries = -1

    logger.debug(f"Attempting to connect to {db_path} and run {query}")
    
    while not db_opt_sucessful:
        tries += 1
        logger.debug(f"Try {tries} to connect to {db_path} ...")
        try:
            con = sqlite3.connect(db_path, timeout=timeout)
            cursor = con.cursor()
            cursor.execute(query)

            if fetchone:
                result = cursor.fetchone()[0]
            else:
                result = cursor.fetchall()

            con.close()
            db_opt_sucessful = True
            
        except sqlite3.OperationalError:
            logger.debug(traceback.print_exc())
            if tries >= max_tries and max_tries > 0:
                logger.critical(f"Maximum SQLite3 tries exceed ({tries}/{max_tries}).")
                raise

    return result



def main(num_workers=None, start=None, total=None, replace_table=False, budget=1000):
    """Main script for optimisation against db records. """

    # Sets up the parallel optimisation
    num_cores = mp.cpu_count()
    num_workers = min(
        num_cores,
        num_workers if num_workers is not None else num_coresr
    )

    start = start if start is not None else 0
    total = total if total is not None else 1

    logger.debug(
        f"Starting job {start} out of {total} with {num_workers} workers."
    )

    # Loads the data
    db_path = "physiological.db"
    col_names = (
        "row_names", "hr", "sex", "age", "sbp", "dbp", "height", "weight"
    )
    table = 'literature_relations'
    out_table_name = 'lumped_model_outputs'

    if total > 1:
        query = f"SELECT COALESCE(MAX(row_names)+1, 0) FROM {table}"
        num_rows = execute_sql_concurrently(db_path, query, fetchone=True)
        
        min_row = int(start / total * num_rows)
        max_row = int((start + num_workers) / total * num_rows)

        query = (
            f"SELECT {', '.join(col_names)} FROM {table} "
            f"WHERE row_names >= {min_row} AND row_names <= {max_row}"
        )
        data = execute_sql_concurrently(db_path, query)

    else:
        query = f"SELECT {', '.join(col_names)} FROM {table}"
        data = execute_sql_concurrently(db_path, query)

    df = pd.DataFrame(data, columns=col_names)

    logger.debug(f"Sucessfully loaded database {db_path} with shape {df.shape}")

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
                "r_scale": [0.1, 10, 1.5],
                "c_scale": [0.1, 10, 0.5],
                'e_scale': [0.25, 4, 2.0],
            },
        }

        logger.debug(
            f"Beginning optimisation of patient {i} with variable parameters:\n"
            f"{params}\n and fixed inputs:\n{inputs}"
        )

        opt = Optimiser(
            optimiser="TwoPointsDE",
            inputs=inputs,
            params=params,
            budget=budget,
            num_workers=num_workers,
            multi_objective=True,
            tol=1e-3,
            pbar=False,
        )

        best_params = opt.run(sbp=row['sbp'], dbp=row['dbp'])

        logger.debug(f"Optimisation for patient {i} has been completed.")

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
        logger.debug("Attempting to write Pareto Frontier to database ...")
        while not db_write_sucessful:
            try:
                con = sqlite3.connect(db_path, timeout=10)
                best_df.to_sql(
                    out_table_name, con, if_exists=if_exists, index=False,
                )
                db_write_sucessful = True
                con.close()
            except sqlite3.OperationalError or pd.errors.DatabaseError:
                logger.debug(traceback.print_exc())
        logger.debug(f"Pareto Front for patient {i} has been written to the database!")

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
        '--start',
        type=int,
        help='Starting cpu index (for HPC optimisation).',
    )

    parser.add_argument(
        '--total',
        type=int,
        help='Total number of cpus for the job (for HPC optimisation).',
    )
    parser.add_argument(
        "--replace_table",
        help="Replaces the existing SQLite3 table.",
        action="store_true"
    )
    parser.add_argument(
        "--log",
        type=str,
        default='warning',
        help="Sets the logging level.",
    )

    args = parser.parse_args()

    log_level = getattr(logging, args.log.upper())
    if not isinstance(log_level, int):
        raise ValueError(f"Invalid log level: {args.log}")
    logging.basicConfig(level=log_level)

    main(
        start=args.start,
        total=args.total,
        num_workers=args.num_workers,
        replace_table=args.replace_table,
    )
