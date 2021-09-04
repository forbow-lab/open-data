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


PDIR=$SCRATCH/fmri/$PROJECT/
if [ ! -d "$PDIR/$SITE/derivatives/fmriprep" ]; then
	echo " *** ERROR: could not find derivatives for $PDIR/$SITE/derivatives/fmriprep/"
	Usage
fi
cd $PDIR/
fp_tar_dir=$PDIR/${PROJECT}_${SITE}_derivatives_fmriprep
fs_tar_dir=$PDIR/${PROJECT}_${SITE}_derivatives_freesurfer
mkdir -pv $fp_tar_dir/ $fs_tar_dir/
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
for f in `ls sub-*.tar.gz`; do echo " + calculating `pwd`/${f}.md5"; md5sum $f >${f}.md5 ; done
cd $fs_tar_dir/
for f in `ls sub-*.tar.gz`; do echo " + calculating `pwd`/${f}.md5"; md5sum $f >${f}.md5 ; done

exit 0
