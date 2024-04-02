#! /usr/bin/env sh

container_name="cl0"
container_tag="latest"
data_dir="${HOME}/data"
port="0.0.0.0"
export APPTAINER_TMPDIR="$PWD/singularity_tmpdir"

root_cmd="doas"

args="${@}"
run=0

while [ -n "${1}" ]
do
case "${1}" in
-b | --build) 
	run=1
	mkdir ${APPTAINER_TMPDIR};
	docker build -t ${container_name}:${container_tag} . &&\
	${root_cmd} singularity build ${container_name}.sif \
	docker-daemon://${container_name}:${container_tag} &&\
	rm -rf ${APPTAINER_TMPDIR}
	exit;;
-l | --lab)
	run=1
    singularity exec --bind "$(pwd)":/app --bind ${data_dir}:/data  ${container_name}.sif \
		jupyter lab --ip ${port} --no-browser --allow-root
	exit;;
-s | --shell)
	run=1
	singularity shell --bind "$(pwd)":/app --bind "${data_dir}":/data  ${container_name}.sif;;
-e | --exec)
	run=1
	singularity exec --bind "$(pwd)":/app --bind "${data_dir}":/data  ${container_name}.sif \
		${args:2};;
-d | --debug)
	run=1
	singularity exec --bind "$(pwd)":/app --bind "${data_dir}":/data  ${container_name}.sif \
		python3 -m pdb ${args:2};;
-t | --test)
	run=1
	singularity exec --bind "$(pwd)":/app --bind "${data_dir}":/data  ${container_name}.sif \
		python3 -m pytest ${args:2};;
-h | --help)
	run=1
	echo "./run.sh [OPTION] [ARGS]"
	echo ""
	echo "This is a simple script for ease of running container commands."
	echo "By default it binds the current directory to /app in the container and the data_dir to"
	echo "/data in the container."
	echo "Additionally, the script exposes the nvidia drivers to the singularity container."
	echo ""
	echo "Options:"
	echo "-b, --build   Builds a docker container and a singularity image from the Dockerfile."
	echo "-l, --lab     Launches a jupyter lab instance using singularity on port ${port}."
	echo "-s, --shell   Launches a singularity container binding the current and data directory".
	echo "-e, --exec    Passes ARGS directory to the singularity container."
	echo "-d, --debug   Passes python3 -m pdb ARGS to the singularity container."
	echo "-h, --help    Displays this message."
	echo ""
	echo "If no option is specified, runs ARGS with python3."
	echo ""
	echo "Current variables:"
	echo "container_name    ${container_name}"
	echo "container_tag     ${container_tag}"
	echo "data_dir          ${data_dir}"
	echo "port              ${port}"
	echo "root_cmd          ${root_cmd}"
	echo ""
	echo "Variables are intended to be edited to reflect user setup.";;

esac
shift
done

if [ ${run} -eq 0 ]
then
	singularity exec --bind "$(pwd)":/app --bind "${data_dir}":/data  ${container_name}.sif \
		python3 ${args}
fi
