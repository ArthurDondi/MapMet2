# MapMet2 — Apptainer image

A single [Apptainer](https://apptainer.org/) (formerly Singularity) image that
runs the **entire** MapMet2 R analysis (`analysis/01_read_data` …
`analysis/07_generate_images`).

The definition ([`mapmet2.def`](mapmet2.def)) is adapted from MapMetSC's
`apptainer/mapmetsc.def`: it is built **from scratch** on the same pinned base
(`rocker/rstudio:4.4.0` → R 4.4.0, **Bioconductor 3.19**), so MapMet2 and
MapMetSC run on identical package versions. Bone-marrow samples are cytospins,
so MapMet2 has no spatial step and does not need MapMetSC's
`imcRtools::testInteractions` fix; the only `imcRtools` function used is
`read_steinbock()`.

The `diffcyt` / `CATALYST` / `edgeR` stack is installed although the core
pipeline does not use it yet, so MapMetSC's comparative (differential-abundance)
analyses can be added later without rebuilding the image.

## Build

```bash
# from the repository root
./apptainer/build.sh            # -> ./mapmet2.sif
# or explicitly
apptainer build mapmet2.sif apptainer/mapmet2.def
```

Building pulls `rocker/rstudio:4.4.0` from Docker Hub and downloads the
CRAN/Bioconductor packages, so run it somewhere with outbound network access.
`apptainer build` needs root or `--fakeroot` (the helper script adds
`--fakeroot` automatically when you are not root). Expect a multi-GB `.sif`.

Bioconductor is pinned to release **3.19** (the one matching the rocker image's
frozen CRAN snapshot). The 3.19 repositories are added to `options(repos)` and
installed with plain `install.packages()` — deliberately *not* via
`BiocManager::install(version=)`, whose version-switch handshake fails behind a
strict HPC egress proxy. Packages are installed with a retry-only-missing loop,
and the build fails loudly at the completeness check rather than shipping a
half-installed image.

No local Apptainer? A manual GitHub Actions workflow
([`.github/workflows/build-apptainer.yml`](../.github/workflows/build-apptainer.yml))
builds the image and uploads it as an artifact — run it from the repo's
**Actions** tab.

## Run

The scripts read from `/mnt/data` and write to `/mnt/data/output_mapmet2` by
default (see the main [README](../README.md) for the expected layout and the
`MAPMET2_*` environment variables). Bind your extracted single-cell data there:

```bash
# render the whole pipeline in order (headless)
apptainer exec --bind /path/to/singlecelldata:/mnt/data \
    mapmet2.sif Rscript run_analysis.R
```

```bash
# render a single script (e.g. the phenotyping step)
apptainer exec --bind /path/to/singlecelldata:/mnt/data mapmet2.sif \
    Rscript -e 'rmarkdown::render("analysis/04_phenotyping.Rmd",
                  output_dir="docs",
                  params=list(input="/mnt/data/input_all",
                              output="/mnt/data/output_mapmet2"))'
```

```bash
# drop into an interactive R session
apptainer run --bind /path/to/singlecelldata:/mnt/data mapmet2.sif
```

On a SLURM cluster, use [`run_mapmet2_slurm.sh`](../run_mapmet2_slurm.sh).

### RStudio Server (optional)

The base image ships RStudio Server. Apptainer containers are read-only, so
redirect the server's writable directories to bind mounts:

```bash
mkdir -p rstudio-run/{tmp,var,run}
PASSWORD=mapmet2 apptainer exec \
    --bind rstudio-run/var:/var/lib/rstudio-server \
    --bind rstudio-run/run:/var/run/rstudio-server \
    --bind rstudio-run/tmp:/tmp \
    --bind /path/to/MapMet2:/home/rstudio/MapMet2 \
    --bind /path/to/singlecelldata:/mnt/data \
    mapmet2.sif \
    /usr/lib/rstudio-server/bin/rserver --www-port 8787 \
        --auth-none 0 --auth-pam-helper-path=pam-helper --server-user=$(whoami)
# then open http://localhost:8787  (user: your shell user, password: mapmet2)
```

## Notes

- Built `.sif` files are git-ignored (`*.sif`).
- The image records provenance at `/opt/mapmet2-sessionInfo.txt` and
  `/opt/mapmet2-packages.csv`.
