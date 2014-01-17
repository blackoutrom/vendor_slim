#!/bin/bash

usage()
{
	echo -e ""
	echo -e ${txtbld}"Usage:"${txtrst}
	echo -e "  build_blk.sh [options] device"
	echo -e ""
	echo -e ${txtbld}"  Options:"${txtrst}
#	echo -e "    -c  Clean before build"
#	echo -e "    -d  Use dex optimizations"
#	echo -e "    -i  Static Initlogo"
	echo -e "    -j# Set jobs"
#	echo -e "    -s  Sync before build"
#	echo -e "    -p  Build using pipe"
	echo -e ""
	echo -e ${txtbld}"  Example:"${txtrst}
	echo -e "    ./build-blk.sh -c jfltespr"
	echo -e ""
	exit 1
}

# colors
. ./vendor/slim/tools/colors

if [ ! -d ".repo" ]; then
	echo -e ${red}"No .repo directory found.  Is this an Android build tree?"${txtrst}
	exit 1
fi
if [ ! -d "vendor/slim" ]; then
	echo -e ${red}"No vendor/slim directory found.  Is this a Blackout ROM build tree?"${txtrst}
	exit 1
fi

# get OS (linux / Mac OS x)
IS_DARWIN=$(uname -a | grep Darwin)
if [ -n "$IS_DARWIN" ]; then
	CPUS=$(sysctl hw.ncpu | awk '{print $2}')
	DATE=gdate
else
	CPUS=$(grep "^processor" /proc/cpuinfo | wc -l)
	DATE=date
fi

export USE_CCACHE=1

#opt_clean=0
#opt_dex=0
#opt_initlogo=0
opt_jobs="$CPUS"
#opt_sync=0
#opt_pipe=0

while getopts "cdij:ps" opt; do
	case "$opt" in
#	c) opt_clean=1 ;;
#	d) opt_dex=1 ;;
#	i) opt_initlogo=1 ;;
	j) opt_jobs="$OPTARG" ;;
#	s) opt_sync=1 ;;
#	p) opt_pipe=1 ;;
	*) usage
	esac
done
shift $((OPTIND-1))
if [ "$#" -ne 1 ]; then
	usage
fi
device="$1"

# get current version
eval $(grep "^BLK_VERSION_" vendor/slim/config/common.mk | sed 's/ *//g')
VERSION="$PRODUCT_VERSION_MAJOR.$PRODUCT_VERSION_MINOR.$PRODUCT_VERSION_MAINTENANCE"

echo -e ${cya}"Building ${bldgrn}slim ROM ${bldylw}v$VERSION"${txtrst}

# Blackout ROM device dependencies
#echo -e ""
#echo -e ${bldblu}"Looking for Blackout ROM product dependencies${txtrst}"${cya}
#vendor/blackout/tools/getdependencies.py "$device"
#echo -e "${txtrst}"

#if [ "$opt_clean" -ne 0 ]; then
#	make clean >/dev/null
#fi

# download prebuilt files
if [ -x "vendor/cm/get-prebuilts" -a ! -d "vendor/cm/proprietary" ]; then
	echo -e ""
	echo -e ${bldblu}"Downloading prebuilts"${txtrst}
	vendor/cm/get-prebuilts
	echo -e ""
fi

# sync with latest sources
#if [ "$opt_sync" -ne 0 ]; then
#	echo -e ""
#	echo -e ${bldblu}"Fetching latest sources"${txtrst}
#	repo sync -j"$opt_jobs"
#	echo -e ""
#fi

rm -f out/target/product/$device/obj/KERNEL_OBJ/.version

# get time of startup
t1=$($DATE +%s)

# setup environment
echo -e ${bldblu}"Setting up environment"${txtrst}
. build/envsetup.sh

# Remove system folder (this will create a new build.prop with updated build time and date)
rm -f out/target/product/$device/system/build.prop
rm -f out/target/product/$device/system/app/*.odex
rm -f out/target/product/$device/system/framework/*.odex

# initlogo
#if [ "$opt_initlogo" -ne 0 ]; then
#	export BUILD_WITH_STATIC_INITLOGO=true
#fi

# lunch device
echo -e ""
echo -e ${bldblu}"Lunching device"${txtrst}
lunch "slim_$device-userdebug";

echo -e ""
echo -e ${bldblu}"Starting compilation"${txtrst}

# start compilation
#if [ "$opt_dex" -ne 0 ]; then
#	export WITH_DEXPREOPT=true
#fi

#if [ "$opt_pipe" -ne 0 ]; then
#	export TARGET_USE_PIPE=true
#fi

make -j"$opt_jobs" bacon
echo -e ""

# squisher
vendor/slim/tools/squisher

# cleanup unused built
rm -f out/target/product/$device/cm-*.*
rm -f out/target/product/$device/blk_*-ota*.zip

# finished? get elapsed time
t2=$($DATE +%s)

tmin=$(( (t2-t1)/60 ))
tsec=$(( (t2-t1)%60 ))

echo -e ${bldgrn}"Total time elapsed:${txtrst} ${grn}$tmin minutes $tsec seconds"${txtrst}
