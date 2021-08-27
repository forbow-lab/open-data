#!/bin/bash
##
## find problem subjects that SLURM cancelled due to time-limits
##

Usage() {
	echo
	echo "Usage: `basename $0` -p <project> -s <site> -e <email>"
	echo
	echo "Example: `basename $0` -p ADHD200 -s Peking_1 -e chelmick@dal.ca"
	echo
	exit 1
}

SCRIPT=$(python3 -c "from os.path import abspath; print(abspath('$0'))")
SCRIPTDIR=$(dirname $SCRIPT)
echo " + `date`: starting script = $SCRIPT"

EMAIL_ARR=("chelmick@dal.ca" "vlad.drobinin@dal.ca")
NCPUS=16
RESTART_JOB="no"
DEBUG_MODE="no"
SUBMIT_MODE="no"
EXTRA_ARGS=()
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
    -e|--email)
      EMAIL=$(echo "$2" | awk '{print tolower($0)}')
      shift # past arg-name
      shift # past value
      ;;
    -d|--debug)
      DEBUG_MODE="yes"
      echo " + DEBUG_MODE enabled."
      shift
      ;;
    -h|--help|--usage)
      Usage
      shift
      ;;
    --submit)
      SUBMIT_MODE="yes"
      echo " + SUBMIT_MODE enabled."
      shift
      ;;
    *)    # unknown option
      EXTRA_ARGS+=("$1") # save it in an array for later
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
if [[ -z "$EMAIL" ]]; then
	echo " * missing input -e <email>"
	Usage
else
	eMatch="no"
	for e in ${EMAIL_ARR[@]} ; do
		if [ "$e" == "$EMAIL" ]; then
			eMatch="yes"
			break
		fi
	done
	if [ "$eMatch" == "no" ]; then
		echo " * email=[${EMAIL}] does not match any allowed emails listed=[${EMAIL_ARR[@]}]"
		Usage
	fi
fi


PROJECT_DIR_TAPE=/project/6009072/fmri
SLURM_LOG_DIR=$PROJECT_DIR_TAPE/slurm_logs/${PROJECT}_${SITE}
cd $SLURM_LOG_DIR/

SUBJECT_ARR=()
cjobs=$(grep -rl "DUE TO TIME LIMIT" slurm_fmriprep_${SITE}_*.err)
for j in ${cjobs}; do
	jbase=$(echo $j | awk -F. '{print $1}')
	subj=$(echo $jbase | awk -F- '{print $2}')
	echo " + found cancelled job=${j}, site=$SITE, subj=$subj"
	restart="yes"
	newJ=$(find $SLURM_LOG_DIR -newer ${j} -type f -name "${jbase}.*.err" -print)
	for nj in ${newJ} ; do
		nb=$(echo `basename $nj` | awk -F. '{print $1"."$2}')
		newExitStr=$(grep -rn 'with exit-code=0' `dirname $nj`/${nb}.out) ##line-num of successful-exit
		newExitCode=$(echo "$newExitStr" | awk -F: '{print $1}')
		if [[ "$newExitCode" -gt 0 ]]; then 
			echo " -- found newer joblog.err = $nj, exit-code=${newExitStr}"
			## could check for $PROJECT/$SITE/derivatives/fmriprep/sub-${S}.html
			restart="no"
			break
		fi
	done
	if [ "$restart" == "yes" ]; then 
		SUBJECT_ARR+=("$subj")
	fi
done

if [ "$DEBUG_MODE" == "yes" -a "${#SUBJECT_ARR[@]}" -gt 0 ]; then
	echo " ++DEBUG_MODE: need to restart site=$SITE, subjects_arr=[${SUBJECT_ARR[@]}]"
fi

## build a job-resubmission command, including adding extra NCPUS to finish faster! (default_ncpus=8, takes ~8-11 hrs)
if [ "$SUBMIT_MODE" == "yes" -a "${#SUBJECT_ARR[@]}" -gt 0 ]; then
	cmd="$SCRIPTDIR/PNC_1_slurm_fmriprep_batch.sh -e ${EMAIL} -p $PROJECT -s $SITE -n ${NCPUS} ${SUBJECT_ARR[@]}"
	if [ "$DEBUG_MODE" == "yes" ]; then
		cmd="$SCRIPTDIR/PNC_1_slurm_fmriprep_batch.sh -d -e ${EMAIL} -p $PROJECT -s $SITE -n ${NCPUS} ${SUBJECT_ARR[@]}"
	fi
	echo " ++ restarting site=$SITE, subjects_arr=[${SUBJECT_ARR[@]}]"
	eval ${cmd}
fi

exit 0

### remove bad-scripting jobs
#cjobs=$(grep -rl "FATAL:   container creation failed:" slurm_fmriprep_*.err)
#for jerr in ${cjobs}; do jout="$(basename $jerr .err).out"; cmd="rm -v $jerr $jout"; eval $cmd; done
