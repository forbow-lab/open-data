#!/bin/bash
#
#SBATCH --account=def-ruher
#SBATCH --job-name=fmriprep_sub-0026001.job
#SBATCH --output=/project/6009072/fmri/slurm_logs/%x_%j.out
#SBATCH --error=/project/6009072/fmri/slurm_logs/%x_%j.err
#SBATCH --time=16:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=4096M
#SBATCH --mail-user=chelmick@dal.ca
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

PROJECT_DIR_TAPE=/project/6009072/fmri

SCRATCH_DIR_SSD=$SCRATCH/fmri
mkdir -p $SCRATCH_DIR_SSD/

echo " * `date +%Y/%m%/d-%H%M%S`: starting fmriprep_sub-0026001.job on slurm_tmpdir=${SLURM_TMPDIR}"

## set variables pointing to containers,licenses,templates
FMRIPREP_SIMG=$SCRATCH_DIR_SSD/fmriprep-20.2.1_CC.sif
TF_HOST_HOME=$SCRATCH_DIR_SSD/templateflow
FS_LIC_PATH=$HOME/.freesurfer_license.txt


## always ensure containers,licenses,templates are current on fast SSD /SCRATCH/
rsync -rltuv $PROJECT_DIR_TAPE/fmriprep-20.2.1_CC.sif $FMRIPREP_SIMG
rsync -rltuv $PROJECT_DIR_TAPE/templateflow/ $TEMPLATEFLOW_HOME/
rsync -rltuv $PROJECT_DIR_TAPE/freesurfer_license.txt $FS_LIC_PATH


## variables for inside singularity
export SINGULARITYENV_FS_LICENSE=$HOME/.freesurfer_license.txt
export SINGULARITYENV_TEMPLATEFLOW_HOME=/templateflow

module load singularity/3.7


## PROJECT SPECIFIC
BIDS_HOST_DIR=$SCRATCH_DIR_SSD/ADHD200/Brown

## ensure project-specific input files (BIDS) are available on fast SSD /SCRATCH/ 
rsync -rltuv --exclude="derivatives" $PROJECT_DIR_TAPE/ADHD200/Brown/BIDS/ $BIDS_HOST_DIR/BIDS/

## copy only necessary input dataset from ssd scratch into slurm-localscratch
#rsync -rltv --exclude="sub*" --exclude="derivatives" $SCRATCH_DIR_SSD/ADHD200/Brown/BIDS/ $SLURM_TMPDIR/BIDS/
#rsync -rltv $SCRATCH_DIR_SSD/ADHD200/Brown/BIDS/sub-0026001 $SLURM_TMPDIR/BIDS/
DERIVS_DIR=$BIDS_HOST_DIR/derivatives
mkdir -p $DERIVS_DIR/freesurfer/ $DERIVS_DIR/fmriprep/

## mem_mb=(mem-per-cpu*cpu)
SING_CMD="singularity run --cleanenv -B ${BIDS_HOST_DIR}:/DATA -B ${SLURM_TMPDIR}:/work -B ${HOME} -B ${TF_HOST_HOME}:${SINGULARITYENV_TEMPLATEFLOW_HOME} -B /etc/pki:/etc/pki ${FMRIPREP_SIMG}"
CMD="${SING_CMD} /DATA/BIDS /DATA/derivatives participant -w /work --participant-label 0026001 --omp-nthreads 8 --nprocs 16 --mem_mb 65536 --write-graph --resource-monitor --notrack --skip_bids_validation -vvv"
echo " * `date`, starting cmd: $cmd"
eval $cmd
exitcode=$?
echo " * `date +%Y/%m%/d-%H%M%S`: finished fmriprep_sub-0026001.job with exit-code=$exitcode"
cp -v $SLURM_TMPDIR/fmriprep_wf/resource_monitor.json $SCRATCH_DIR_SSD/fmriprep_sub-0026001_resource_monitor.json
if [ $exitcode -ne 0 ]; then 
	## problem-encountered, copy the entire output folder for review
	workdir=$SCRATCH_DIR_SSD/$(basename $SLURM_TMPDIR).workdir 
	rsync -rptlv $SLURM_TMPDIR/ $workdir/ 
else
	## successful slurm-job, copy only the necessary output files
	workdir=$SCRATCH_DIR_SSD/$(basename $SLURM_TMPDIR).workdir 
	echo " ++ DEBUG: successful run, copying all outputs to: $workdir"
	rsync -rptlv $SLURM_TMPDIR/ $workdir/
fi
exit $exitcode


## Notes:
##
## 1) SLURM_TMPDIR variable is unique for each job after submitted, named by user.jobid = /localscratch/chelmick.6990096.0/
##
## 2) /SCRATCH/user/ has 20T capacity, files older than 60days are purged.
##    PROJECT is tape-based, very slow and meant for almost static files (BIDS/, derivatives/)
##    SLURM_TMPDIR is /localscratch/ given when job is submitted
## 
