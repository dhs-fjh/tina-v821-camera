#!/bin/bash

THIS_DIR=$(cd $(dirname $0); pwd)

#Local Variables
version="0.0.1"
dts_path=""
include_path=""
output_path=""
dtc_path=""
dts_warnning_skip="-W no-unit_address_vs_reg -W no-unit_address_format -W no-simple_bus_reg -W no-pwms_property"

build_dts()
{
	if [ "x${dts_path}" == "x" ] ; then
		echo "dts_path can not be empty!"
		exit 1
	fi

	if [ "x${output_path}" == "x" ] ; then
		# default output_path is dts path
		output_path=${dts_path%/*}
	fi


	if [ "x${dtc_path}" == "x" ] ; then
		# default dtc_path is current path
		dtc_path="${THIS_DIR}/dtc"
	fi

	local dts_filename=$(basename "${dts_path}")
	local dtb_name=${dts_filename%.*}
	local outname="${dtb_name}.dtb"

	dep=${output_path}/dts_dep
	mkdir -p ${dep}

	set -e
	cpp \
	-Wp,-MD,${dep}/.${outname}.d.pre.tmp \
	-nostdinc \
	${include_path} \
	-undef \
	-D__DTS__ \
	-x assembler-with-cpp \
	-o ${dep}/.${outname}.dts.tmp \
	${dts_path}

	${dtc_path} \
	-O dtb \
	-o ${output_path}/${outname} \
	-W no-unit_address_vs_reg \
	-W no-unit_address_format \
	-W no-unique_unit_address\
	-W no-graph_child_address \
	-W no-simple_bus_reg \
	-b 0 \
	-@ \
	-d ${dep}/.${outname}.d.dtc.tmp ${dep}/.${outname}.dts.tmp

	#delete tmp dir and file
	rm -rf ${dep}

	#compile dtb to dts
	${dtc_path} ${dts_warnning_skip} -I dtb -O dts ${output_path}/${outname} > ${output_path}/${dtb_name}-dtb.dts

	echo "OUTPATH: ${output_path}/${outname} ${output_path}/${dtb_name}-dtb.dts"
}

show_usage()
{
	echo "$(basename $0) ${version}"
	echo "Usage: $0 -i /path/to/dts [OPTIONS]"
	echo "OPTIONS:"
	echo "  -I                  Include file path"
	echo "  -o                  Output file path"
	echo "  -t                  Dtc Tool path"
	echo "  -h                  Help"
	echo "  eg: $0 -i /path/to/dts -I /path/to/include1 -I /path/to/include2 -I /path/to/include3 -o /path/to/output"
}

parse_args()
{
	while getopts 'i:I:o:t:h' opt; do
		case $opt in
			i)
				dts_path=$OPTARG
				;;
			I)
				include_path="${include_path} -I $OPTARG"
				;;
			o)
				output_path=$OPTARG
				;;
			t)
				dtc_path=$OPTARG
				;;
			h|*)
				show_usage
				exit 0
				;;
		esac
	done
}

if [ "x$1" == "x" ] ; then
	show_usage
	exit 1
fi

parse_args $@
build_dts
