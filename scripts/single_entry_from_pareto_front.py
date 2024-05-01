#! /usr/bin/env python
"""Converts database entries contain Pareto front into a single value"""

# Python imports
import os
import time
import sqlite3
import string
import argparse
import logging
import multiprocessing as mp
import itertools
from math import ceil
from typing import Optional, Union

# Module imports
from tqdm import tqdm
import pandas as pd

logger = logging.getLogger(__name__)


def execute_sql_concurrently(
        db_path: str,
        query: Union[str, list, None] = None,
        dataframe: Optional[pd.DataFrame] = None,
        df_table: Optional[str] = None,
        commit: Optional[bool] = False,
        fetchone: Optional[bool] = False,
        max_tries: Optional[int] = -1,
        timeout: Optional[int] = 10,
        use_tmp: Optional[bool] = False,
        **kwargs,
) -> tuple:
    """Executes an SQL command concurrently

    All unknown arguments are passed to the pandas to_sql method on dataframe.

    Args:
        db_path (str) : Path to SQLite3 database.
        query (str, optional) : Query to execute.
        dataframe (pd.DataFrame, optional) : If present, will write a datafrom
                to sql.
        df_table (str, optional) : Table to write to if dataframe is present.
        commit (bool, optional) : If True, will perform a commit after the
                query.
        fetchone (bool, optional) : If True, will return only the first result.
                Defaults to False.
        max_tries (int, optional) : Maximum number of retries for SQL
                connection.
                If <0, will perpetually retry. Defaults to -1.
        timeout (int, optional) : Timeout for SQLite connection in seconds.
                Defaults to 10.
        use_tmp (bool, optional) : If True, will write to a process specific
                temporary database with the name db_path.PID where PID is the
                process ID. Defaults to False.

    Returns:
        result (list) : Result from the SQL query.
    """

    db_opt_sucessful = False
    tries = -1

    if use_tmp:
        db_path = f"{db_path}.{mp.current_process().pid}"

    while not db_opt_sucessful:
        tries += 1
        try:
            con = sqlite3.connect(db_path, timeout=timeout)

            if query is not None:
                cursor = con.cursor()

                if not isinstance(query, (list, tuple)):
                    query = [query]

                for q in query:
                    cursor.execute(q)

                if fetchone:
                    result = cursor.fetchone()[0]
                else:
                    result = cursor.fetchall()

                if commit:
                    con.commit()

            if dataframe is not None:
                if df_table is None:
                    logger.critical(
                        "If using the dataframe keyword argument "
                        "you must also supply the df_table keyword argument"
                    )
                    raise ValueError(
                        "df_table must be supplied if supplying a dataframe."
                    )

                result = dataframe.to_sql(df_table, con, **kwargs)

            con.close()
            db_opt_sucessful = True

        except (sqlite3.OperationalError, pd.errors.DatabaseError):
            if tries >= max_tries and max_tries >= 0:
                logger.critical(
                    "Maximum SQLite3 tries exceed "
                    f"({tries}/{max_tries})"
                )
                raise

    return result


def loss(a, b):
    return abs(a - b) / b


def single_from_pareto(row, db_info, use_tmp=False):

    new_table = db_info['new_table']
    db_path = db_info['db_path']
    table = db_info['table']
    id_col = db_info['id_col']
    opt_cols = db_info['opt_cols']
    static_cols = db_info['static_cols']
    var_col = db_info['var_col']
    all_cols = db_info['all_cols']
    all_cols_str = db_info['all_cols_str']

    query = f"SELECT {all_cols_str} FROM {table} WHERE {id_col} == {row}"
    data = pd.DataFrame(
        execute_sql_concurrently(db_path, query=query),
        columns=all_cols,
    ).dropna()
    for i, col in enumerate(opt_cols.keys()):
        if i == 0:
            _loss = loss(data[opt_cols[col]], data[col])
        else:
            _loss = _loss + loss(data[opt_cols[col]], data[col])
    data["w"] = (1 / _loss) / sum(1 / _loss)

    single_row = {col: data[col].iloc[0] for col in static_cols}
    single_row[var_col] = sum(data[var_col] * data["w"])
    for col in opt_cols.keys():
        single_row[opt_cols[col]] = data[opt_cols[col]].iloc[0]
        single_row[col] = sum(data[col] * data["w"])
    single_row[id_col] = row

    df = pd.DataFrame(
        single_row,
        index=[0],
    )
    execute_sql_concurrently(
        db_path,
        dataframe=df,
        df_table=new_table,
        use_tmp=use_tmp,
        if_exists='append',
        index=False,
    )

    return True


def single_from_pareto_loop(args, checkpoint=10):
    rows, db_info = args
    logger.debug(f"Starting pareto front reduction on {len(rows)} rows ...")
    t0 = time.time()
    t_per_row = -1
    for i, row in enumerate(rows):
        if i % checkpoint == 0 and i != 0:
            t1 = time.time()
            dt = t1 - t0

            # If the time per changes by more than 10% redisplay the predicted
            # time remaining.
            if abs((dt / i) - t_per_row) / t_per_row >= 0.1 or i == checkpoint:
                t_per_row = (dt / i)
                remaining_t = t_per_row * (len(rows) - i) / 60
                logger.debug(
                    f"Worker {mp.current_process().pid} here, "
                    f"should be finished in {remaining_t:.3f} mins"
                )

            logger.debug(
                f"Worker {mp.current_process().pid} completed : {i} rows"
            )

        single_from_pareto(row, db_info, use_tmp=True)
    return mp.current_process().pid


def main(num_workers=None, start=None, total=None):

    ##################################
    # Sets up the parallel execution #
    ##################################

    num_cores = mp.cpu_count()
    num_workers = min(
        num_cores,
        num_workers if num_workers is not None else num_cores,
    )

    start = start if start is not None else 0
    total = total if total is not None else 1

    logger.debug(
        f"Starting job {start} out of {total} with {num_workers} workers."
    )

    db_path = "physiological.db"
    table = "lumped_model_outputs"
    new_table = "sv_rel"

    id_col = "row_names"

    opt_cols = {
        "sys": "sys_target",
        "dia": "dia_target",
    }

    static_cols = [
        "generic_params.period",
        "generic_params.height",
        "generic_params.age",
        "generic_params.sex",
        "ecg.t1",
        "ecg.t2",
        "ecg.t3",
        "ecg.t4",
    ]

    var_col = "sv"
    all_cols = [*opt_cols.keys(), *opt_cols.values(), *static_cols, var_col]
    all_cols_str = (
        ', '.join(f"\"{s.strip(string.punctuation)}\""
                  for s in str(all_cols).split())
    )

    query = f"SELECT DISTINCT({id_col}) FROM {table}"
    row_tuple = execute_sql_concurrently(db_path, query=query)
    logger.debug(
        f"Database has {len(row_tuple)} rows.\n"
        f"First row:\n{row_tuple[0]}"
    )

    if total > 1:
        min_idx = int(start / total * len(row_tuple))
        max_idx = int((start + num_workers) / total * len(row_tuple))
        row_tuple = row_tuple[min_idx:max_idx]

    rows = [r[0] for r in row_tuple]

    logger.info(
        f"Connecting to {db_path} "
        f"reading from {table} and writing to {new_table}\n"
        f"The following columns are constant:\n{static_cols}\n"
        f"The following columns are used for optimisation:\n{opt_cols}\n"
        f"The following column is the variable column of interest: {var_col}\n"
    )

    db_info = {
        'new_table': new_table,
        'db_path': db_path,
        'table': table,
        'id_col': id_col,
        'opt_cols': opt_cols,
        'static_cols': static_cols,
        'var_col': var_col,
        'all_cols': all_cols,
        'all_cols_str': all_cols_str,
    }

    logger.info(f"{len(rows)} total rows to process.")

    # Single core #
    if num_workers <= 1:
        for row in tqdm(rows):
            single_from_pareto(row, db_info)

    # Parallel #
    else:
        n = ceil(len(rows) / num_workers)
        logger.info(f"{n} rows per worker.")
        args = list(
            zip(
                [rows[i:i+n] for i in range(0, len(rows), n)],
                itertools.repeat(db_info),
            )
        )
        logger.debug(f"Zipped args format:\n{args[0]}")

        with mp.Pool(num_workers) as p:
            # Performs the weighting in parallel
            ids = p.map(single_from_pareto_loop, args)

            # Joins the temporary databases together.
            for pid in ids:
                logger.debug(f"Adding database from worker {pid} to {db_path}")
                pid_db = f"{db_path}.{pid}"

                query = (
                    f"ATTACH '{pid_db}' AS pid_db",
                    f"INSERT INTO {new_table} SELECT * FROM pid_db.{new_table}"
                )
                execute_sql_concurrently(
                    db_path, query=query, commit=True,
                )

                os.remove(pid_db)

    logger.info(f"Completed! Processed {len(rows)} rows.")


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description=(
            "Transforms a Pareto Frontier into a "
            "single value via loss weighting."
        )
    )

    parser.add_argument(
        '--num_workers',
        type=int,
        help='Number of workers',
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
        '--log',
        default="warning",
        type=str,
        help='Log level, can be debug, info, warning, error or critical.',
    )

    args = parser.parse_args()
    log_level = getattr(logging, args.log.upper())
    logging.basicConfig(level=log_level)

    main(
        start=args.start,
        total=args.total,
        num_workers=args.num_workers,
    )
