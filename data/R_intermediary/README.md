# R_intermediary — frozen intermediaries and the cluster annotation

Phenograph clustering in this project runs through `Rphenoannoy`, which uses
**Annoy** (approximate nearest-neighbour search, C++) followed by
`igraph::cluster_louvain`. Neither step is bit-reproducible across `igraph`
versions, compilers or CPUs, so the **same seed and same input data can produce
different clusters on a different machine or container**. As in MapMetSC, the
clustering-dependent decisions are therefore frozen as `.rds` files and reused:

* **`02_QC_1.Rmd`** excludes lost cells and freezes the **list of kept cells**;
  later runs load it instead of re-deciding from new cluster numbers.
* **`04_phenotyping.Rmd`** freezes the **phenograph labels of every k**
  (default 15 / 30 / 45 / 60), so the manual cluster annotation stays valid
  between runs, and the **UMAP embedding**, which is slow to compute for
  hundreds of thousands of cells.

Unlike MapMetSC, MapMet2 creates these files itself on its first run (written to
`<output>/R_intermediary/`), because the BM-only cell set differs from the
MapMetSC objects.

## Files

| file | written / read by | contents |
|------|-------------------|----------|
| `kept_cells_BM.rds`          | `analysis/02_QC_1.Rmd` | character vector of kept cell ids (post lost-cell exclusion) |
| `pg_clusters_BM_k<k>.rds`    | `analysis/04_phenotyping.Rmd` | one per k: named vector, cell id → phenograph cluster (before GMM subclustering) |
| `umap_BM.rds`                | `analysis/04_phenotyping.Rmd` | UMAP embedding (cell id × 2); reused while it covers all cells and was computed on the same channels and `n_neighbors` |
| `celltype_transfer_BM.rds`   | `analysis/04_phenotyping.Rmd` | cache of the SingleR label transfer from MapMetSC (per cell) |
| `cluster_annotation_BM.xlsx` | `analysis/04_phenotyping.Rmd` | **filled by you**, from the template in `<output>/annotation/`: only its **first tab** is read — the rows of the chosen k with `k`, `cluster`, `celltype`, `metacluster` (+ comments); a `.csv` with these columns is also accepted |
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
* Delete `pg_clusters_BM_k*.rds` to re-cluster — the cluster IDs then change,
  so `cluster_annotation_BM.xlsx` has to be redone too. `04` stops with a
  message if the frozen clusters no longer cover all cells (e.g. after a QC
  change). A k added to `k_values` is clustered and frozen on the next run.
* Delete `umap_BM.rds` to recompute the UMAP (it is recomputed automatically
  when it no longer covers all cells or the clustering channels changed).

`code/generate_phenograph_intermediary.R` re-extracts `kept_cells_BM.rds`,
`pg_clusters_BM_k<k>.rds` and `umap_BM.rds` from saved `spe_02` / `spe_04` objects.

> These files are **not** committed here (they depend on the dataset). This
> folder and README document the scheme.
