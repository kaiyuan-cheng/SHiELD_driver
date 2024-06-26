#!/bin/bash -xe

##############################################################################
## User set up variables
## Root directory for CI
dirRoot=/contrib/fv3
## Intel version to be used
intelVersion=2023.2.0
##############################################################################
## HPC-ME container
container=/contrib/containers/noaa-intel-prototype_2023.09.25.sif
container_env_script=/contrib/containers/load_spack_noaa-intel.sh
##############################################################################

#Parse Arguments
branch=main
commit=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--branch)
      branch="$2"
      shift # past argument
      shift # past value
      ;;
    -h|--hash)
      commit="$2"
      shift # past argument
      shift # past value
      ;;
    *)
      echo "unknown argument"
      exit 1
      ;;
  esac
done

echo "branch is $branch"
echo "commit is $commit"


## Set up the directories
testDir=${dirRoot}/${intelVersion}/SHiELD_physics/${branch}/${commit}
logDir=${testDir}/log
export MODULESHOME=/usr/share/lmod/lmod
#Define External Libs path
export EXTERNAL_LIBS=${dirRoot}/${intelVersion}/SHiELD_physics/externallibs
mkdir -p ${EXTERNAL_LIBS}
## create directories
rm -rf ${testDir}
mkdir -p ${logDir}
# salloc commands to start up 
#2 tests layout 8,8 (16 nodes)
#2 tests layout 4,8 (8 nodes)
#9 tests layout 4,4 (18 nodes)
#5 tests layout 4,1 (5 nodes)
#17 tests layout 2,2 (17 nodes)
#salloc --partition=p2 -N 64 -J ${branch} sleep 20m &

## clone code
cd ${testDir}
git clone --recursive https://github.com/NOAA-GFDL/SHiELD_build.git  

##checkout components
cd ${testDir}/SHiELD_build && ./CHECKOUT_code

## Check out the PR
cd ${testDir}/SHiELD_SRC/SHiELD_physcis && git fetch origin ${branch}:toMerge && git merge toMerge

##Check if we already have FMS compiled and recompile if version doesn't match what is in SHiELD_build checkout script
grep -m 1 "fms_release" ${testDir}/SHiELD_build/CHECKOUT_code > ${logDir}/release.txt
source ${logDir}/release.txt
echo ${fms_release}
echo `cat ${EXTERNAL_LIBS}/FMSversion`
if [[ ${fms_release} != `cat ${EXTERNAL_LIBS}/FMSversion` ]]
  then
    #remove libFMS if it exists
    if [ -d $EXTERNAL_LIBS/libFMS ]
      then
        rm -rf $EXTERNAL_LIBS/libFMS
    fi
    if [ -e $EXTERNAL_LIBS/FMSversion ]
      then
        rm $EXTERNAL_LIBS/FMSversion
    fi
    echo $fms_release > $EXTERNAL_LIBS/FMSversion
    echo $container > $EXTERNAL_LIBS/FMScontainerversion
    echo $container_env_script >> $EXTERNAL_LIBS/FMScontainerversion
    # Build FMS
    cd ${testDir}/SHiELD_build/Build
    set -o pipefail
    singularity exec -B /contrib ${container} ${container_env_script} "./BUILDlibfms intel"
 fi
