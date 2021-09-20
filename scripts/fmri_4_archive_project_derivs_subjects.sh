#!/bin/bash

## individually tar fmriprep & freesurfer subject with .html outputs

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

echo " +++ `date`, starting: $(basename $0) -p ${PROJECT} -s ${SITE}"

GRP_PROJECT=/project/6009072/fmri
PDIR=$SCRATCH/fmri/$PROJECT

if [ ! -d "$PDIR/$SITE/derivatives/fmriprep" ]; then
	echo " *** ERROR: could not find derivatives for $PDIR/$SITE/derivatives/fmriprep/"
	Usage
fi
cd $PDIR/
fp_tar_dir=$PDIR/deriv_archives/${PROJECT}_${SITE}_derivatives_fmriprep
fs_tar_dir=$PDIR/deriv_archives/${PROJECT}_${SITE}_derivatives_freesurfer
mkdir -pv $fp_tar_dir/ $fs_tar_dir/
for f in `ls $SITE/derivatives/fmriprep/sub-*.html`; do 
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

## archive top-level files in fmriprep/
cd $SITE/derivatives/fmriprep/
ofp=$fp_tar_dir/top_level_files
tar -vvc --use-compress-program="pigz -p 8" -f ${ofp}.tar.gz ./logs/ ./d*.json ./d*.tsv >${ofp}.index
## archive top-level files in freesurfer/
cd $SITE/derivatives/freesurfer/
ofs=$fs_tar_dir/top_level_files
tar -vvc --use-compress-program="pigz -p 8" -f ${ofs}.tar.gz ./fsaverage/ >${ofs}.index

## calculate md5 for fmriprep and freesurfer .tar.gz files
cd $fp_tar_dir/
for f in `ls *.tar.gz`; do if [ ! -r "${f}.md5" ]; then echo " + calculating `pwd`/${f}.md5"; md5sum $f >${f}.md5 ; fi; done
cd $fs_tar_dir/
for f in `ls *.tar.gz`; do if [ ! -r "${f}.md5" ]; then echo " + calculating `pwd`/${f}.md5"; md5sum $f >${f}.md5 ; fi; done


## --- get slurm_logs
cd $PDIR/deriv_archives/
if [ ! -r "${PROJECT}_${SITE}_slurm_logs.tar.gz" ]; then
	echo " + compressing $GRP_PROJECT/slurm_logs/${PROJECT}_${SITE} -> `pwd`/${PROJECT}_${SITE}_slurm_logs.tar.gz"
	tar -vvc --use-compress-program="pigz -p 8" -f ./${PROJECT}_${SITE}_slurm_logs.tar.gz $GRP_PROJECT/slurm_logs/${PROJECT}_${SITE}/ >./${PROJECT}_${SITE}_slurm_logs.index
	md5sum ${PROJECT}_${SITE}_slurm_logs.tar.gz > ./${PROJECT}_${SITE}_slurm_logs.tar.gz.md5
fi

## --- get resource_monitor_files
cd $PDIR/deriv_archives/
if [ ! -r "${PROJECT}_${SITE}_resource_monitor_files.tar.gz" ]; then
	echo " + compressing $GRP_PROJECT/slurm_logs/${PROJECT}_${SITE} -> `pwd`/${PROJECT}_${SITE}_slurm_logs.tar.gz"
	tar -vvc --use-compress-program="pigz -p 8" -f ./${PROJECT}_${SITE}_resource_monitor_files.tar.gz $PDIR/${SITE}/resource_monitor_files/ >./${PROJECT}_${SITE}_resource_monitor_files.index
	md5sum ${PROJECT}_${SITE}_resource_monitor_files.tar.gz >${PROJECT}_${SITE}_resource_monitor_files.tar.gz.md5
fi

## rsync archives from ~/scratch/ to /project/
cd $PDIR/
mkdir -p $GRP_PROJECT/$PROJECT/Tar_DERIVS/
rsync -auxvH --no-p --no-g ./deriv_archives/ $GRP_PROJECT/$PROJECT/Tar_DERIVS/deriv_archives/
## nohup rsync -axuH --no-p --no-g $PDIR/deriv_archives/ /project/6009072/fmri/${PROJECT}/Tar_DERIVS/deriv_archives/ >>logs/nohup_rsync_deriv_archives_to_project_20210905.txt 2>&1 &

echo " +++ `date`, completed: $(basename $0) -p ${PROJECT} -s ${SITE}"

exit 0
