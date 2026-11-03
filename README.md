# MapMet2

_This repository is under development._

MapMet2 is the `R`-based single-cell analysis of neuroblastoma (NB)
**bone-marrow (BM)** samples imaged by multi-modal imaging (IMC + IF). It covers
normal control BM and patient BM at four timepoints:

| timepoint | meaning | metadata code (`Timepoint`) |
|-----------|---------|-----------------------------|
| `control` | normal (non-NB) BM, as used in MapMetSC | `NA`, `control = "yes"` |
| `DE`      | diagnosis | `DE` |
| `T1`      | treatment timepoint 1 | `RE1` |
| `T2`      | treatment timepoint 2 | `RE2` |
| `REL`     | relapse | `REL` |

BM samples are cytospins of BM aspirates, so the analysis is purely single-cell:
there is no spatial analysis. MapMet2 is adapted from
[MapMetSC](https://github.com/TaschnerMandlGroup/MapMetSC) (Lazic et al.), which
analyses the diagnostic primary tumors; both build on data processed with
[MapMetIP](https://github.com/TaschnerMandlGroup/MapMetIP).

## Pipeline

| step | script | output |
|------|--------|--------|
| 1 | `analysis/01_read_data.Rmd` — read the BM images and metadata; patient cohort overview | `spe_01_read_data.rds` |
| 2 | `analysis/02_QC_1.Rmd` — exclude cells lost between IF and IMC | `spe_02_QC_1.rds` |
| 3 | `analysis/03_QC_2.Rmd` — exclude segmentation artifacts | `spe_03_QC_2.rds` |
| 4 | `analysis/04_phenotyping.Rmd` — UMAP, phenograph clustering (k = 15 / 30 / 45 / 60), label transfer from MapMetSC, two-pass cluster annotation | `spe_04_phenotyping.rds` |
| 5.1 | `analysis/05.1_correlation_Fetahu.Rmd` — SingleR against NB-BM scRNA-seq ([Fetahu et al.](https://doi.org/10.1038/s41467-023-39210-0)) | figures |
| 5.2 | `analysis/05.2_correlation_Lee.Rmd` — SingleR against healthy-BM scRNA-seq ([Lee et al.](https://doi.org/10.3389/fimmu.2023.1127879)) | figures |
| 6 | `analysis/06_generate_images.Rmd` — marker / cell-type / metacluster images of selected BM images | figures |

Shared colors and the timepoint labels are defined once in
`analysis/00_MapMet_color_code.R`; the bubble-plot helper is `code/bubbleplot.R`.
Every UMAP plot shows the same random subset of at most `umap_max_cells` cells
(default 50,000, set in `run_analysis.R`); the UMAP embedding itself is
computed on all cells.
Each script reads the object written by the previous step, so the steps run in
order. Rendered HTML goes to `docs/`, objects and figures (`plots/<step>/`) to
the output folder.

### Compared with MapMetSC

* BM samples only (`read_steinbock(pattern = "_BM_")`), all timepoints plus the
  controls; `RE1`/`RE2` are displayed as `T1`/`T2`.
* Not carried over: the adrenal-gland (AD) reference pipeline and its
  correlation step, the spatial analysis, the cell–cell communication analysis,
  and the primary-tumor community / differential-abundance steps.
* QC thresholds are the BM ones of MapMetSC.
* Frozen intermediaries (`kept_cells_BM.rds`, `pg_clusters_BM_k<k>.rds`) are created
  by the pipeline itself on its first run (see
  [`data/R_intermediary/README.md`](data/R_intermediary/README.md)).
* The cluster → cell type annotation is new for MapMet2 (two-pass, below), with
  a SingleR label transfer from MapMetSC's annotated object as cross-check and
  backup.

## Data

MapMet2 uses the same data as MapMetSC. Download and extract the
MapMetIP-processed single-cell data from Zenodo
[(MapMetIP_ProcessedDataset.zip)](https://doi.org/10.5281/zenodo.13220634):

```bash
wget -P <path/to/extract/directory> https://zenodo.org/records/13220635/files/MapMetIP_ProcessedDataset.zip
unzip <path/to/extract/directory>/MapMetIP_ProcessedDataset.zip -d <path/to/extract/directory>
```

The scripts expect, as for MapMetSC:

```
/mnt/data
├── input_all             # MapMetIP_ProcessedDataset (intensities-*, regionprops, masks, img) + NB_Panel.csv
│                         #   and Supplementary_Tables/20260526_Suppl_Table1.xlsx (inside or next to it)
├── public_datasets       # Fetahu/, Lee/ and protein2gene.csv
└── output_mapmet2        # created automatically: spe_*.rds, plots/, annotation/, R_intermediary/
```

All paths can be set with environment variables (read by `run_analysis.R` and by
each Rmd's `params`):

| variable | default | meaning |
|----------|---------|---------|
| `MAPMET2_INPUT` | `/mnt/data/input_all` | MapMetIP_ProcessedDataset folder |
| `MAPMET2_PUBLIC` | `/mnt/data/public_datasets` | public scRNA-seq references |
| `MAPMET2_OUTPUT` | `/mnt/data/output_mapmet2` | MapMet2 output — keep it separate from MapMetSC's output (same `spe_*.rds` names) |
| `MAPMET2_REFERENCE` | *(empty)* | MapMetSC's annotated `spe_04_phenotyping.rds`, used for the label transfer; empty = skip |
| `MAPMET2_INTERMEDIARY` | *(empty)* | extra folder searched first for frozen intermediaries / the filled annotation |
| `MAPMET2_ANNOTATION` | *(empty)* | path of the filled cluster annotation (default: `<output>/R_intermediary/cluster_annotation_BM.xlsx`) |
| `MAPMET2_ANNOTATION_FALLBACK` | `none` | `transfer` = use the SingleR-transferred MapMetSC labels when no filled annotation exists |

## Usage

Clone the repository and build the Apptainer image (see
[`apptainer/README.md`](apptainer/README.md); a GitHub Actions workflow can build
it too):

```bash
git clone https://github.com/ArthurDondi/MapMet2.git
cd MapMet2
./apptainer/build.sh                       # -> ./mapmet2.sif
```

Render the pipeline headless:

```bash
apptainer exec --bind <path/to/singlecelldata>:/mnt/data \
    --env MAPMET2_REFERENCE=/mnt/data/output/spe_04_phenotyping.rds \
    mapmet2.sif Rscript run_analysis.R
```

or on a SLURM cluster (edit the CONFIG block first):

```bash
mkdir -p logs
sbatch run_mapmet2_slurm.sh
```

A `Dockerfile` is provided for local RStudio use; the Apptainer image is the
tested route.

### Two-pass cell-type annotation

1. **First run.** `run_analysis.R` renders steps 1–4. On this first run:
   * `02_QC_1` freezes the kept-cell list (lost-cell clusters chosen by an
     IMC-DNA heuristic, shown in its heatmap);
   * `04_phenotyping` clusters the cells with phenograph for k = 15, 30, 45 and
     60 (`k_values` in `run_analysis.R`), freezes each clustering and writes
     `<output>/annotation/cluster_annotation_BM_template.xlsx`. Its first tab
     `annotation` is empty; then come one tab per k (`k15`, `k30`, ...) with the
     clusters of that k: cell counts and percentages per timepoint, plus the most
     frequent transferred MapMetSC label when `MAPMET2_REFERENCE` is set;
   * steps 5–6 are skipped.
2. **Check and annotate.** Inspect the bubble plots and heatmaps in
   `<output>/plots/02_QC_1/` and `<output>/plots/04_phenotyping/`.
   * Which lost-cell clusters were excluded is recorded in
     `<output>/plots/02_QC_1/<date>_lost_cell_clusters.csv` (one row per QC
     cluster: cells, mean IMC DNA and DAPI, flagged by the heuristic, cells
     excluded), in the job's `.err` log (`[02_QC_1] lost-cell exclusion ...`) and
     in `docs/02_QC_1.html`.
   * If the lost-cell heuristic picked the wrong cluster(s), set
     `lost_cell_clusters` in `run_analysis.R` and delete
     `R_intermediary/pg_clusters_BM_k*.rds`.
   * Compare the k values (UMAPs, bubble plots and heatmaps per k in
     `<output>/plots/04_phenotyping/`) and fill in `celltype` and `metacluster`
     for every cluster in the tab of the k you choose. Use the MapMetSC
     metacluster names where they apply; `tumor` and `other` are used by the
     correlation steps.
   * To split mixed clusters, set `gmm_subclusters` in `run_analysis.R`, giving
     the k of the clusters (e.g. `list(list(k = 30, cluster = "5", new = "35",
     markers = c("CD3_")))`); the subclusters appear as extra rows in that k's
     tab after the next run.
   * Copy the rows of the chosen k (with the `k` and `cluster` columns) into the
     **first tab** — the only tab the script reads — and save the workbook as
     `<output>/R_intermediary/cluster_annotation_BM.xlsx`.
3. **Second run.** Run `run_analysis.R` again: the frozen intermediaries are
   reused, the annotation is applied and steps 4–6 complete.

To skip the manual annotation, run with `MAPMET2_ANNOTATION_FALLBACK=transfer`
(requires `MAPMET2_REFERENCE`): the transferred MapMetSC cell types are then used.

## Acknowledgements

The analysis code is adapted from [MapMetSC](https://github.com/TaschnerMandlGroup/MapMetSC)
by [Daria Lazic](https://github.com/LazDaria),
[Sara Wernig-Zorc](https://github.com/sarawernig) and
[Simon Gutwein](https://github.com/SimonBon/).
