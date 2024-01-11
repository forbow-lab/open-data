# Open Data
Scripts and documentation for open datasets

---

## Open Dataset Descriptions

| Dataset  | fMRI availability |
| ------------- | ------------- |
| [**ABCD** - The Adolescent Brain Cognitive Development Study](https://github.com/forbow-lab/open-data/wiki/ABCD) | Resting + Task
| [**HBN** - Child Mind Institute: healthy brain network](https://github.com/forbow-lab/open-data/wiki/CMI:-HBN) | Resting + Nat Viewing
| [**HCP-D** - HCP-Development](https://github.com/forbow-lab/open-data/wiki/HCP-D) | Resting + Task
| [**PNC** - Philadelphia neurodevelopmental cohort](https://github.com/forbow-lab/open-data/wiki/PNC) | Resting (6.2mins) + Task
| [**NKI** - Enhanced Nathan Kline Institute - Rockland Sample](https://github.com/forbow-lab/open-data/wiki/NKI) | Resting
| [**PING** - Pediatric Imaging, Neurocognition, and Genetics](https://github.com/forbow-lab/open-data/wiki/PING) | Resting
| [**ABIDE** - Autism Brain Imaging Data Exchange](https://github.com/forbow-lab/open-data/wiki/ABIDE-I-and-II) | Resting 
| [**CoRR** - Consortium for Reliability and Reproducibility](https://github.com/forbow-lab/open-data/wiki/CoRR) | Resting
| [**ADHD-200** - International Neuroimaging Datasharing Initiative (INDI), the ADHD-200 Sample](https://github.com/forbow-lab/open-data/wiki/ADHD200) | Resting
| [**NIHPD** - The NIH MRI study of normal brain development](https://github.com/forbow-lab/open-data/wiki/NIHPD) | NA
| [**QTAB** - The NIH MRI study of normal brain development](https://github.com/forbow-lab/open-data/wiki/QTAB) | rsfMRI + sMRI


---


## Running fMRI prep on Compute Canada / ACENET

### TAR & Upload Site BIDS Data (from PBIL)
From the PBIL, tar and upload raw bids dataset onto shared project drive. Each site (ie, /ADHD200/Brown/) is done separately to limit size of tar-archives, transfer speeds, and job-management on ComputeCanada. Use the tar_and_rsync_to_CC.sh script from the PBIL, /shared/uher/FORBOW/OpenDatasets/ADHD200/. This script will tar an entire site's raw BIDS dataset, then rsync up to cedar into a Tar_BIDS folder under the Project space (eg, ~/projects/def-ruher/fmri/ADHD200/Tar_BIDS/Brown.tar)

### 1) Unpack BIDS TAR Archive into ~/scratch/fmri/ (on Cedar)
SSH into cedar.computecanada.ca, `username@cedar.computecanada.ca` then use the script below to upack the site BIDS tar file from ~/projects/def-ruher/PROJECT/TarBIDS/ into ~/scratch/fmri/PROJECT/SITE/BIDS/. Specify project and site.

```
cd ~/projects/def-ruher/fmri/
./scripts/fmri_0_unpack_site_bids_archive.sh -p ADHD200 -s Brown
```

Another option to execute script: `bash script-name-here.sh -arg1 -arg2`

### 2) Run Fmriprep (on Cedar)
Then run every subject individually as one fmriprep-slurm job. First pass, add the `'--debug'` flag to ensure job-scripts are created without any errors. __Then remove the flag to submit to slurm-scheduler__. This script by default uses `NCPUS=8, MemPerCPU=1024MB, OMP-THREADS=NCPUS, with Slurm-WallTime=12hrs`. After jobs are submitted use `'sq'` command to check the queue status. 

```
./scripts/fmri_1_slurm_fmriprep_batch.sh -p ADHD200 -s Brown -e chelmick@dal.ca --debug
```

### 3) Restart TimeOut-Cancelled Fmriprep Jobs (on Cedar)
Depending on resources used, quality of data, and ComputeCanada workload, a certain amount of fmriprep jobs will not finish within the specified WallTime limit (12hrs). These jobs can be re-started easily, from scratch with original outputs deleted, with another script as described below. Each of these jobs will use NCPUS=12. Use '--debug' on the first try to ensure cancelled jobs are properly found and reported. Once satisfied use the '--submit' flag when ready to run. This script safely removes the incomplete results then calls the fmri_1_slurm_fmriprep_batch.sh above to submit the jobs.

```
./scripts/fmri_2_restart_cancelled_jobs.sh -p ADHD200 -s Brown -e chelmick@dal.ca --debug
```

### 4) TAR Fmriprep Derivatives (on Cedar)
Once fmriprep has completed for all subjects in a site, use this script to archive the derivatives from user ~/scratch/fmri/PROJECT/ (slower-SSD) back over to group-shared tape-drive ~/projects/def-ruher/fmri/PROJECT/Tar_DERIVS/SITE.tar:

```
./scripts/fmri_3_archive_site_derivs.sh -p ADHD200 -s Brown
```

### Download Tar Derivatives from Cedar to PBIL (from PBIL)
From the PBIL, download the completed site derivatives Tar file.

`
cd /shared/uher/FORBOW/OpenDatasets/ADHD200/
./download_tar_derivs.sh -p ADHD200 -s Brown
`


### [Priorities](https://docs.google.com/document/d/1-Fzzu3Op6nP51oM1lcZ3M3e3-rhNfBRtebmxVf1BMns/edit#heading=h.hx69dzmtqn9c):
ADHD200 > HBN > ABIDE > Rockland > Corr
