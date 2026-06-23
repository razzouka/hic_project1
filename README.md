# hic_project1

Educational project completed for the course **Analysis methods of structural and functional chromatin organization**.

This repository contains a reproducible Hi-C preprocessing workflow, starting from raw paired-end Hi-C reads and ending with `.hic` contact map files that can be opened in Juicebox for downstream visualization and comparison.

## Project goal

The goal of this project was to build a bash-based pipeline for processing multiple Hi-C samples from raw FASTQ files to final `.hic` files. The workflow includes reference genome preparation, read quality control, adapter trimming, Juicer-based processing, and generation of contact maps for visual inspection in Juicebox.

## Workflow summary

The project was organized into the following main stages:

1. Prepare the reference genome:
   - download the T2T-CHM13v2.0 human genome FASTA,
   - decompress the `.fna.gz` file,
   - rename chromosome headers into `chr*` format,
   - build the `bwa` index,
   - generate `chrom.sizes`,
   - generate restriction site positions for Juicer using the DpnII enzyme.

2. Prepare raw Hi-C reads:
   - download paired-end FASTQ files,
   - run FastQC for initial quality assessment,
   - trim adapters and low-quality ends with cutadapt.

3. Generate Hi-C contact maps:
   - run the Juicer pipeline locally,
   - collect the final `.hic` files,
   - inspect the contact maps in Juicebox.

## Repository structure

This repository keeps scripts, documentation, and lightweight service files. Large input data, intermediate files, downloaded tools, and final heavy outputs are excluded from version control using `.gitignore`.

```text
hic_project1/
├── README.md
├── .gitignore
├── data/
│   └── .gitkeep
├── results/
│   └── .gitkeep
├── tools/
│   └── .gitkeep
└── scripts/
    ├── hic_pipeline.sh
    └── rename_chroms_t2t.py
```

## Files included in the repository

- `scripts/hic_pipeline.sh` — the main bash pipeline for processing Hi-C samples.
- `scripts/rename_chroms_t2t.py` — helper script to rename T2T reference chromosome headers into `chr*` format.
- `.gitignore` — excludes large raw, intermediate, and result files from Git tracking.

## Main tools used

- FastQC
- cutadapt
- bwa
- samtools
- Java
- Juicer
- Juicebox

## Reference genome and visualization

The reference genome used in this project was the human T2T-CHM13v2.0 assembly from NCBI. Final contact maps were generated as `.hic` files for interactive visualization in Juicebox, which is the standard viewer used with Juicer outputs.
