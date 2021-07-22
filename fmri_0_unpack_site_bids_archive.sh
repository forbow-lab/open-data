#!/bin/bash

Usage() {
	echo
	echo "Usage: `basename $0` -p <project> -s <site>"
	echo
	echo "Example: `basename $0` -p ADHD200 -s Peking_1"
	echo
	exit 1
}

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

## ensure site.tar exists
PROJECT_DIR_TAPE=/project/6009072/fmri
TAR_BIDS_DIR=$PROJECT_DIR_TAPE/$PROJECT/Tar_BIDS/$SITE.tar
if [ ! -r "$TAR_BIDS_DIR" ]; then
	echo "*** ERROR: could not read site-archive = $TAR_BIDS_DIR"
	exit 2
fi

SCRATCH_DIR_SSD=$SCRATCH/fmri
SCRATCH_SITE_DIR=$SCRATCH_DIR_SSD/$PROJECT/$SITE

## unpack site-bids-archive on scratch_ssd, then rename
if [ -r "$SCRATCH_SITE_DIR/BIDS/dataset_description.json" ]; then
	echo " * Warning: found existing archive-output = $SCRATCH_SITE_DIR/BIDS/dataset_description.json"
else
	echo " ++ unpacking archive=${TAR_BIDS_DIR} into $SCRATCH_SITE_DIR/BIDS/"
	mkdir -p $SCRATCH_SITE_DIR/
	cd $SCRATCH_SITE_DIR/
	tar -xvf $TAR_BIDS_DIR 
	mv ./${SITE} ./BIDS
	cd ./BIDS/
	pfile="$SCRATCH_SITE_DIR/BIDS/participants.tsv"
	if [ ! -r "$pfile" ]; then
		echo " ++ creating file = $pfile"
		echo "particpant_id" >$pfile
		for D in $(ls -d sub-*); do
			echo "$D" | awk -F- '{print $2}' >>$pfile
		done
	fi
fi

exit 0
