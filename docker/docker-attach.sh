#!/bin/bash

# Attach a terminal to an existing docker container.

# Global variables

NARGS=$#
ARGS=$@
PROGRAM=$0

g_usage="usage: ${PROGRAM} CONTAINER"

function run() {
	if [[ -z "$1" ]]; then
		echo "You must provide a container."
		echo "${g_usage}"
		exit 1
	else
		echo "Attaching to the terminal of container ${1}."
		echo "The current directory will be mounted on to /var/share in the container."
		echo "Use exit to quit."
		sudo docker exec -it "${1}" /bin/bash
	fi
}

run $ARGS
