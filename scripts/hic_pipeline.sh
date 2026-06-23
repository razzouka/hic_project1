#!/usr/bin/env bash
set -euo pipefail

# ======================
# CONFIG
# ======================

REF_FASTA="$(pwd)/data/reference/T2T_human.fna"
CHROM_SIZES="$(pwd)/data/reference/chrom.sizes"
RE_SITE_FILE="$(pwd)/data/reference/restriction_sites_DpnII.txt"
JUICER_DIR="$(pwd)/tools/juicer"
THREADS=8

SAMPLES=("MoPh7" "MoPh11" "MoPh14" "MoPh15")
BASE_URL="https://genedev.bionet.nsc.ru/ftp/_RawReads/2025-05-23MyGenetics"

declare -A R1_REMOTE
declare -A R2_REMOTE

R1_REMOTE["MoPh7"]="Copy%20of%20MoPh7_S85_L001_R1_001.fastq.gz"
R2_REMOTE["MoPh7"]="Copy%20of%20MoPh7_S85_L001_R2_001.fastq.gz"

R1_REMOTE["MoPh11"]="Copy%20of%20MoPh11_S86_L001_R1_001.fastq.gz"
R2_REMOTE["MoPh11"]="Copy%20of%20MoPh11_S86_L001_R2_001.fastq.gz"

R1_REMOTE["MoPh14"]="Copy%20of%20MoPh14_S87_L001_R1_001.fastq.gz"
R2_REMOTE["MoPh14"]="Copy%20of%20MoPh14_S87_L001_R2_001.fastq.gz"

R1_REMOTE["MoPh15"]="Copy%20of%20MoPh15_S88_L001_R1_001.fastq.gz"
R2_REMOTE["MoPh15"]="Copy%20of%20MoPh15_S88_L001_R2_001.fastq.gz"

# ======================
# STEP 1: DOWNLOAD FASTQ (skip if present)
# ======================

echo "=== STEP 1: Download raw FASTQ files (skipping existing) ==="
mkdir -p data/raw

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Processing downloads for ${SAMPLE} ..."
  R1_FILE="data/raw/${SAMPLE}_R1.fastq.gz"
  R2_FILE="data/raw/${SAMPLE}_R2.fastq.gz"

  R1_URL="${BASE_URL}/${R1_REMOTE[${SAMPLE}]}"
  R2_URL="${BASE_URL}/${R2_REMOTE[${SAMPLE}]}"

  if [[ -f "${R1_FILE}" ]]; then
    echo "  ${R1_FILE} exists, skipping download."
  else
    echo "  Downloading ${R1_FILE} ..."
    wget --no-check-certificate -O "${R1_FILE}" "${R1_URL}"
  fi

  if [[ -f "${R2_FILE}" ]]; then
    echo "  ${R2_FILE} exists, skipping download."
  else
    echo "  Downloading ${R2_FILE} ..."
    wget --no-check-certificate -O "${R2_FILE}" "${R2_URL}"
  fi
done

ls -lh data/raw

# ======================
# STEP 2: FASTQC ON RAW (skip if report exists)
# ======================

echo "=== STEP 2: FastQC on raw reads ==="
mkdir -p results/fastqc_raw

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Running FastQC for ${SAMPLE} ..."
  R1="data/raw/${SAMPLE}_R1.fastq.gz"
  R2="data/raw/${SAMPLE}_R2.fastq.gz"

  # FastQC output files (zip + html). We’ll check one of them.
  OUT_HTML="results/fastqc_raw/${SAMPLE}_R1_fastqc.html"

  if [[ -f "${OUT_HTML}" ]]; then
    echo "  FastQC report for ${SAMPLE} already exists, skipping."
    continue
  fi

  fastqc "${R1}" "${R2}" -o results/fastqc_raw
done

echo "FastQC done. Check results/fastqc_raw/"

# ======================
# STEP 3: TRIMMING WITH CUTADAPT (paired-end)
# ======================

echo "=== STEP 3: Trimming with cutadapt ==="

mkdir -p data/trimmed
mkdir -p results/cutadapt

ADAPTER_R1="AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
ADAPTER_R2="AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT"
POLY_A="A{30}"
POLY_G="G{30}"

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Trimming ${SAMPLE} ..."
  R1_IN="data/raw/${SAMPLE}_R1.fastq.gz"
  R2_IN="data/raw/${SAMPLE}_R2.fastq.gz"

  R1_OUT="data/trimmed/${SAMPLE}_R1.trimmed.fastq.gz"
  R2_OUT="data/trimmed/${SAMPLE}_R2.trimmed.fastq.gz"

  LOG="results/cutadapt/${SAMPLE}.cutadapt.log"

  # Skip if trimmed R1 already exists
  if [[ -f "${R1_OUT}" ]]; then
    echo "  Trimmed files for ${SAMPLE} already exist, skipping."
    continue
  fi

  cutadapt \
   -q 20 \
   -m 70 \
   -a "${ADAPTER_R1}" \
   -A "${ADAPTER_R2}" \
   -a "${POLY_A}" \
   -A "${POLY_A}" \
   -a "${POLY_G}" \
   -A "${POLY_G}" \
   -n 3 \
   -o "${R1_OUT}" \
   -p "${R2_OUT}" \
   "${R1_IN}" \
   "${R2_IN}" \
   > "${LOG}" 2>&1
done

echo "Cutadapt trimming done. Check data/trimmed/ and results/cutadapt/"

# ======================
# STEP 4: FASTQC ON TRIMMED READS
# ======================

echo "=== STEP 4: FastQC on trimmed reads ==="

mkdir -p results/fastqc_trimmed

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Running FastQC on trimmed reads for ${SAMPLE} ..."
  R1_TRIM="data/trimmed/${SAMPLE}_R1.trimmed.fastq.gz"
  R2_TRIM="data/trimmed/${SAMPLE}_R2.trimmed.fastq.gz"

  OUT_HTML_TRIM="results/fastqc_trimmed/${SAMPLE}_R1.trimmed_fastqc.html"

  if [[ -f "${OUT_HTML_TRIM}" ]]; then
    echo "  Trimmed FastQC report for ${SAMPLE} already exists, skipping."
    continue
  fi

  fastqc \
    "${R1_TRIM}" \
    "${R2_TRIM}" \
    -o results/fastqc_trimmed
done

echo "FastQC on trimmed reads done. Check results/fastqc_trimmed/"

# ======================
# STEP 5: PREPARE JUICER DIRECTORIES (symlinks to trimmed FASTQ)
# ======================

echo "=== STEP 5: Prepare Juicer input directories ==="

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Preparing Juicer folder for ${SAMPLE} ..."
  SAMPLE_DIR="$(pwd)/data/juicer/${SAMPLE}"
  FASTQ_DIR="${SAMPLE_DIR}/fastq"

  mkdir -p "${FASTQ_DIR}"

  R1_TRIM="$(pwd)/data/trimmed/${SAMPLE}_R1.trimmed.fastq.gz"
  R2_TRIM="$(pwd)/data/trimmed/${SAMPLE}_R2.trimmed.fastq.gz"

  # Symlink names inside Juicer structure
  R1_LINK="${FASTQ_DIR}/${SAMPLE}_R1.fastq.gz"
  R2_LINK="${FASTQ_DIR}/${SAMPLE}_R2.fastq.gz"

  # Create or update symlinks
  ln -sf "${R1_TRIM}" "${R1_LINK}"
  ln -sf "${R2_TRIM}" "${R2_LINK}"

  # Optional check
  ls -lh "${FASTQ_DIR}"
done

echo "Juicer input directories ready under data/juicer/<sample>/fastq/"

# ======================
# STEP 6: RUN JUICER AND COLLECT .hic FILES
# ======================

echo "=== STEP 6: Run Juicer for each sample ==="

mkdir -p results/hic

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Running Juicer for ${SAMPLE} ..."

  SAMPLE_DIR="$(pwd)/data/juicer/${SAMPLE}"
  HIC_OUT="results/hic/${SAMPLE}.inter_30.hic"

  # Skip if final .hic already exists
  if [[ -f "${HIC_OUT}" ]]; then
    echo "  ${HIC_OUT} already exists, skipping Juicer."
    continue
  fi

  # Run Juicer
  bash "${JUICER_DIR}/scripts/juicer.sh" \
    -D "${JUICER_DIR}" \
    -d "${SAMPLE_DIR}" \
    -g T2T_human \
    -z "${REF_FASTA}" \
    -p "${CHROM_SIZES}" \
    -y "${RE_SITE_FILE}" \
    -s DpnII \
    -t "${THREADS}"

  # Copy resulting .hic
  if [[ -f "${SAMPLE_DIR}/aligned/inter_30.hic" ]]; then
    cp "${SAMPLE_DIR}/aligned/inter_30.hic" "${HIC_OUT}"
    echo "  Saved ${HIC_OUT}"
  else
    echo "  WARNING: inter_30.hic not found for ${SAMPLE}" >&2
  fi
done

echo "All Juicer runs done. Check results/hic/ for .hic files."
