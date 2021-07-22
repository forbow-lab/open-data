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

## ensure site.tar does not already exists
PROJECT_DIR_TAPE=/project/6009072/fmri
DERIVS_TAR_DIR=$PROJECT_DIR_TAPE/$PROJECT/Tar_DERIVS
mkdir -p $DERIVS_TAR_DIR/
DERIVS_TAR=$DERIVS_TAR_DIR/${SITE}.tar

if [ -r "$DERIVS_TAR" ]; then
	echo " * Warning: found existing derivatives archive = $DERIVS_TAR"
	exit 2
fi

SCRATCH_DIR_SSD=$SCRATCH/fmri
SCRATCH_SITE_DIR=$SCRATCH_DIR_SSD/$PROJECT/$SITE

if [ ! -r "$SCRATCH_SITE_DIR/derivatives/fmriprep/dataset_description.json" ]; then
	echo "*** ERROR: could not locate site derivatives = $SCRATCH_SITE_DIR/derivatives/"
	exit 3
fi


### ENSURE NO RUNNING JOBS FROM THIS SITE!!!!


SLURM_LOG_DIR=$PROJECT_DIR_TAPE/slurm_logs/${PROJECT}_${SITE}
echo " ++ copying slurm_log files into derivatives = $SCRATCH_SITE_DIR/"
rsync -rtluv $SLURM_LOG_DIR $SCRATCH_SITE_DIR/slurm_logs

## create site-derivs-archive, move to project-space, and report disk-usage
TEMP_TAR=$SCRATCH_DIR_SSD/$PROJECT/${SITE}.tar
echo " ++ creating initial archive=${TEMP_TAR} from $SCRATCH_SITE_DIR/"
tar -cvf ${DERIVS_TAR} $SCRATCH_SITE_DIR/
if [ $? -ne 0 ]]; then
	echo "*** ERROR: tar-command failed, please try again..."
	exit 2
fi
echo " ++ tar successful, size=comparison:"
du -sh $SCRATCH_SITE_DIR/ ${TEMP_TAR}

echo " ++ copying initial archive=${TEMP_TAR} to ${DERIVS_TAR}"
rsync -rtlv ${TEMP_TAR} ${DERIVS_TAR}
if [ $? -ne 0 ]]; then
	echo "*** ERROR: rsync tar to PROJECT-drive failed, please try again..."
	exit 2
fi
du -sh $SCRATCH_SITE_DIR/ ${TEMP_TAR} ${DERIVS_TAR}
rm -fv ${TEMP_TAR}

exit 0
