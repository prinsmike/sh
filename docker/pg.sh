#!/bin/bash

# Enable this for debugging:
#set -x

# Global variables

NARGS=$#
ARGS=$@
PROGRAM=$0

declare -A g_commands=(
	[create]="Create a new PostgreSQL docker container."
	[start]="Start an existing PostgreSQL docker container."
	[stop]="Stop an existing PostgreSQL docker container."
	[attach]="Attach a psql command line interface to an existing PostgreSQL container."
	[script]="Execute an SQL script on an existing PostgreSQL docker container."
	[dump]="Dump a PostgreSQL database to an SQL script."
	[drop]="Remove an existing PostgreSQL docker container."
	[status]="Display status information for all PostgreSQL docker containers."
	[logs]="Distplay the logs for a PostgreSQL docker container."
)

g_usage="usage: ${PROGRAM} COMMAND [COMMAND_OPTIONS...]"

run() {
	if [[ $NARGS -lt 1 ]]; then
		printUsage
	else
		case "$1" in
			'create')
				createPG $ARGS
				;;
			'start')
				startPG $ARGS
				;;
			'stop')
				stopPG $ARGS
				;;
			'attach')
				attachPG $ARGS
				;;
			'script')
				pgScript $ARGS
				;;
			'dump')
				pgDump $ARGS
				;;
			'drop')
				dropPG $ARGS
				;;
			'status')
				pgStatus $ARGS
				;;
			'logs')
				pgLogs $ARGS
				;;
			*)
				echo 'Invalid command.'
				printUsage
				exit 1
				;;
		esac
	fi
}

printUsage() {
	echo ${g_usage}
	printf "Commands:\n"
	for k in "${!g_commands[@]}"
	do
		printf "\t%s\t%s\n" "${k}" "${g_commands[$k]}"
	done
}

createPG() {
	local loc_command=create
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME PG_PASS"

	if [[ -z "$2"  ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		echo "Provided: $ARGS"
		exit 1
	elif [[ "$2" == "--help"  ]]; then
		echo "${loc_usage}"
		exit 0
	elif [[ -z "$3"  ]]; then
		echo "You must provide the PostgreSQL password."
		echo "${loc_usage}"
		exit 1
	else
		echo "Creating the new PostgreSQL docker container."
		docker run --name "${2}" -p 5432:5432 -e POSTGRES_PASSWORD="${3}" -d postgres:latest
		
		# PostgreSQL with PostGIS
		#docker run --name "${2}" -p 5432:5432 -e POSTGRES_PASSWORD="${2}" -d mdillon:postgis
	fi
}

startPG() {
	local loc_command=start
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		echo "Provided $ARGS"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		echo "Starting the ${2} container."
		docker start "${2}"
	fi
}

stopPG() {
	local loc_command=start
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		echo "Provided $ARGS"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		echo "Stopping the ${2} container."
		docker stop "${2}"
	fi
}

attachPG() {
	local loc_command=attach
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"

	if [[ -z "$2"  ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 0
	else
		echo "Attaching a terminal to an existing PosgreSQL docker container."
		docker run -it --rm --link "${2}":postgres postgres:latest sh -c 'exec psql -h postgres -U postgres'
	fi
}

pgScript() {
	local loc_command=script
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME FILENAME [DB_NAME]"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	elif [[ -z "$3" ]]; then
		echo "You must provide a filename for the script."
		echo "${loc_usage}"
		exit 1
	elif [[ ! -z "$4" ]]; then
		local DIR=$(dirname "${3}")
		local FILE=$(basename "${3}")
		echo "Running script ${3} on database ${4} in container ${2}."
		docker run -it --link "${2}":postgres -v $DIR:/var/script -e SQL_SCRIPT="${FILE}" -e DB_NAME="${4}" --rm postgres:latest psql -h postgres -U postgres -d ${4} -f /var/script/$FILE
	else
		local DIR=$(dirname "${3}")
		local FILE=$(basename "${3}")
		echo "You did not provide a database name."
		if confirm "Proceed? [y/N]"; then
			echo "Running script ${3} in container ${2}."
			docker run -it --link "${2}":postgres -v $DIR:/var/script -e FILENAME="${FILE}" --rm postgres:latest psql -h postgres -U postgres postgres -f /var/script/$FILE
		else
			echo "Aborting."
			exit 0
		fi
	fi

}

function pgStatus() {
	local loc_command=status
	local loc_usage="usage: $PROGRAM ${loc_command}"

	if [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		docker ps -a | grep CREATED
		docker ps -a | egrep 'pg|postgres|postgresql'
	fi
}

function confirm() {
	# Requires Bash 4.x
	read -r -p "${1:-Are you sure? [y/N]} " response
	response=${response,,}		# tolower
	if [[ $response =~ ^(yes|y)$ ]]; then
		true
	else
		false
	fi
}

run ${ARGS}
