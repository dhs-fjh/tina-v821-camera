#!/bin/bash

function print_red(){
	echo -e '\033[0;31;1m'
	echo $1
	echo -e '\033[0m'
}

function copy_usage()
{
	echo "Usage: ./collect_flash_image.sh from_dir to_dir"
}

function copy_image()
{
	[ "$#" -ne "2" ] && copy_usage
	echo "copy flash images from $1 to $2"
	local src_dir=$1
	local dst_dir=$2
	local is_secure=0
	rm -rf ${dst_dir}
	mkdir -p ${dst_dir}

	[ x"$(grep "^imagename" -nr ${src_dir}/image.cfg | grep "secure")" != x"" ] && is_secure=1

	local sys_config="${src_dir}/sys_config.fex"
	local flash_type="$( awk -F"=" '/^storage_type/{print $2}' ${sys_config} | sed 's/^[ \t]*//g' | sed 's/\r//g')"

	local uboot_img=boot_package.fex
	case ${flash_type} in
		-1)
			print_red "###storage type error###"
			print_red "###cannot choose boot0, please config storage_type in sys_config ###"
			;;
		*0 | *5)
			local boot0_img=boot0_nand.fex
			;;
		*1 | *2 | *4)
			local boot0_img=boot0_sdcard.fex
			;;
		3)
			local boot0_img=boot0_spinor.fex
			uboot_img=boot_package_nor.fex
			[ -f ${src_dir}/full_img.fex ] && cp ${src_dir}/full_img.fex ${dst_dir}
			;;
		*)
			print_red "###storage type error###"
			print_red "###cannot choose boot0, please config storage_type in sys_config ###"
			;;
	esac

	if [ x"${is_secure}" = x"1" ]; then
		boot0_img=toc0.fex
		uboot_img=toc1.fex
	fi

	#copy boot0,uboot,gpt image
	cp ${src_dir}/${boot0_img} ${dst_dir}
	cp ${src_dir}/${uboot_img} ${dst_dir}
	cp ${src_dir}/sunxi_gpt.fex ${dst_dir}

	local tmp_part=${src_dir}/sys_partition.tmp
	cp ${src_dir}/sys_partition.fex ${tmp_part}

	sed -i '/^[\r;]/d' ${tmp_part}
	sed -i 's/[ "\r]//g' ${tmp_part}
	sed -i '/^[;]/d' ${tmp_part}

	local part_img_list=$(grep "downloadfile" -nr ${tmp_part} | awk -F '=' '{print $2}')

	#copy sys_partition downloadfile
	for file in ${part_img_list[@]}; do
		#echo "cp ${src_dir}/${file} ${dst_dir}"
		cp ${src_dir}/${file} ${dst_dir}
	done
}

#main==============================
copy_image $*
