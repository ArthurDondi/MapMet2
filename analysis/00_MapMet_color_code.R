#!/usr/bin/env Rscript

# ============================================================================
# MapMet2 - central color definitions and display labels
#
# Adapted from MapMetSC's analysis/00_MapMet_color_code.R. Shared palettes for
# the bone-marrow (BM) single-cell analysis, collected here so that every script
# uses the same colors. Source this file near the top of a script (path-robust
# across working directories) and then assign the vector(s) you need.
# ============================================================================

# ---- Cell types (04_phenotyping.Rmd) ---------------------------------------
# Starting palette carried over from MapMetSC: cell types that keep a MapMetSC
# name reuse its color. Names that are not listed here (new BM-specific cell
# types from the MapMet2 annotation) get a deterministic color from
# complete_palette() below, so plots never drop a category.
COL_CELLTYPE <- c(
  ## Tumor
  "Ki67+ Tu"                  = rgb(128, 128,   0, maxColorValue = 255),  # olive
  "CD44+ Tu"                  = rgb( 50, 205,  50, maxColorValue = 255),  # bright lime green
  "GD2neg Tu"                 = rgb(189, 183, 107, maxColorValue = 255),  # khaki
  "early neuroblast-like Tu"  = rgb(152, 251, 152, maxColorValue = 255),  # pale green
  "adrenergic marker-low Tu"  = rgb( 34, 100,  60, maxColorValue = 255),  # dark green
  "neuroblast-like Tu"        = rgb(  0, 145, 150, maxColorValue = 255),  # teal / blue-green

  ## Proliferation
  "Ki67+ cells"               = rgb(255, 200,   0, maxColorValue = 255),
  "CXCR4+ cells"              = rgb(255, 245, 160, maxColorValue = 255),

  ## Progenitor
  "CD34+ HSPCs"               = rgb(255,  95,   0, maxColorValue = 255),

  ## T cells
  "CD8+ T cells"              = rgb(220,  20,  60, maxColorValue = 255),  # crimson
  "CD4+ T cells"              = rgb(255, 127,  80, maxColorValue = 255),  # coral
  "CD3+ T cells"              = rgb(139,   0,   0, maxColorValue = 255),  # dark red
  "CD8+ S100B+ T cells"       = rgb(230,  20, 210, maxColorValue = 255),  # fuchsia
  "CD8+ GZMB+ T cells"        = rgb(255, 182, 193, maxColorValue = 255),  # light pink
  "dense T cell region"       = rgb(199,  21, 133, maxColorValue = 255),  # magenta

  ## Myeloid
  "granulocytes"              = rgb(  8,  48, 107, maxColorValue = 255),
  "CD14+ MO"                  = rgb( 33, 102, 172, maxColorValue = 255),
  "myeloid cells"             = rgb( 64, 180, 170, maxColorValue = 255),
  "GZMB+ DC/NK cells"         = rgb(107, 174, 214, maxColorValue = 255),

  ## B cells
  "B cells"                   = rgb(136,  86, 167, maxColorValue = 255),

  ## Stromal
  "Schwann cells"             = rgb(166,  97,  26, maxColorValue = 255),
  "fibroblast/endothel"       = rgb(101,  67,  33, maxColorValue = 255),

  ## Other
  "other"                     = rgb(120, 120, 120, maxColorValue = 255),

  ## MapMet2 (BM) cell types
  "HSPCs"                     = "#FFA500",  # plain orange
  "CD4+ PD1+ T cells"         = "#B5475D",  # light bordeaux
  "pDC"                       = "#6497D1",
  "PDL1+ MO"                  = "#0073E6"   # blue (the fallback color was too close to B cells)
)

# ---- Metaclusters (04_phenotyping.Rmd) -------------------------------------
# The correlation steps (06.x) rely on the MapMetSC metacluster names "tumor"
# and "other"; keep these names in the MapMet2 annotation.
COL_METACLUSTER <- c(
  "tumor"               = "#238B45",
  "T cells"             = "#E34A33",
  "granulocytes"        = "#08306B",
  "myeloid/NK"          = "#41B6C4",
  "B cells"             = "#88419D",
  "mesenchymal"         = "#8C510A",
  "proliferating cells" = "#FFD700",
  "progenitors"         = "#FFA500",  # = HSPCs cell-type color (plain orange)
  "HSPCs"               = "#FFA500",
  "other"               = "#969696"
)

# ---- Sample groups / timepoints (01_read_data.Rmd onwards) ------------------
# Metadata (Suppl. Table 1, column Timepoint) codes the BM timepoints as
# DE / RE1 / RE2 / REL; MapMet2 displays RE1 / RE2 as the treatment timepoints
# T1 / T2. Normal (non-infiltrated) control BM samples get the label "control".
TIMEPOINT_RELABEL <- c("DE" = "DE", "RE1" = "T1", "RE2" = "T2", "REL" = "REL")
TIMEPOINT_LEVELS  <- c("control", "DE", "T1", "T2", "REL")
COL_TIMEPOINT <- c(
  "control" = "#969696",  # grey
  "DE"      = "#2C7BB6",  # diagnosis: blue
  "T1"      = "#ABD9E9",  # treatment timepoint 1: light blue
  "T2"      = "#FDAE61",  # treatment timepoint 2: orange
  "REL"     = "#D7191C"   # relapse: red
)

# ---- Patient cohort overview tracks (01_read_data.Rmd cohort figure) -------
# Sample availability per timepoint (yes / no tiles).
COL_AVAIL <- c(
  "yes" = "#A89F8F",  # taupe
  "no"  = "#E6DFD3"   # beige
)
# MYCN amplification / 1p loss / progression.
COL_YNH <- c(
  "yes" = rgb(202,   0,  32, maxColorValue = 255),  # red
  "no"  = rgb(  5, 113, 176, maxColorValue = 255),  # blue
  "het" = rgb(146, 197, 222, maxColorValue = 255),  # light blue
  "NA"  = "#F0F0F0"                                 # unknown: near-white
)
COL_SEX <- c(
  "f"   = rgb(202,   0,  32, maxColorValue = 255),  # red
  "m"   = rgb(  5, 113, 176, maxColorValue = 255)   # blue
)

# ---- Fetahu et al. reference: RNA cluster colors (06.1_correlation_Fetahu.Rmd)
COL_FETAHU_CLUSTERS <- c(
  "B (3)"       = rgb(145,   2, 144, maxColorValue = 255),
  "B (16)"      = rgb(253, 218, 236, maxColorValue = 255),
  "B (19)"      = rgb(240,   0, 240, maxColorValue = 255),
  "B (11)"      = rgb(188, 128, 189, maxColorValue = 255),
  "B (7)"       = rgb(190, 174, 212, maxColorValue = 255),
  "M (1)"       = rgb( 28, 146, 255, maxColorValue = 255),
  "M (10)"      = rgb(  0, 255, 255, maxColorValue = 255),
  "M (15)"      = rgb( 39, 130, 187, maxColorValue = 255),
  "M (2)"       = rgb(166, 206, 227, maxColorValue = 255),
  "T (18)"      = rgb(227,  26,  28, maxColorValue = 255),
  "T (5)"       = rgb(254, 142, 175, maxColorValue = 255),
  "T (6)"       = rgb(242,   3, 137, maxColorValue = 255),
  "T (9)"       = rgb(251, 128, 114, maxColorValue = 255),
  "SC (14)"     = rgb(149, 144,  89, maxColorValue = 255),
  "SC (17)"     = rgb(210, 205, 126, maxColorValue = 255),
  "SC (20)"     = rgb(230, 245, 201, maxColorValue = 255),
  "NB (8)"      = rgb( 60, 119,  97, maxColorValue = 255),
  "E (13)"      = rgb(254, 217, 166, maxColorValue = 255),
  "NK (4)"      = rgb(212, 143,  75, maxColorValue = 255),
  "pDC (12)"    = rgb(253, 180,  98, maxColorValue = 255),
  "other (21)"  = rgb(174, 129,  37, maxColorValue = 255)
)

# ---- Fetahu et al. reference: predicted metacluster colors ------------------
COL_FETAHU_METACLUSTER <- c(
  "NB"    = "palegreen4",
  "NK"    = "#FB8072",
  "T"     = "indianred",
  "E"     = "#80B1D3",
  "M"     = "#8DD3C7",
  "B"     = "#BC80BD",
  "other" = "goldenrod1",
  "pDC"   = "tan4",
  "SC"    = "tan2"
)

# ---- Lee et al. reference: extra label colors (06.2_correlation_Lee.Rmd) ----
# Added on top of the per-celltype colors read from Lee/celltype_metacluster.csv.
COL_LEE_EXTRA <- c("tumor" = "grey70", "other" = "goldenrod1")  # grey70: visible on white

# ---- Generic qualitative palette for random sample/cluster colors (02_QC_1) -
# All named R colors except greys, used to assign arbitrary colors to samples /
# clusters where the specific hue does not carry meaning.
COL_VECTOR_433 <- grDevices::colors()[grep("gr(a|e)y", grDevices::colors(), invert = TRUE)]

# ---- MapMet2 names that take the color of a MapMetSC name -----------------
PALETTE_ALIASES <- c(
  "GD2low Tu"                = "GD2neg Tu",
  "PDL1+ neuroblast-like Tu" = "Ki67+ Tu"
)

# ---- Helper: complete a named palette for a set of labels -------------------
# Returns one color per unique label. A label takes the palette color of the
# same name, matched ignoring case, spaces, hyphens / punctuation and a final
# plural "s" (e.g. "T cell", "t-cells" -> "T cells"), or of its alias in
# PALETTE_ALIASES. The other labels get a deterministic pick from
# COL_VECTOR_433 that avoids the colors already in use; they are listed in
# attr(, "unmatched"). Order follows `labels` (first appearance).
norm_label <- function(x) sub("s$", "", gsub("[^a-z0-9+]", "", tolower(x)))
complete_palette <- function(labels, palette, seed = 221228, aliases = PALETTE_ALIASES) {
  labels <- unique(as.character(labels[!is.na(labels)]))
  target <- ifelse(labels %in% names(aliases), aliases[labels], labels)
  hit    <- match(norm_label(target), norm_label(names(palette)))
  out    <- setNames(unname(palette[hit[!is.na(hit)]]), labels[!is.na(hit)])
  missing <- labels[is.na(hit)]
  if (length(missing)) {
    pool <- setdiff(COL_VECTOR_433, out)
    # drop near-white / near-black colors (invisible on white, or read as text)
    rgb01 <- grDevices::col2rgb(pool) / 255
    lum   <- 0.2126 * rgb01[1, ] + 0.7152 * rgb01[2, ] + 0.0722 * rgb01[3, ]
    pool  <- pool[lum > 0.1 & lum < 0.85]
    set.seed(seed)
    extra <- sample(pool, length(missing), replace = length(missing) > length(pool))
    out <- c(out, setNames(extra, missing))
  }
  out <- out[labels]
  attr(out, "unmatched") <- missing
  out
}
