#! /usr/bin/env python
"""Converts database entries contain Pareto front into a single value"""

# Python imports
import sqlite3
import string
import argparse
from typing import Optional
import logging

# Module imports
from tqdm import tqdm
import pandas as pd

logger = logging.getLogger(__name__)


def execute_sql_concurrently(
        db_path: str,
        query: str,
        fetchone: Optional[bool] = False,
        max_tries: Optional[int] = -1,
        timeout: Optional[int] = 10,
):
    """Executes an SQL command concurrently

    Args:
        db_path (str) : Path to SQLite3 database.
        query (str) : Query to execute.
        fetchone (bool, optional) : If True, will return only the first result.
                Defaults to False.
        max_tries (int, optional) : Maximum number of retries for SQL connection
                If <0, will perpetually retry. Defaults to -1.
        timeout (int, optional) : Timeout for SQLite connection in seconds.
                Defaults to 10

    Returns:
        result (list) : Result from the SQL query.
    """

    db_opt_sucessful = False
    tries = -1

    while not db_opt_sucessful:
        tries += 1
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
            if tries >= max_tries and max_tries >= 0:
                logger.critical(
                    "Maximum SQLite3 tries exceed "
                    f"({tries}/{max_tries})"
                )
                raise

    return result


def loss(a, b):
    return abs(a - b) / b


def main():

    db_path = "physiological.sqlite3"
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
    rows = [r[0] for r in execute_sql_concurrently(db_path, query)]

    logger.info(
        f"Connecting to {db_path} "
        f"reading from {table} and writing to {new_table}\n"
        f"The following columns are constant:\n{static_cols}\n"
        f"The following columns are used for optimisation:\n{opt_cols}\n"
        f"The following column is the variable column of interest: {var_col}\n"
    )
    for row in tqdm(rows):

        query = f"SELECT {all_cols_str} FROM {table} WHERE {id_col} == {row}"
        data = pd.DataFrame(
            execute_sql_concurrently(db_path, query, max_tries=10),
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

        con = sqlite3.connect(db_path, timeout=10)
        pd.DataFrame(
            single_row,
            index=[0],
        ).to_sql(new_table, con, if_exists='append')
        con.close()


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description=(
            "Transforms a Pareto Frontier into a "
            "single value via loss weighting."
        )
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

    main()
