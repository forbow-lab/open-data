#!/bin/bash

Usage() {
	echo
	echo "Usage: `basename $0` -p <project> -s <site>"
	echo
	echo "Example: `basename $0` -p ADHD200 -s Peking_1"
	echo
	exit 1
}

if [ "$HOSTNAME" != "mars" ]; then
	echo "*** ERROR: this script must be run from MARS"
	exit 1
fi

SCRIPT=$(python3 -c "from os.path import abspath; print(abspath('$0'))")
SCRIPTDIR=$(dirname $SCRIPT)
echo " + SCRIPTDIR=${SCRIPTDIR}"


POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -p|--project)
      PROJECT="$2"
      shift # past arg-name
      shift # past value
      ;;
    -s|--site)
      SITE="$2"
      shift # past arg-name
      shift # past value
      ;;
    -h|--help|--usage)
      Usage
      shift
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past arg-name
      ;;
  esac
done

## ensure required inputs were specified
if [[ -z "$PROJECT" ]]; then
	echo " * missing input -p <project>"
	Usage
fi
if [[ -z "$SITE" ]]; then
	echo " * missing input -s <site>"
	Usage
fi

echo " +++ `date`, starting: $(basename $0) -p ${PROJECT} -s ${SITE}"


EDIR=/data/OpenDatasets/
PROJ_DIR=$EDIR/$PROJECT
SITE_DIR=$PROJ_DIR/$SITE
mkdir -p $SITE_DIR/
cd $SITE_DIR/


## -- download code here ...
## *FUTURE:
##   +rsync -auxH --no-p --no-g chelmick@cedar:/home/chelmick/fmri/$PROJECT/$SITE/tar_derivs/ $SITE_DIR/tar_derivs 


## -- unpack derivs
## *FUTURE: 
##   +change tar script to remove leading paths before compression...
cd $SITE_DIR/tar_derivs/fmriprep
mkdir -p $SITE_DIR/derivatives/fmriprep/
if [ -r "top_level_files.tar.gz" ]; then
	tar zxvf top_level_files.tar.gz -C $SITE_DIR/derivatives/fmriprep/
fi
for t in `ls sub-*.tar.gz`; do 
	if [ ! -r "${t}.md5" ]; then
		echo "*** ERROR: could not find md5 for file = `pwd`/${t}"
		continue
	fi
	msg=$(md5sum -c --quiet --status ${t}.md5)
	if [ "$?" -eq 1 ]; then
		echo "*** ERROR: md5sum failed for file = `pwd`/${t}, message={$msg}"
		continue
	fi
	tar zxvf $t -C $PROJ_DIR
done


cd $SITE_DIR/tar_derivs/freesurfer
mkdir -p $SITE_DIR/derivatives/freesurfer/
if [ -r "top_level_files.tar.gz" ]; then
	tar zxvf top_level_files.tar.gz -C $SITE_DIR/derivatives/freesurfer/
fi
for t in `ls sub-*.tar.gz`; do
	if [ ! -r "${t}.md5" ]; then
		echo "*** ERROR: could not find md5 for file = `pwd`/${t}"
		continue
	fi
	msg=$(md5sum -c --quiet --status ${t}.md5)
	if [ "$?" -eq 1 ]; then
		echo "*** ERROR: md5sum failed for file = `pwd`/${t}, message={$msg}"
		continue
	fi
	tar zxvf $t -C $PROJ_DIR
done

exit 0
