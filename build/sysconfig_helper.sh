#!/bin/bash

if [ $# -lt 3 ]; then
	echo "usage:"
	echo "$0 filepath get mainkey subkey"
	echo "$0 filepath set mainkey subkey newval"
	exit 0
fi

sysconf="$1"

if [ ! -f $sysconf ]; then
	echo "$sysconf file not exist"
	exit
fi

function sysconf_get_line()
{
	local mainkey=$1
	local subkey=$2
	awk '
		BEGIN {
			find_main = 0
		}
		/^;?\[.*\]/ {
			match($0,/\[(.+)\]/,array)
			if (RSTART != 0 && array[1] == "'"$mainkey"'")
				find_main = 1
			else
				find_main = 0
			next
		}
		// {
			if (find_main == 0)
				next
			match($0,/^\s*;?\s*(\S+)*\s*=\s*([^\s]*)$/,array)
			if (RSTART != 0 && array[1] == "'$subkey'") {
				printf "%d\n", NR
				exit
			}
		}
	' $sysconf
}

function sysconf_get_val()
{
	local line=$(sysconf_get_line $1 $2)

	if ! expr "$line" + 0 > /dev/null 2>&1; then
		echo "can't find $1 $2 in $sysconf"
		exit
	fi

	sed -n "${line}s/\(.*=\s*\)\([^\s]*\)/\2/p" $sysconf
}

function sysconf_set_val()
{
	local newval=$3
	local line=$(sysconf_get_line $1 $2)
	local ori_val=$(sysconf_get_val $1 $2)

	if ! expr "$line" + 0 > /dev/null 2>&1; then
		echo "can't find $1 $2 in $sysconf"
		exit
	fi

	if [ "x$newval" = "x$ori_val" ]; then
		exit
	fi

	sed -i "${line}s/\(.*=\s*\)\([^\s]*\)/\1${newval}/" $sysconf
}

case "$2" in
	get)
		sysconf_get_val $3 $4
	;;
	set)
		sysconf_set_val $3 $4 $5
	;;
esac
