# MapMet2 Docker image (adapted from MapMetSC's Dockerfile).
# The Apptainer definition in apptainer/mapmet2.def is the tested route (it pins
# Bioconductor 3.19 to the rocker CRAN snapshot); this Dockerfile is provided for
# local RStudio use.

# Docker inheritance
FROM rocker/rstudio:4.4.0

LABEL maintainer="TaschnerMandl group"
LABEL version="mapmet2"

RUN apt-get -y update \
    && apt-get install -y --no-install-recommends apt-utils \
    && apt-get install -y --no-install-recommends zlib1g-dev libglpk-dev libmagick++-dev libfftw3-dev libxml2-dev libxt-dev curl libcairo2-dev libproj-dev libgdal-dev libudunits2-dev libarchive-dev \
       libgit2-dev libgeos-dev libtiff-dev libjpeg-dev libpng-dev libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev pandoc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN R -e 'install.packages(c("rmarkdown", "pheatmap", "viridis", "BiocManager", "devtools", "tiff", \
                             "ggrepel", "patchwork", "mclust", "RColorBrewer", "uwot", "Seurat", \
                             "SeuratObject", "cowplot", "ggridges", "gridGraphics", "scales", "Matrix", \
                             "workflowr", "writexl", "ggrastr", "hexbin"))'
RUN R -e 'BiocManager::install(c("CATALYST", "scater", "dittoSeq", "tidyverse", "imcRtools", \
                                 "cytomapper", "ComplexHeatmap", "BiocParallel", "SingleR", "diffcyt", \
                                 "BioQC", "edgeR", "EBImage", "stringr", "circlize", "paletteer", "tidyHeatmap", "bruceR", \
                                 "FactoMineR", "factoextra", "ggpubr", "rstatix", "gridExtra", "gtools", "forcats", "openxlsx"))'
RUN R -e 'devtools::install_github("stuchly/Rphenoannoy@8b81e2e7fb0599f45070e2cba1b28ac219b7c472")'
