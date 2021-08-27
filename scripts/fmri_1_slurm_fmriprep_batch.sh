#!/bin/bash

## Notes:
##
## 1) SLURM_TMPDIR variable is unique for each job after submitted, named by user.jobid = /localscratch/chelmick.6990096.0/
##
## 2) /SCRATCH/user/ has 20T capacity, files older than 60days are purged.
##    PROJECT is tape-based, very slow and meant for almost static files (BIDS/, derivatives/)
##    SLURM_TMPDIR is /localscratch/ given when job is submitted
##
Usage() {
	echo
	echo "Usage: `basename $0` -p <project> -s <site> -e <email>"
	echo
	echo "Example: `basename $0` -p ADHD200 -s Peking_1 -e chelmick@dal.ca"
	echo ""
	echo "Options:"
	echo "  -d|--debug    Enable debug mode, will generate a job script but not submit"
	echo "  -n|--ncpus    Switch from default=${DEFAULT_NCPUS} to use [8,12,16]"
	echo "  -r|--restart  Restart mode, requires specifing individual subject-IDs"
	echo "  -h|--help     Prints this help/usage message"
	exit 1
}

SCRIPT=$(python3 -c "from os.path import abspath; print(abspath('$0'))")
SCRIPTDIR=$(dirname $SCRIPT)
echo " + `date`: starting script = $SCRIPT"

DEFAULT_NCPUS=8
NCPUS_OPTIONS=(8 12 16)
EMAIL_ARR=("chelmick@dal.ca" "vlad.drobinin@dal.ca")
RESTART_JOB="no"
DEBUG_MODE="no"
InputSubjArr=()
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
    -n|--ncpus)
      NCPUS_INPUT="$2"
      shift # past arg-name
      shift # past value
      ;;
    -r|--restart)
      RESTART_JOB="yes"
      echo " + RESTART_JOB mode enabled."
      shift
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
    *)    # unknown option
      InputSubjArr+=("$1") # save it in an array for later
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
SLURM_NCPUS=$DEFAULT_NCPUS
if [[ ! -z "$NCPUS_INPUT" ]]; then
	foundUsableOption="no"
	for n in ${NCPUS_OPTIONS[@]} ; do
		if [[ "$n" == "$NCPUS_INPUT" ]]; then
			SLURM_NCPUS=$NCPUS_INPUT
			echo " + now using SLURM_NCPUS=${SLURM_NCPUS}"
			foundUsableOption="yes"
			break
		fi
	done
	if [ "$foundUsableOption" == "no" ]; then
		echo " * specified option ncpus=$NCPUS_INPUT does not match one of the allowed NCPUS..."
		Usage
	fi
fi

## fmriprep-specific resource variables
RESOURCE_MEM_MB_PER_CPU=1024
RESOURCE_OMP_THREADS=$SLURM_NCPUS
RESOURCE_MEM_TOTAL=$((SLURM_NCPUS*RESOURCE_MEM_MB_PER_CPU))
RESOURCE_TIMEOUT="12:00:00"

## declare project paths and folders on tape-drive
PROJECT_DIR_TAPE=/project/6009072/fmri
SLURM_LOG_DIR=$PROJECT_DIR_TAPE/slurm_logs/${PROJECT}_${SITE}
mkdir -p ${SLURM_LOG_DIR}/

## declare project paths on ssd-drive
SCRATCH_DIR_SSD=$SCRATCH/fmri
SCRATCH_SITE_DIR=$SCRATCH_DIR_SSD/$PROJECT/$SITE
mkdir -p ${SCRATCH_SITE_DIR}/
BIDS_DIR=$SCRATCH_SITE_DIR/BIDS
DERIVS_DIR=$SCRATCH_SITE_DIR/derivatives

### unpack site-bids-archive on scratch_ssd
##eval "$SCRIPTDIR/fmri_0_unpack_site_bids_archive.sh -p $PROJECT -s $SITE"

## use input subjects if specified, otherwise assume all participants in site
if [ "${#InputSubjArr[@]}" -gt 0 ]; then
	SUBJECT_LIST="${InputSubjArr[*]}"
else
	if [ "$RESTART_JOB" == "yes" ]; then
		echo "*** ERROR: specifing --restart option requires "
	fi
	PartFile="$BIDS_DIR/participants.tsv"
	if [ ! -r "$PartFile" ]; then
		echo " * ERROR: could not read participant list = $PartFile"
		exit 2
	fi
	SUBJECT_LIST=$(tail -n +2 ${PartFile} | awk '{print $1}')
fi
echo " ++ SUBJECT_LIST=${SUBJECT_LIST}"

## run each subject as one job...
for S in ${SUBJECT_LIST} ; do
	SDIR=$BIDS_DIR/sub-${S}
	if [ ! -d "$SDIR" ]; then
		echo " *** ERROR: could not locate subject-bidsdir = $SDIR/"
		continue
	fi
	t1=$(find $SDIR -type f -name "sub-${S}_*T1w.nii.gz" -print)
	func=$(find $SDIR -type f -name "sub-${S}_*task-rest_*bold.nii.gz" -print)
	if [ ! -r "$t1" -o ! -r "$func" ]; then
		echo " * ERROR: missing required bids files for $SDIR/"
		continue
	fi
	if [ -r "$DERIVS_DIR/fmriprep/sub-${S}.html" ]; then
		echo " *** ERROR: found existing output = $DERIVS_DIR/fmriprep/sub-${S}.html, skipping"
		continue
	fi
	if [ "$RESTART_JOB" == "yes" -a "$DEBUG_MODE" == "no" ]; then
		echo " * removing derivatives $DERIVS_DIR/freesurfer/sub-${S}"
		#find $DERIVS_DIR/freesurfer/sub-${S} -type f -name "IsRunning" -delete
		rm -rf $DERIVS_DIR/fmriprep/sub-${S} >/dev/null
		rm -rf $DERIVS_DIR/freesurfer/sub-${S} >/dev/null
	fi
	jobname="slurm_fmriprep_${SITE}_sub-${S}"
	jobscript=${SLURM_LOG_DIR}/${jobname}.sh
	echo " ++ creating slurm-fmriprep script = $jobscript"
	cat >${jobscript} << EOF
#!/bin/bash
#
#SBATCH --account=def-ruher
#SBATCH --job-name=${jobname}.job
#SBATCH --output=${SLURM_LOG_DIR}/%x_%j.out
#SBATCH --error=${SLURM_LOG_DIR}/%x_%j.err
#SBATCH --time=${RESOURCE_TIMEOUT}
#SBATCH --cpus-per-task=${SLURM_NCPUS}
#SBATCH --mem-per-cpu=${RESOURCE_MEM_MB_PER_CPU}M
#SBATCH --mail-user=${EMAIL}
#SBATCH --mail-type=FAIL

echo " * \$(date +%Y%m%d-%H%M%S): starting job=${jobname}.job on slurm_tmpdir=\${SLURM_TMPDIR}"

## set variables pointing to containers,licenses,templates
FMRIPREP_SIMG=${SCRATCH_DIR_SSD}/fmriprep-20.2.3.sif
TF_HOST_HOME=${SCRATCH_DIR_SSD}/templateflow
FS_LIC_PATH=$HOME/.freesurfer_license.txt

## always ensure containers,licenses,templates are current on fast SSD /SCRATCH/
rsync -rltuv ${PROJECT_DIR_TAPE}/fmriprep-20.2.3.sif \${FMRIPREP_SIMG}
rsync -rltuv ${PROJECT_DIR_TAPE}/templateflow/ \${TF_HOST_HOME}/
rsync -rltuv ${PROJECT_DIR_TAPE}/freesurfer_license.txt \${FS_LIC_PATH}

## variables for inside singularity
export SINGULARITYENV_FS_LICENSE=\${FS_LIC_PATH}
export SINGULARITYENV_TEMPLATEFLOW_HOME=/templateflow

module load singularity/3.7

## mem_mb=(mem-per-cpu*cpu)
sing_cmd="singularity run --cleanenv -B ${SCRATCH_SITE_DIR}:/DATA -B \${SLURM_TMPDIR}:/work -B \${HOME} -B \${TF_HOST_HOME}:\${SINGULARITYENV_TEMPLATEFLOW_HOME} -B /etc/pki:/etc/pki \${FMRIPREP_SIMG}"
cmd_flags="--omp-nthreads ${RESOURCE_OMP_THREADS} --nprocs ${SLURM_NCPUS} --mem_mb ${RESOURCE_MEM_TOTAL} --write-graph --resource-monitor --notrack --skip_bids_validation -v"
cmd="\${sing_cmd} /DATA/BIDS /DATA/derivatives participant -w /work --participant-label ${S} \${cmd_flags}"
echo " * \$(date +%Y%m%d-%H%M%S): starting cmd: \$cmd"
eval \$cmd
exitcode=\$?
echo " * \$(date +%Y%m%d-%H%M%S): finished job=${jobname}.job with exit-code=\$exitcode"
rDIR=$SCRATCH_DIR_SSD/${PROJECT}/${SITE}/resource_monitor_files
mkdir -p \${rDIR}/
cp -vf \$SLURM_TMPDIR/fmriprep_wf/resource_monitor.json \${rDIR}/fmriprep_${SITE}_${SLURM_NCPUS}cpu_sub-${S}_resource_monitor.json
if [ \$exitcode -ne 0 ]; then 
	## problem-encountered, copy the entire output folder for review
	workdir=${SCRATCH_DIR_SSD}/\$(basename \$SLURM_TMPDIR).workdir 
	rsync -rtlv \$SLURM_TMPDIR/ \$workdir/ 
fi
echo "\$(date +%Y%m%d-%H%M%S),${jobname},\${exitcode}" >> ${SLURM_LOG_DIR}/job_exit_codes.csv
exit \$exitcode

EOF
	if [ "$DEBUG_MODE" == "yes" ]; then
		echo " * [DEBUG_MODE] $(date +%Y/%m/%d-%H%M%S): creating sbatch job=$jobscript"
	else
		echo " ++ $(date +%Y%m%d-%H%M%S): submitting sbatch job=$jobscript"
		jobQ=$(sbatch $jobscript)
		echo "$(date +%Y%m%d-%H%M%S),$jobscript,$jobQ" >>$SLURM_LOG_DIR/jobs_submitted.csv
	fi
done

exit 0
