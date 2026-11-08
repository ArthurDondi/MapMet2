#!/usr/bin/env Rscript
# ============================================================================
# MapMet2 — master script
#
# Renders the MapMet2 single-cell pipeline (neuroblastoma bone marrow, IMC) end
# to end, in order. Adapted from MapMetSC's run_analysis.R. Each step reads the
# object saved by the previous step from `output` and writes its own object and
# figures back to `output`.
#
# Setup
# -----
#   1. Download and extract the MapMetIP-processed single-cell data from Zenodo
#      (see the README); the Supplementary Tables and the public reference
#      datasets (Fetahu / Lee) are expected next to it, as for MapMetSC.
#   2. Point the paths in the CONFIG block below at that data (or export the
#      MAPMET2_* environment variables). The defaults assume the container mount
#      `-v <singlecelldata>:/mnt/data` (see README).
#   3. From the repository root run:   Rscript run_analysis.R
#
# Cell-type annotation is TWO-PASS (see README / analysis/04_phenotyping.Rmd):
#   * first run: everything up to 04_phenotyping is rendered; 04 clusters the
#     cells for every k in `k_values`, writes
#     <output>/annotation/cluster_annotation_BM_template.xlsx (an empty first tab
#     plus one tab per k) and stops, and the steps after it are skipped;
#   * annotate the tab of the chosen k, copy its rows into the FIRST tab of that
#     same workbook (never overwritten by later runs) and run again: the frozen
#     kept-cell list and phenograph clusters are reused, so the cluster IDs stay
#     valid;
#   * with GMM subclusters (chunk gmm-subclustering of 04), 04 writes
#     <output>/annotation/cluster_annotation_BM_template_subclustering.xlsx and
#     stops again until its first tab, annotations_after_subclustering, is filled.
#   Setting MAPMET2_ANNOTATION_FALLBACK=transfer instead uses the cell types
#   transferred from MapMetSC with SingleR (needs MAPMET2_REFERENCE).
#
# Rendered HTML is written to docs/; intermediate objects (spe_*.rds) and
# figures to `output`.
# ============================================================================

# ---------------------------- CONFIG (edit me) ------------------------------
# Either export the MAPMET2_* environment variables or replace the fallback
# strings after the commas. The same variables drive the per-Rmd `params:`
# defaults, so knitting a single .Rmd interactively picks them up too.
input     <- Sys.getenv("MAPMET2_INPUT",  "/mnt/data/input_all")          # MapMetIP_ProcessedDataset (steinbock data + NB_Panel.csv)
public    <- Sys.getenv("MAPMET2_PUBLIC", "/mnt/data/public_datasets")    # public scRNA-seq references (Fetahu / Lee) + protein2gene.csv
output    <- Sys.getenv("MAPMET2_OUTPUT", "/mnt/data/output_mapmet2")     # writable; keep it separate from MapMetSC's output
reference <- Sys.getenv("MAPMET2_REFERENCE", "")                          # MapMetSC's annotated spe_04_phenotyping.rds (label transfer; "" = skip)

# Analysis settings, chosen after inspecting the first run (see README):
lost_cell_clusters  <- NULL       # 02_QC_1: lost-cell clusters of that run's heatmap, e.g. c("26"); NULL = frozen list / IMC-DNA heuristic
k_values            <- c(15, 30, 45, 60)  # 04_phenotyping: phenograph k values, one template tab each
umap_max_cells      <- 50000      # 04 / 06.x: cells drawn per UMAP plot (random subset; the embedding uses all cells)
# (the GMM subclustering is set in analysis/04_phenotyping.Rmd, chunk gmm-subclustering)
# 05.1: communities cut from each sample dendrogram, per variant
# (<clustered on>_<with|without>_controls); a number, or "auto" = the largest k
# whose communities are all bootstrap-stable (see 05.1, "Number of communities")
n_communities <- c(all_with_controls       = "auto",
                   all_without_controls    = "auto",
                   immune_with_controls    = "auto",
                   immune_without_controls = "auto")
community_variant   <- "all_without_controls"  # 05.2: 05.1 variant whose communities are compared ("" = none)
min_cells_sample    <- 100        # 05.1 / 05.2: samples with fewer cells are left out (communities, DA)
annotation_file     <- Sys.getenv("MAPMET2_ANNOTATION", "")               # "" = the workbook in <output>/annotation/ (see 04)
annotation_fallback <- Sys.getenv("MAPMET2_ANNOTATION_FALLBACK", "none")  # "none" (two-pass) or "transfer"

# First step to render: "01" (everything), "02", "03", "04", "05" (05.1 communities + 05.2 DA),
# "06" (06.1 Fetahu + 06.2 Lee) or "07" (images); a step renders every step after it
# too. Earlier steps are skipped and their saved spe_*.rds objects are used,
# e.g. "04" to redo the phenotyping / annotation without re-running read + QC.
start_from <- Sys.getenv("MAPMET2_START_FROM", "01")
# ----------------------------------------------------------------------------

dir.create(output, showWarnings = FALSE, recursive = TRUE)
if (nzchar(reference) &&
    normalizePath(dirname(reference), mustWork = FALSE) == normalizePath(output, mustWork = FALSE))
  stop("MAPMET2_OUTPUT (", output, ") is the folder of the MapMetSC reference (", reference,
       "): MapMet2 would overwrite it. Use a separate output folder.")

render_step <- function(rmd, params) {
  message("\n=====================================================================")
  message("Rendering: ", rmd)
  message("=====================================================================")
  rmarkdown::render(
    input      = rmd,
    output_dir = "docs",
    params     = params,
    envir      = new.env(),
    quiet      = FALSE
  )
}

main_params  <- list(input = input, output = output)
qc1_params   <- c(main_params, if (length(lost_cell_clusters)) list(lost_cell_clusters = lost_cell_clusters))
pheno_params <- c(main_params, list(reference           = reference,
                                    annotation_file     = annotation_file,
                                    annotation_fallback = annotation_fallback,
                                    k_values            = k_values,
                                    umap_max_cells      = umap_max_cells))
comm_params  <- c(main_params, list(min_cells = min_cells_sample))
da_params    <- c(main_params, list(min_cells = min_cells_sample, community_variant = community_variant))
corr_params  <- list(input = input, output = output, public = public, umap_max_cells = umap_max_cells)

# --- Where to start ----------------------------------------------------------
steps <- c("01", "02", "03", "04", "05", "06", "07")
start_from <- sprintf("%02d", as.integer(sub("^0*", "", start_from)))  # "4" -> "04"
if (!start_from %in% steps)
  stop("start_from must be one of ", paste(steps, collapse = ", "), " (got '", start_from, "').")
# object each step reads from the step before it
needs <- c("02" = "spe_01_read_data.rds", "03" = "spe_02_QC_1.rds", "04" = "spe_03_QC_2.rds",
           "05" = "spe_04_phenotyping.rds", "06" = "spe_04_phenotyping.rds",
           "07" = "spe_04_phenotyping.rds")
if (start_from != "01" && !file.exists(file.path(output, needs[[start_from]])))
  stop("start_from = ", start_from, " needs ", file.path(output, needs[[start_from]]),
       " from an earlier run; start from an earlier step.")
run_step <- function(step) match(step, steps) >= match(start_from, steps)
if (start_from != "01")
  message("Starting from step ", start_from, ": steps ",
          paste(steps[seq_len(match(start_from, steps) - 1)], collapse = ", "), " skipped.")

# --- Main single-cell pipeline ----------------------------------------------
# Shared colors live in analysis/00_MapMet_color_code.R, which each script
# sources automatically - it is a helper, not a rendered step.
if (run_step("01")) render_step("analysis/01_read_data.Rmd",   main_params)   # BM samples + cohort overview
if (run_step("02")) render_step("analysis/02_QC_1.Rmd",        qc1_params)    # lost cells (freezes kept_cells_BM.rds)
if (run_step("03")) render_step("analysis/03_QC_2.Rmd",        main_params)   # segmentation artifacts

spe04 <- file.path(output, "spe_04_phenotyping.rds")
if (run_step("04")) {
  pheno_start <- Sys.time()
  render_step("analysis/04_phenotyping.Rmd", pheno_params)  # clusters, label transfer, annotation
  # 04 writes spe_04_phenotyping.rds only once the clusters are annotated.
  annotated <- file.exists(spe04) && file.mtime(spe04) >= pheno_start
} else {
  annotated <- file.exists(spe04)   # checked above
}

if (!annotated) {
  message("\nCluster annotation pending: steps 05-07 skipped (the reason is printed by ",
          "04_phenotyping above and in docs/04_phenotyping.html).\n",
          "Fill in the first tab of the workbook named there (in ",
          file.path(output, "annotation"), ") and run run_analysis.R again.")
} else {
  # --- BM sample analysis: cellular communities (05.1) and DA (05.2) --------
  # 05.1 is rendered four times: samples clustered on all / on immune cell
  # types, each with and without the normal control BM. Each variant is knit
  # from its own temporary copy of the Rmd, so the HTML reports
  # (05.1_BM_cellularcomm_<variant>.html) keep separate figure folders
  # (workflowr names them after the Rmd).
  if (run_step("05")) {
    for (variant in names(n_communities)) {
      rmd_variant <- sprintf("analysis/05.1_BM_cellularcomm_%s.Rmd", variant)
      file.copy("analysis/05.1_BM_cellularcomm.Rmd", rmd_variant, overwrite = TRUE)
      tryCatch(render_step(rmd_variant, c(comm_params, list(
                 cluster_on       = sub("_.*$", "", variant),
                 include_controls = grepl("_with_controls$", variant),
                 n_communities    = n_communities[[variant]]))),
               finally = unlink(rmd_variant))
    }
    render_step("analysis/05.2_BM_DA.Rmd", da_params)   # control / timepoints / MYCN comparisons
  }

  # --- Validation by correlation with reference scRNA-seq datasets ----------
  if (run_step("06")) {
    render_step("analysis/06.1_correlation_Fetahu.Rmd", corr_params)   # NB bone marrow (Fetahu et al.)
    render_step("analysis/06.2_correlation_Lee.Rmd",    corr_params)   # healthy bone marrow (Lee et al.)
  }

  # --- Region / marker images (customised params) -------------------------
  # Standalone image step with its own params (image ids, crops, markers).
  # Reads spe_04_phenotyping.rds.
  image_params <- list(
    input    = input,
    output   = output,
    # Images to render in one pass (add / remove ids here).
    image_ids = c("20220517_20220309_20-154_BM_003"),
    markers  = c("DNA1_Ir193_mean", "GD2_Gd155_mean", "CD45_Eu153_mean",   # Ir193 = DNA2
                 "CD3_Sm152_mean", "CD14_Lu175_mean", "CD15_Bi209_mean"),
    # colour per marker (individual image + merge), keyed by short marker name
    marker_colours = c(DNA1 = "blue", GD2 = "green", CD45 = "magenta",
                       CD3 = "red", CD14 = "cyan", CD15 = "yellow"),
    # all six markers go into the merge (cytomapper's maximum)
    merge_exclude = character(0),
    # One zoom window c(xmin, xmax, ymin, ymax) per image id; NULL = whole image only.
    crops    = list(NULL)
  )
  render_step("analysis/07_generate_images.Rmd", image_params)

  message("\nAll steps completed. Rendered HTML is in docs/; objects & figures in ", output)
}
