#!/usr/bin/env Rscript
# =============================================================================
# Extract frozen phenograph outputs from existing MapMet2 SPE objects
# (adapted from MapMetSC's code/generate_phenograph_intermediary.R).
#
# Phenograph (Annoy kNN + igraph Louvain) is not bit-reproducible across
# machines, so the notebooks load a frozen kept-cell list (02_QC_1) and frozen
# cluster labels per phenograph k (04_phenotyping) instead of re-clustering. MapMet2's 02
# and 04 already write these to <output>/R_intermediary/ on their first run;
# this script re-extracts them from the saved objects, e.g. to ship them with
# the data (params$input/R_intermediary/) or after copying objects around.
#
# Produces: kept_cells_BM.rds, pg_clusters_BM_k<k>.rds (one per clustered k),
#           umap_BM.rds (the UMAP embedding of 04_phenotyping)
# =============================================================================

suppressPackageStartupMessages(library(SpatialExperiment))

output_dir <- Sys.getenv("MAPMET2_OUTPUT", "/mnt/data/output_mapmet2")  # holds spe_*.rds
inter_dir  <- file.path(output_dir, "R_intermediary")
dir.create(inter_dir, showWarnings = FALSE, recursive = TRUE)

## ---- lost cells: the kept-cell list is just spe_02's cells -----------------
extract_kept <- function(spe02_path, out_name) {
  if (!file.exists(spe02_path)) {
    message("skip kept-cells: ", spe02_path, " not found"); return(invisible())
  }
  spe02 <- readRDS(spe02_path)
  saveRDS(colnames(spe02), file.path(inter_dir, out_name))
  message(sprintf("wrote %s  (%d kept cells)", out_name, ncol(spe02)))
}

## ---- phenotyping: the labels per k BEFORE GMM subclustering, and the UMAP ---
# MapMet2's 04 stores the labels in pg_raw_k<k> (pg_clusters_k<k> adds the
# optional GMM subclusters) and the embedding in reducedDim(spe, "UMAP").
extract_pheno <- function(spe_paths) {
  spe_path <- spe_paths[file.exists(spe_paths)][1]
  if (is.na(spe_path)) {
    message("skip phenotyping: none found of ", paste(spe_paths, collapse = ", "))
    return(invisible())
  }
  spe  <- readRDS(spe_path)
  cols <- grep("^pg_raw_k[0-9]+$", names(colData(spe)), value = TRUE)
  if (!length(cols)) stop("no pg_raw_k<k> columns found in ", spe_path)
  for (col in cols) {
    out_name <- paste0("pg_clusters_BM_", sub("^pg_raw_", "", col), ".rds")
    v <- setNames(as.character(colData(spe)[[col]]), colnames(spe))
    saveRDS(v, file.path(inter_dir, out_name))
    message(sprintf("wrote %s  (%d cells, %d clusters; from %s col %s)",
                    out_name, length(v), length(unique(v)), basename(spe_path), col))
  }
  if ("UMAP" %in% reducedDimNames(spe)) {
    u <- reducedDim(spe, "UMAP")
    rownames(u) <- colnames(spe)
    # the attributes 04_phenotyping checks before reusing the embedding
    attr(u, "channels")    <- rownames(spe)[rowData(spe)$use_channel]
    attr(u, "n_neighbors") <- 30
    saveRDS(u, file.path(inter_dir, "umap_BM.rds"))
    message(sprintf("wrote umap_BM.rds  (%d cells; from %s)", nrow(u), basename(spe_path)))
  }
}

extract_kept(file.path(output_dir, "spe_02_QC_1.rds"), "kept_cells_BM.rds")
extract_pheno(file.path(output_dir, c("spe_04_phenotyping.rds",
                                      "spe_04_phenotyping_clusters.rds")))

message("\nDone. Intermediaries written to: ", inter_dir)
