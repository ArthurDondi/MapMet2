# R_intermediary — frozen intermediaries and the cluster annotation

Phenograph clustering in this project runs through `Rphenoannoy`, which uses
**Annoy** (approximate nearest-neighbour search, C++) followed by
`igraph::cluster_louvain`. Neither step is bit-reproducible across `igraph`
versions, compilers or CPUs, so the **same seed and same input data can produce
different clusters on a different machine or container**. As in MapMetSC, the
clustering-dependent decisions are therefore frozen as `.rds` files and reused:

* **`02_QC_1.Rmd`** excludes lost cells and freezes the **list of kept cells**;
  later runs load it instead of re-deciding from new cluster numbers.
* **`04_phenotyping.Rmd`** freezes the **k=30 phenograph labels**, so the manual
  cluster annotation stays valid between runs.

Unlike MapMetSC, MapMet2 creates these files itself on its first run (written to
`<output>/R_intermediary/`), because the BM-only cell set differs from the
MapMetSC objects.

## Files

| file | written / read by | contents |
|------|-------------------|----------|
| `kept_cells_BM.rds`          | `analysis/02_QC_1.Rmd` | character vector of kept cell ids (post lost-cell exclusion) |
| `pg_clusters_BM.rds`         | `analysis/04_phenotyping.Rmd` | named vector, cell id → k=30 cluster (before GMM subclustering) |
| `celltype_transfer_BM.rds`   | `analysis/04_phenotyping.Rmd` | cache of the SingleR label transfer from MapMetSC (per cell) |
| `cluster_annotation_BM.xlsx` | `analysis/04_phenotyping.Rmd` | **filled by you**: `cluster`, `celltype`, `metacluster` (+ comments), from the template in `<output>/annotation/` (`.csv` also accepted) |
| `celltype_order_BM.csv`      | `analysis/04_phenotyping.Rmd` | optional, `;`-separated `order;celltype`; sets the celltype display order |

Cell ids are `sample_id_ObjectNumber`.

## Lookup order

`02` and `04` search, in this order: `MAPMET2_INTERMEDIARY`,
`<input>/R_intermediary`, `<input>/../R_intermediary`, `<output>/R_intermediary`.
Newly frozen files are always written to `<output>/R_intermediary`.

In `02_QC_1.Rmd` the lost-cell clusters set in `run_analysis.R`
(`lost_cell_clusters`) take precedence over the frozen list and re-freeze it.

## Starting over

* Delete `kept_cells_BM.rds` to redo the lost-cell exclusion.
* Delete `pg_clusters_BM.rds` to re-cluster — the cluster IDs then change, so
  `cluster_annotation_BM.xlsx` has to be redone too. `04` stops with a message
  if the frozen clusters no longer cover all cells (e.g. after a QC change).

`code/generate_phenograph_intermediary.R` re-extracts `kept_cells_BM.rds` and
`pg_clusters_BM.rds` from saved `spe_02` / `spe_04` objects.

> These files are **not** committed here (they depend on the dataset). This
> folder and README document the scheme.
