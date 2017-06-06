#!/bin/bash

# Enable this for debugging:
#set -x

# Global variables

NARGS=$#
ARGS=$@
PROGRAM=$0

declare -A g_commands=( 
	[create]="Create a new MYSQL docker container."
 	[start]="Start an existing MYSQL docker container."
 	[stop]="Stop an existing MYSQL docker container."
 	[attach]="Attach a MYSQL command line interface to an existing MYSQL container."
 	[script]="Execute an SQL script on an existing MYSQL docker container."
 	[dump]="Dump a MYSQL database to an SQL script."
 	[drop]="Remove an existing MYSQL docker container."
	[status]="Display status information for all MYSQL docker containers."
	[logs]="Display the logs for a MYSQL docker container."
)

g_usage="usage: ${PROGRAM} COMMAND [COMMAND_OPTIONS...]"

function run() {
	if [[ $NARGS -lt 1 ]]; then
		printUsage
	else
		case "$1" in
			'create')
				createMysql $ARGS
				;;
			'start')
				startMysql $ARGS
				;;
			'stop')
				stopMysql $ARGS
				;;
			'attach')
				attachMysql $ARGS
				;;
			'script')
				mysqlScript $ARGS
				;;
			'dump')
				mysqlDump $ARGS
				;;
			'drop')
				dropMysql $ARGS
				;;
			'status')
				mysqlStatus $ARGS
				;;
			'logs')
				mysqlLogs $ARGS
				;;
			*)
				echo 'Invalid command.'
				printUsage
				exit 1
				;;
		esac
	fi
}

function printUsage() {
	echo ${g_usage}
	printf "Commands:\n"
	for k in "${!g_commands[@]}"
	do
		printf "\t%s\t%s\n" "${k}" "${g_commands[$k]}"
	done
}

function createMysql() {
	local loc_command=create
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME MYSQL_PASSWORD "
	
	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		echo "Provided: $@"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	elif [[ -z "$3" ]]; then
		echo "You must provide the MYSQL password."
		echo "${loc_usage}"
		exit 1
	else
		echo "Creating the new MYSQL docker container."
		docker run --name "${2}" -e MYSQL_ROOT_PASSWORD="${3}" -p 3306:3306 -d mysql:latest
	fi
}

function attachMysql() {
	local loc_command=attach
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"
	
	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		echo "Attaching a terminal to an existing MYSQL docker container."
		docker run -it --link "${2}":mysql --rm mysql sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p'
	fi
}

function dropMysql() {

	local loc_command=drop
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		if confirm "Are you sure you want to delete the ${2} container? This cannot be undone!"; then
			stopMysql $ARGS
			echo "Dropping container ${2}"
			docker rm "${2}"
		else
			echo "Drop operation cancelled."
		fi
	fi	
}

function stopMysql() {
	local loc_command=stop
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		echo "Stopping container ${2}"
		docker stop "${2}"
	fi
}

function startMysql() {
	local loc_command=start
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		echo "Starting container ${2}"
		docker start "${2}"
	fi
}

function mysqlDump() {
	local loc_command=dump
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME DATABASE_NAME [FILENAME]"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	elif [[ -z "$3" ]]; then
		echo "You must provide a database name"
		echo "${loc_usage}"
		exit 1
	elif [[ ! -z "$4" ]]; then
		echo "Dumping database ${3} to SQL file ${4}"
		docker run -it --link "${2}":mysql -v $PWD:/var/script -e DB_NAME="${3}" -e FILENAME="${4}" --rm mysql sh -c 'exec mysqldump -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot --default-character-set=utf8 --result-file="/var/script/$FILENAME" -p --databases "$DB_NAME"'
	else
		echo "Dumping database ${3} to SQL file dump.sql."
		docker run -it --link "${2}":mysql -v $PWD:/var/script -e DB_NAME="${3}" --rm mysql sh -c 'exec mysqldump -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p --default-character-set=utf8 --result-file="/var/script/dump.sql" --databases "$DB_NAME" > "/var/script/dump.sql"'
	fi
}

function mysqlScript() {
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
		docker run -it --link "${2}" -v $DIR:/var/script -e SQL_SCRIPT="${FILE}" -e DB_NAME="${4}" --rm mysql sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p --default-character-set=utf8 "$DB_NAME" < "/var/script/$SQL_SCRIPT"'
	else
		local DIR=$(dirname "${3}")
		local FILE=$(basename "${3}")
		echo "You did not provide a database name."
		echo "Please make sure you have a USE DB_NAME statement at the beginning of your script."
		if confirm "Proceed? [y/N]"; then
			echo "Running script ${3} in container ${2}."
			docker run -it --link "${2}":mysql -v $DIR:/var/script -e FILENAME="${FILE}" --rm mysql sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p --default-character-set=utf8 < "/var/script/$FILENAME"'
		else
			echo "Aborting."
			exit 0
		fi
	fi
}

function mysqlStatus() {
	local loc_command=status
	local loc_usage="usage: $PROGRAM ${loc_command}"

	if [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		docker ps -a | grep CREATED
		docker ps -a | grep mysql
	fi
}

function mysqlLogs() {
	local loc_command=logs
	local loc_usage="usage: $PROGRAM ${loc_command} CONTAINER_NAME"

	if [[ -z "$2" ]]; then
		echo "You must provide a container name."
		echo "${loc_usage}"
		exit 1
	elif [[ "$2" == "--help" ]]; then
		echo "${loc_usage}"
		exit 0
	else
		docker logs "${2}"
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
