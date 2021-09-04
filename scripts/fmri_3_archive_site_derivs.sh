#!/bin/bash

#
#  Must use rsync to copy between /scratch <--> /project
#  https://docs.computecanada.ca/wiki/Frequently_Asked_Questions
#
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

## future: individually tar and transfer each 
##   1. ~/scratch/fmri/PROJECT/SITE/derivatives/fmriprep
##   2. ~/scratch/fmri/PROJECT/SITE/derivatives/freesurfer
##   3. ~/scratch/fmri/PROJECT/SITE/resource_monitor_files
##   4. ~/scratch/fmri/PROJECT/SITE/slurm_logs




SLURM_LOG_DIR=$PROJECT_DIR_TAPE/slurm_logs/${PROJECT}_${SITE}
echo " ++ copying slurm_log files into derivatives = $SCRATCH_SITE_DIR/"
rsync -axvH --no-g --no-p $SLURM_LOG_DIR $SCRATCH_SITE_DIR/slurm_logs

## create site-derivs-archive, move to project-space, and report disk-usage
TEMP_TAR=$SCRATCH_DIR_SSD/$PROJECT/${SITE}.tar
echo " ++ creating initial archive=${TEMP_TAR} from $SCRATCH_SITE_DIR/"
tar -cvvf ${TEMP_TAR} $SCRATCH_SITE_DIR/ >${TEMP_TAR}.index
if [[ $? -ne 0 ]]; then
	echo "*** ERROR: tar-command failed, please try again..."
	exit 2
fi
echo " ++ tar successful, size=comparison:"
du -sh $SCRATCH_SITE_DIR/ ${TEMP_TAR}

echo " ++ copying initial archive=${TEMP_TAR} to ${DERIVS_TAR}"
rsync -axvH --no-g --no-p ${TEMP_TAR} ${DERIVS_TAR}
if [[ $? -ne 0 ]]; then
	echo "*** ERROR: rsync tar to PROJECT-drive failed, please try again..."
	exit 2
fi
du -sh $SCRATCH_SITE_DIR/ ${DERIVS_TAR}
rsync -axvH --no-g --no-p ${TEMP_TAR}.index ${DERIVS_TAR}.index

## create MD5 and check transfers - delete if matching.

exit 0


############################# individually tar fmriprep & freesurfer subject with .html outputs
PROJECT=PNC
SITE=PNC
PDIR=$SCRATCH/fmri/$PROJECT/
cd $PDIR/
fp_tar_dir=$PDIR/${PROJECT}_${SITE}_derivatives_fmriprep
fs_tar_dir=$PDIR/${PROJECT}_${SITE}_derivatives_freesurfer
mkdir -p $fp_tar_dir/ $fs_tar_dir/
for f in `ls $SITE/derivatives/fmriprep/sub-60*.html`; do 
	S=$(basename $f .html)
	## compress fmriprep
	fp=$SITE/derivatives/fmriprep/$S
	ofp=$fp_tar_dir/$S
	if [ ! -r "${ofp}.tar.gz" ]; then
		echo " + compressing ${fp} -> ${ofp}.tar.gz";
		tar -vvc --use-compress-program="pigz -p 8" -f ${ofp}.tar.gz ${fp}* >${ofp}.index
	fi
	## compress freesurfer
	fs=$SITE/derivatives/freesurfer/$S
	ofs=$fs_tar_dir/$S
	if [ ! -r "${ofs}.tar.gz" ]; then
		echo " + compressing ${fs} -> ${ofs}.tar.gz";
		tar -vvc --use-compress-program="pigz -p 8" -f ${ofs}.tar.gz ${fs}* >${ofs}.index
	fi
done

## calculate md5 for fmriprep and freesurfer .tar.gz files
cd $fp_tar_dir/
for f in `ls sub-*.tar.gz`; do md5sum $f >${f}.md5 ; done
cd $fs_tar_dir/
for f in `ls sub-*.tar.gz`; do md5sum $f >${f}.md5 ; done

exit 0
