#!/bin/bash
BUILD_CONFIG=.buildconfig

function mk_error()
{
	echo -e "\033[47;31mERROR: $*\033[0m"
}

function mk_info()
{
	echo -e "\033[47;30mINFO: $*\033[0m"
}

#selectconfig=(
#LICHEE_ARCH
#LICHEE_KERN_VER
#)
#
#boardconfig=(
#${selectconfig[@]}
#LICHEE_KERNEL_VERSION
#LICHEE_KERN_DEFCONF
#LICHEE_KERN_DEFCONF_RT
#LICHEE_BUILDING_SYSTEM
#LICHEE_BR_VER
#LICHEE_BR_DEFCONF
#LICHEE_DEFCONFIG_FRAGMENT
#LICHEE_PRODUCT
#LICHEE_BRANDY_VER
#LICHEE_BRANDY_DEFCONF
#LICHEE_BRANDY_UBOOT_VER
#LICHEE_BRANDY_BUILD_OPTION
#LICHEE_COMPILER_TAR
#LICHEE_ROOTFS
#LICHEE_RAMFS
#LICHEE_BUSSINESS
#LICHEE_BR_RAMFS_CONF
#LICHEE_CHIP
#LICHEE_RTOS_PROJECT_NAME
#LICHEE_DSP_PROJECT_NAME
#LICHEE_PACK_HOOK
#LICHEE_PACK_SECURE_TYPE
#LICHEE_REDUNDANT_ENV_SIZE
#LICHEE_ONE_ENV_SIZE
#LICHEE_BRANDY_SPL
#LICHEE_COMPRESS
#LICHEE_NO_RAMDISK_NEEDED
#LICHEE_RAMDISK_PATH
#LICHEE_KERN_DEFCONF_RECOVERY
#LICHEE_USE_INDEPENDENT_BSP
#LICHEE_INDEPENDENT_PACK
#LICHEE_BOOT0_BIN_NAME
#LICHEE_EFEX_BIN_NAME
#LICHEE_EFEX_DEFCONF
#LICHEE_UPDATE_BOOTIMG
#ANDROID_CLANG_PATH
#ANDROID_TOOLCHAIN_PATH
#ANDROID_CLANG_ARGS
#LICHEE_BSP_STAGING
#LICHEE_GEN_BOOT0_DTS_INFO
#)
#
#allconfig=(
#${boardconfig[@]}
#LICHEE_PLATFORM
#LICHEE_LINUX_DEV
#LICHEE_IC
#LICHEE_BOARD
#LICHEE_FLASH
#LICHEE_KERN_SYSTEM
#LICHEE_KERN_DEFCONF_RELATIVE
#LICHEE_KERN_DEFCONF_ABSOLUTE
#LICHEE_KERN_DEFCONF_RECOVERY_RELATIVE
#LICHEE_KERN_DEFCONF_RECOVERY_ABSOLUTE
#LICHEE_CROSS_COMPILER
#CONFIG_SESSION_SEPARATE
#LICHEE_TOP_DIR
#LICHEE_CBBPKG_DIR
#LICHEE_BRANDY_DIR
#LICHEE_BUILD_DIR
#LICHEE_BR_DIR
#LICHEE_DEVICE_DIR
#LICHEE_KERN_DIR
#LICHEE_BSP_DIR
#BSP_TOP
#LICHEE_PLATFORM_DIR
#LICHEE_SATA_DIR
#LICHEE_DRAGONABTS_DIR
#LICHEE_DRAGONBAORD_DIR
#LICHEE_TOOLS_DIR
#CONFIG_SESSION_SEPARATE
#LICHEE_COMMON_CONFIG_DIR
#LICHEE_CHIP_CONFIG_DIR
#LICHEE_BOARD_CONFIG_DIR
#LICHEE_PRODUCT_CONFIG_DIR
#CONFIG_SESSION_SEPARATE
#LICHEE_OUT_DIR
#LICHEE_BRANDY_OUT_DIR
#LICHEE_BR_OUT
#LICHEE_PACK_OUT_DIR
#LICHEE_TOOLCHAIN_PATH
#LICHEE_PLAT_OUT
#LICHEE_BOARDCONFIG_PATH
#LICHEE_ARISC_PATH
#LICHEE_DRAMLIB_PATH
#LICHEE_KERN_NAME
#LICHEE_KERN_TYPE
#)

function parse_common_parameters()
{
	# some parameters that represent the build target for function mk_autoconfig()
	DEFINE_string  'ic'       ''          'ic to build, e.g. V316'             'i'
	DEFINE_string  'kernel'   ''          'Kernel to build, e.g. 3.3'          'k'
	DEFINE_string  'board'    ''          'Board to build, e.g. evb'           'b'
	DEFINE_string  'flash'    'default'   'flash to build, e.g. nor'           'n'
	DEFINE_string  'os'       ''          'os to build, e.g. android bsp'      'o'
	DEFINE_string  'arch'     ''          'arch to build, e.g. arm arm64'      'a'
	DEFINE_string  'sata_mod' 'all'       'sata module to build when build sata, e.g. all, spi, pinctrl, ...' 's'
	DEFINE_string  'jobs'     '1'         'how many jobs to build, e.g. 16'    'j'

	FLAGS "$@" || exit $?
	eval set -- "${FLAGS_ARGV}"

	FLAGS_IC=${FLAGS_ic}
	FLAGS_PLATFORM=${FLAGS_os}
	FLAGS_BOARD=${FLAGS_board}
	FLAGS_FLASH=${FLAGS_flash}
	FLAGS_KERN=${FLAGS_kernel}
	FLAGS_ARCH=${FLAGS_arch}
	FLAGS_SATA_MODE=${FLAGS_sata_mod}
	FLAGS_JOBS=${FLAGS_jobs}
}

function export_important_variable()
{
	export LICHEE_TOP_DIR=$(pwd)
	export LICHEE_PACK_OUT_DIR=${LICHEE_TOP_DIR}/out/pack_out
	export LICHEE_PLAT_OUT=${LICHEE_TOP_DIR}/image
	# define importance variable
	export LICHEE_BUILD_DIR=${LICHEE_TOP_DIR}/build
	#export LICHEE_TOP_DIR=$(cd $LICHEE_BUILD_DIR/.. && pwd)
	export LICHEE_DEVICE_DIR=${LICHEE_TOP_DIR}/device
	export LICHEE_PLATFORM_DIR=${LICHEE_TOP_DIR}/platform
	export LICHEE_SATA_DIR=${LICHEE_TOP_DIR}/test/SATA
	export LICHEE_DRAGONBAORD_DIR=${LICHEE_TOP_DIR}/test/dragonboard
	export LICHEE_DRAGONABTS_DIR=${LICHEE_TOP_DIR}/test/dragonabts
	export LICHEE_TOOLS_DIR=${LICHEE_TOP_DIR}/tools
	export LICHEE_COMMON_CONFIG_DIR=${LICHEE_DEVICE_DIR}/config/common
	export LICHEE_OUT_DIR=$LICHEE_TOP_DIR/out
	[ -z "${LICHEE_TOOLCHAIN_PATH}" ] && \
	export LICHEE_TOOLCHAIN_PATH=${LICHEE_OUT_DIR}/external-toolchain/gcc-arm
	export LICHEE_ARISC_PATH=${LICHEE_TOP_DIR}/brandy/arisc
	export LICHEE_DRAMLIB_PATH=${LICHEE_TOP_DIR}/brandy/dramlib
	export LICHEE_BSP_DIR=${LICHEE_TOP_DIR}/bsp

	# make surce at the top directory of lichee
	if [ ! -d ${LICHEE_BUILD_DIR} -o \
		! -d ${LICHEE_DEVICE_DIR} ] ; then
		mk_error "You are not at the top directory of lichee."
		mk_error "Please changes to that directory."
		return 1
	fi

	mkdir -p $LICHEE_OUT_DIR
}

#eg. save_config "LICHEE_PLATFORM" "$LICHEE_PLATFORM" $BUILD_CONFIG
function save_config()
{
	local cfgkey=$1
	local cfgval=$2
	local cfgfile=$3
	local dir=$(dirname $cfgfile)
	[ ! -d $dir ] && mkdir -p $dir
	cfgval=$(echo -e "$cfgval" | sed -e 's/^\s\+//g' -e 's/\s\+$//g')
	if [ -f $cfgfile ] && [ -n "$(sed -n "/^\s*export\s\+$cfgkey\s*=/p" $cfgfile)" ]; then
		sed -i "s|^\s*export\s\+$cfgkey\s*=\s*.*$|export $cfgkey=$cfgval|g" $cfgfile
	else
		echo "export $cfgkey=$cfgval" >> $cfgfile
	fi
}

function save_config_to_buildconfig()
{
	local cfgkey=""
	local cfgval=""

	for cfgkey in ${allconfig[@]}; do
		[ "x$cfgkey" == "xCONFIG_SESSION_SEPARATE" ] && continue
		cfgval="$(eval echo '$'${cfgkey})"
		save_config "$cfgkey" "$cfgval" $BUILD_CONFIG
	done
}

function update_bin_path()
{
	local PACK_PLATFORM=$LICHEE_PLATFORM
	[ "x${LICHEE_PLATFORM}" != "xandroid" ] && PACK_PLATFORM=$LICHEE_LINUX_DEV

	local possible_bin_path=(
		bin
		${LICHEE_BUSSINESS}/bin
		configs/${LICHEE_BOARD}/bin
		configs/${LICHEE_BOARD}/${LICHEE_BUSSINESS}/bin
		configs/${LICHEE_BOARD}/${PACK_PLATFORM}/bin
		configs/${LICHEE_BOARD}/${PACK_PLATFORM}/${LICHEE_BUSSINESS}/bin
	)
	export LICHEE_POSSIBLE_BIN_PATH="\"${possible_bin_path[@]}\""
	save_config "LICHEE_POSSIBLE_BIN_PATH" "$LICHEE_POSSIBLE_BIN_PATH" ${BUILD_CONFIG}
}

function prepare_buildserver()
{
	echo "LICHEE_TOP_DIR:${LICHEE_TOP_DIR}---"
	(
		cd $LICHEE_TOP_DIR/tools/build
		if [ -f buildserver ]; then
			mk_info "prepare_buildserver"
			./buildserver --path $LICHEE_TOP_DIR >/dev/null &
		fi
	)
}

function clbuildserver()
{
	echo "LICHEE_TOP_DIR:${LICHEE_TOP_DIR}---"
	local pidlist=($(lsof 2>/dev/null | awk '$9~"'$LICHEE_TOP_DIR/tools/build/buildserver'"{print $2}'))
	mk_info "clean buildserver"
	for pid in ${pidlist[@]}; do
		kill -9 $pid
	done
}

function parse_boardconfig()
{
	#check_env

	export LICHEE_CHIP_CONFIG_DIR=${LICHEE_DEVICE_DIR}/config/chips/${LICHEE_IC}
	export LICHEE_BOARD_CONFIG_DIR=${LICHEE_DEVICE_DIR}/config/chips/${LICHEE_IC}/configs/${LICHEE_BOARD}

	local default_config_android="${LICHEE_CHIP_CONFIG_DIR}/configs/default/BoardConfig_android.mk"
	local default_config_nor="${LICHEE_CHIP_CONFIG_DIR}/configs/default/BoardConfig_nor.mk"
	local default_config="${LICHEE_CHIP_CONFIG_DIR}/configs/default/BoardConfig.mk"

	local special_config_condition="${LICHEE_CHIP_CONFIG_DIR}/configs/default/BoardConfig-conditions.mk"
	local special_config_android="${LICHEE_BOARD_CONFIG_DIR}/android/BoardConfig.mk"
	local special_config_linux_nor="${LICHEE_BOARD_CONFIG_DIR}/${LICHEE_LINUX_DEV}/BoardConfig_nor.mk"
	local special_config_linux="${LICHEE_BOARD_CONFIG_DIR}/${LICHEE_LINUX_DEV}/BoardConfig.mk"
	local special_config="${LICHEE_BOARD_CONFIG_DIR}/BoardConfig.mk"
	local special_config_nor="${LICHEE_BOARD_CONFIG_DIR}/BoardConfig_nor.mk"

	local config_list=""
	# find BoardConfig.mk path
	# Note: Order is important in config_list
	if [ "x${LICHEE_PLATFORM}" = "xandroid" ]; then
		config_list=($default_config $default_config_android $special_config $special_config_android)
	elif [ "x${LICHEE_PLATFORM}" = "xlinux" ]; then
		config_list=($default_config $default_config_nor $special_config $special_config_linux $special_config_nor $special_config_linux_nor)
		[ ${LICHEE_FLASH} != "nor" ] && config_list=($default_config $special_config $special_config_linux)
	else
		mk_error "Unsupport LICHEE_PLATFORM!"
		exit 1
	fi

	> $LICHEE_OUT_DIR/BoardConfig-select.mk
	config_list+=($LICHEE_OUT_DIR/BoardConfig-select.mk)
	config_list+=($special_config_condition)

	local fetch_list=""
	local fpare_list=""
	for f in ${config_list[@]}; do
		if [ -f $f ]; then
			fetch_list=(${fetch_list[@]} $f)
			fpare_list="$fpare_list -f $f"
		fi
	done

	local v_cfg=""
	for f in ${config_list[@]}; do
		v_cfg=$(echo $f | sed "s|\.mk$|-${LICHEE_KERN_VER#*-}.mk|g")
		if [ -f $v_cfg ]; then
			fetch_list=(${fetch_list[@]} $v_cfg)
			fpare_list="$fpare_list -f $v_cfg"
		fi
	done

	if [ -z "${fetch_list[0]}" ]; then
		mk_error "BoardConfig not found!"
		exit 1
	fi

	export LICHEE_BOARDCONFIG_PATH="\"${fetch_list[@]}\""

	#parse BoardConfig.mk
	local cfgkey=""
	local cfgval=""
	local cfgenv=""
	local includes="--include-dir $LICHEE_TOP_DIR --include-dir $LICHEE_CHIP_CONFIG_DIR"

	if [ "x${LICHEE_PLATFORM}" = "xandroid" ]; then
		get_android_top_path
		[ -n "$ANDROID_TOP_PATH" ] && \
		includes+=" --include-dir $ANDROID_TOP_PATH"
	fi

	for cfgkey in ${selectconfig[@]}; do
		eval cfgval="$""$cfgkey"
		eval "$cfgkey='$cfgval'"
		[ "$cfgkey" == "LICHEE_KERN_VER" ] && [ -n "$cfgval" ] && LICHEE_KERN_VER="linux-${LICHEE_KERN_VER/linux-/}"
		[ -n "$cfgval" ] && echo "$cfgkey := $cfgval" >> $LICHEE_OUT_DIR/BoardConfig-select.mk
	done

	for cfgkey in ${boardconfig[@]}; do
		cfgval="$(echo '__unique:;@echo ${'"$cfgkey"'}' | make $includes -f - $fpare_list --no-print-directory __unique)"
		eval cfgenv="$""$cfgkey"
		if [ -n "$cfgenv" ] && [[ "${selectconfig[@]}"  =~ "$cfgkey" ]]; then
			eval "$cfgkey='$cfgenv'"
		else
			eval "$cfgkey='$cfgval'"
		fi
	done
	[ -n "$LICHEE_KERN_VER" ] && LICHEE_KERN_VER="linux-${LICHEE_KERN_VER/linux-/}"
	rm -rf ${LICHEE_OUT_DIR}/BoardConfig-select.mk
}

function mk_autoconfig()
{
	parse_common_parameters $@
	# we have do clean_old_var() before auto_config(), so that we need export the variable again
	export_important_variable
	local IC=${FLAGS_IC}
	local platform=${FLAGS_PLATFORM}
	local board=${FLAGS_BOARD}
	local flash=${FLAGS_FLASH}
	local linux_ver=${FLAGS_KERN}
	local linux_arch=${FLAGS_ARCH}
	local sata_mod=${FLAGS_SATA_MODE}
	local linux_dev=""

	if [ "${platform}" != "android" ]; then
		linux_dev=${platform}
		platform="linux"
	fi

	export LICHEE_IC=${IC}
	export LICHEE_BOARD=${board}
	export LICHEE_PLATFORM=${platform}
	export LICHEE_FLASH=${flash}
	export LICHEE_LINUX_DEV=${linux_dev}

	if [ "x$linux_dev" = "xsata" ] && [ "x$sata_mod" != "x" ];then
	    export LICHEE_BTEST_MODULE=$sata_mod
	fi

	if [ -n "${linux_ver}" ]; then
		LICHEE_KERN_VER=${linux_ver}
		LICHEE_KERN_NAME=${linux_ver}
		if [[ ${linux_ver} == *_* ]]; then
			LICHEE_KERN_VER=${linux_ver%_*}
			LICHEE_KERN_TYPE=${linux_ver#*_}
		fi
	fi

	#parse boardconfig
	parse_boardconfig

	#if [ -n "${linux_arch}" ]; then
	#	export LICHEE_ARCH=${linux_arch}
	#fi

	#if [ -z "${LICHEE_ARCH}" ]; then
	#	mk_error "can not find LICHEE_ARCH."
	#	exit 1
	#else
	#	if [ "x${LICHEE_ARCH}" = "xarm" ]; then
	#		LICHEE_KERNEL_ARCH=arm
	#	fi

	#	if [ "x${LICHEE_ARCH}" = "xarm64" ]; then
	#		LICHEE_KERNEL_ARCH=arm64
	#	fi

	#	if [ "x${LICHEE_ARCH}" = "xriscv64" -o "x${LICHEE_ARCH}" = "xriscv32" ]; then
	#		LICHEE_KERNEL_ARCH=riscv
	#	fi

	#	save_config "LICHEE_KERNEL_ARCH" ${LICHEE_KERNEL_ARCH} $BUILD_CONFIG
	#fi

	#if [ -z "${LICHEE_KERN_NAME}" ]; then
	#	LICHEE_KERN_NAME=${LICHEE_KERN_VER}
	#fi

	#save config to buildconfig
	save_config_to_buildconfig

	#update amp firmware address
	update_bin_path

	#restart buildserver
	clbuildserver
	prepare_buildserver

	cp $BUILD_CONFIG ${LICHEE_OUT_DIR}/${LICHEE_IC}/${LICHEE_BOARD}/openwrt/
}


function pack()
{
	local cfg_dir="$(pwd)/image"
	echo "cfg_dir:${cfg_dir}----"
    [ ! -e ${cfg_dir}/.buildconfig ] && \
	echo  "Not found .buildconfig,  Please cd aw_pack_src, then ./aw_pack.sh" &&  \
	return -1;

    local chip=$(cat ${cfg_dir}/.buildconfig | sed -n 's/^.*LICHEE_CHIP=\(.*\)$/\1/g'p)
    local platform=$(cat ${cfg_dir}/.buildconfig | sed -n 's/^.*LICHEE_LINUX_DEV=\(.*\)$/\1/g'p)
    local lichee_ic=$(cat ${cfg_dir}/.buildconfig | \
	    sed -n 's/^.*LICHEE_IC=\(.*\)$/\1/g'p)

    local lichee_board=$(cat ${cfg_dir}/.buildconfig | \
	    sed -n 's/^.*LICHEE_BOARD=\(.*\)$/\1/g'p)

    local lichee_kernel_ver=$(cat ${cfg_dir}/.buildconfig | \
	    sed -n 's/^.*LICHEE_KERN_VER=\(.*\)$/\1/g'p)

    local flash=$(cat ${cfg_dir}/.buildconfig | sed -n 's/^.*LICHEE_FLASH=\(.*\)$/\1/g'p)

	source ./build/shflags
	if [ ! -f ./image/tmp_parse_config ]; then
		echo "no ./image/tmp_parse_config, return"
		return 1
	fi
	source ./image/tmp_parse_config
	mk_autoconfig -o openwrt -i ${lichee_ic} -b ${lichee_board} -n ${flash}


    local debug=uart0
    local sigmode=none
    local verity=
    local mode=normal
    local programmer=none
    local tar_image=none
    unset OPTIND

    while getopts "dsvmwih" arg
    do
        case $arg in
            d)
                debug=card0
                ;;
            s)
                sigmode=secure
                ;;
            v)
                verity="--verity"
                ;;
            m)
                mode=dump
                ;;
            w)
                programmer=programmer
                ;;
            i)
                tar_image=tar_image
                ;;
            h)
                pack_usage
                return 0
                ;;
            ?)
            return 1
            ;;
        esac
    done

	echo "pack -c $chip -i ${lichee_ic} -p ${platform} -b ${lichee_board} -k $lichee_kernel_ver -d $debug -v $sigmode -m $mode -w $programmer -n ${flash} ${verity}"
	./build/pack -c $chip -i ${lichee_ic} -p ${platform} -b ${lichee_board} -k $lichee_kernel_ver -d $debug -v $sigmode -m $mode -w $programmer -n ${flash} ${verity}

	[ "$?" -ne "0" ] && return 1
	./build/collect_flash_image.sh ./out/pack_out ./flash_image
}

pack "$@"
