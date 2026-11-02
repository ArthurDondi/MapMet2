#!/bin/bash
#SBATCH --output logs/MapMet2_%j.log
#SBATCH --error  logs/MapMet2_%j.err
#SBATCH --job-name=MapMet2
#SBATCH --partition=longq      # 30d limit: comfortably covers the whole workflow
#SBATCH --qos=longq            # qos must match the partition
#SBATCH --time=2-00:00:00      # --time=days-hours:minutes:seconds
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16     # SingleR steps fork MulticoreParam(workers=10..16)
#SBATCH --mem=192000           # parallel workers multiply memory (see NOTE below)
#SBATCH --mail-type=end
#SBATCH --mail-user=arthur.dondi@cemm.at
#
# Run the whole MapMet2 R analysis (neuroblastoma bone marrow) on the SLURM
# cluster. Adapted from MapMetSC's run_mapmetsc_slurm.sh.
#
# The job runs the pipeline itself by executing `Rscript run_analysis.R` inside
# the Apptainer image: read data -> QC 1 -> QC 2 -> phenotyping -> Fetahu / Lee
# correlations -> images. Cell-type annotation is TWO-PASS (see README): the
# first run stops after 04_phenotyping and writes an annotation template; fill
# it, save it as $INTERMEDIARY/cluster_annotation_BM.xlsx and submit again.
#
# Submit from the MapMet2/ repo root (where run_analysis.R lives):
#   mkdir -p logs                       # once: SLURM needs the log dir to exist
#   sbatch run_mapmet2_slurm.sh
#
# Paths can be overridden at submit time, e.g.:
#   MAPMET2_DATA=/nobackup/.../mapmet MAPMET2_SIF=/path/to/mapmet2.sif \
#       sbatch run_mapmet2_slurm.sh
#
# NOTE on parallelism / memory: 04_phenotyping uses SnowParam(workers=30) for the
# UMAP, and the SingleR steps (label transfer in 04, 05.1 Fetahu, 05.2 Lee) use
# MulticoreParam(workers=10..16). Every worker holds a copy of the data, so
# memory is the real risk - hence the generous --mem. RNGseed is fixed in those
# calls, so results do not depend on the worker count.

set -euo pipefail

# Some clusters expose apptainer/singularity through modules; uncomment if so:
module load apptainer/1.1.9

# ----------------------------- CONFIG (edit me) -----------------------------
# The built image (see apptainer/build.sh). Defaults to the repo root.
SIF="${MAPMET2_SIF:-$SLURM_SUBMIT_DIR/mapmet2.sif}"

# The directory that contains Publication/ (your extracted data root).
DATA="${MAPMET2_DATA:-/nobackup/lab_taschner-mandl/arthurdondi/projects/mapmet}"

# Input data: the same MapMetIP_ProcessedDataset and public references as MapMetSC.
INPUT="${MAPMET2_INPUT:-$DATA/Publication/20240811_Zenodo-Upload/MapMetIP_ProcessedDataset}"
PUBLIC="${MAPMET2_PUBLIC:-$DATA/Publication/public_datasets}"
# MapMet2's OWN output folder. Keep it separate from MapMetSC's output: both
# pipelines write spe_0*.rds objects with the same names.
OUTPUT="${MAPMET2_OUTPUT:-$DATA/MapMet2/output}"
# Frozen intermediaries (kept_cells_BM.rds, pg_clusters_BM.rds) and the filled
# cluster_annotation_BM.xlsx. The first run writes the frozen lists here.
INTERMEDIARY="${MAPMET2_INTERMEDIARY:-$OUTPUT/R_intermediary}"
# Optional: MapMetSC's annotated object, used as the SingleR reference for the
# label transfer in 04_phenotyping. Leave empty to skip the transfer.
REFERENCE="${MAPMET2_REFERENCE:-$DATA/Publication/output/spe_04_phenotyping.rds}"
# ----------------------------------------------------------------------------

echo "======================"
echo "submit dir : $SLURM_SUBMIT_DIR"
echo "job name   : $SLURM_JOB_NAME"
echo "partition  : $SLURM_JOB_PARTITION"
echo "job id     : $SLURM_JOB_ID"
echo "cpus       : ${SLURM_CPUS_PER_TASK:-1}   mem(MB): ${SLURM_MEM_PER_NODE:-?}"
echo "sif        : $SIF"
echo "input      : $INPUT"
echo "public     : $PUBLIC"
echo "output     : $OUTPUT"
echo "intermed.  : $INTERMEDIARY"
echo "reference  : ${REFERENCE:-<none>}"
echo "started    : $(date)"
echo "======================"

# Sanity checks (fail early with a clear message rather than deep in R).
[[ -f "$SIF" ]]                 || { echo "ERROR: image not found: $SIF (build it with apptainer/build.sh)"; exit 1; }
[[ -d "$INPUT/regionprops" ]]   || { echo "ERROR: '$INPUT' is not a MapMetIP_ProcessedDataset (no regionprops/)"; exit 1; }
[[ -d "$PUBLIC" ]]              || { echo "ERROR: public datasets dir not found: $PUBLIC"; exit 1; }
if [[ -n "$REFERENCE" ]]; then
    # MapMet2 writes $OUTPUT/spe_04_phenotyping.rds: never let it overwrite the reference.
    if [[ "$(realpath -m "$OUTPUT")" == "$(realpath -m "$(dirname "$REFERENCE")")" ]]; then
        echo "ERROR: OUTPUT ($OUTPUT) is the folder of the MapMetSC reference ($REFERENCE);"
        echo "       MapMet2 would overwrite it. Point MAPMET2_OUTPUT elsewhere."
        exit 1
    fi
    [[ -f "$REFERENCE" ]] || { echo "WARNING: reference not found: $REFERENCE (label transfer will be skipped)"; REFERENCE=""; }
fi
mkdir -p "$OUTPUT" "$INTERMEDIARY"

# Keep BLAS/OpenMP threads inside the SLURM allocation (APPTAINERENV_* is how
# apptainer forwards env vars into the container).
export APPTAINERENV_OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
export APPTAINERENV_OPENBLAS_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"

# Bind the data root, the output and (if set) the reference's folder.
BINDS=(--bind "$DATA" --bind "$OUTPUT" --bind "$INTERMEDIARY" --bind "$SLURM_SUBMIT_DIR")
[[ -n "$REFERENCE" ]] && BINDS+=(--bind "$(dirname "$REFERENCE")")

# --cleanenv: do NOT inherit the host shell env (an active conda `base` sets
# LD_LIBRARY_PATH to conda libs, which can shadow the image's own libraries and
# break e.g. git2r's libgit2). --env / APPTAINERENV_* still pass through.
apptainer exec \
    --cleanenv \
    "${BINDS[@]}" \
    --pwd "$SLURM_SUBMIT_DIR" \
    --env MAPMET2_INPUT="$INPUT" \
    --env MAPMET2_PUBLIC="$PUBLIC" \
    --env MAPMET2_OUTPUT="$OUTPUT" \
    --env MAPMET2_INTERMEDIARY="$INTERMEDIARY" \
    --env MAPMET2_REFERENCE="$REFERENCE" \
    "$SIF" \
    Rscript run_analysis.R

echo "======================"
echo "finished   : $(date)"
echo "objects & figures in: $OUTPUT"
echo "rendered HTML in    : $SLURM_SUBMIT_DIR/docs"
echo "======================"
