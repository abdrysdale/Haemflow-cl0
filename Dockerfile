FROM python:3.12-bookworm

# Installs system packages
RUN apt-get update && apt-get install -y gfortran

# Sets up the /app/ directory with the correct scripts
RUN mkdir -p /app
RUN mkdir -p /data
COPY . /app/

WORKDIR /app
ENV PYTHONPATH=${PYTHONPATH}:${PWD}
RUN ln -s /bin/python3 /bin/python
RUN export PIP_DEFAULT_TIMEOUT=300

# Installs the packages
RUN pip install poetry
RUN poetry config virtualenvs.create false
RUN poetry lock --no-update
RUN poetry install --no-interaction

# Builds the fortran library
RUN make clean && ./build.sh lib

# Runs the a script in poetry
CMD ["python", "$@"]
