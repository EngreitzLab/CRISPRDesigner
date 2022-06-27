# Snakemake workflow: CRISPRDesigner

[![Snakemake](https://img.shields.io/badge/snakemake-≥5.5.0-brightgreen.svg)](https://snakemake.bitbucket.io)
[![Build Status](https://travis-ci.org/snakemake-workflows/{{cookiecutter.repo_name}}.svg?branch=master)](https://travis-ci.org/snakemake-workflows/{{cookiecutter.repo_name}})

This snakemake workflow is a wrapper for the CRISPR SpCas9 guideRNA designer used in Engreitz Lab CRISPR screens (e.g., Fulco et al. Science 2016, Fulco, Nasser, et al. Nat Genet 2019).  


## Authors

* Jesse Engreitz (@engreitz)

## Description

Guide RNAs are first designed against all NGG PAM sites.  

Guide specificity / off-target scores are calculated according to the original Feng Zhang MIT score, and efficacy scores are computed using Tim Wang et al. Science 2014.  

Then, the following filters are applied to remove gRNAs that match any of the following conditions:
- A N in the reference genome
- More than 1 T/U in the last 4 nucleotides, which combine with the first few nucleotides of the gRNA scaffold to terminate Pol III transcription
- More than 40% total T/U content
- 4-mer T/U repeats
- 5-mer mononucleotide repeats 
- Low-complexity sequences, defined as 10 nucleotides of 2-nt repeat, 12 nucleotides of 3- or 4-nt repeats, or 18 nucleotides of 5- or 6-nt repeats
- <= 20% GC content
- >= 90% GC content  

This code also allows providing a list of previously designed and scored gRNAs, so that new runs only need to design gRNAs for new regions.

## Usage

### Step 1: Clone this github repository

[Clone](https://help.github.com/en/articles/cloning-a-repository) this to your local system, into the place where you want to perform the data analysis.

### Step 2: Install conda environment

Install Snakemake and conda environment using [conda](https://conda.io/projects/conda/en/latest/user-guide/install/index.html):

    conda env create --file workflow/envs/CRISPRDesignerSnakemake.yaml

For installation details, see the [instructions in the Snakemake documentation](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html).

### Step 3: Create input regions BED file

Create an input 'regions' BED file, with columns `chr   start   end     name`. The snakemake script will find and score guides in these regions, and label them with the provided region name.  If desired, also collect a list of pre-designed guideRNAs (BED file with regions, and filteredGuides.bed file with guide scores)

### Step 4: Configure workflow

Configure the workflow according to your needs via editing the files in the `config/` folder. Adjust `config.yaml` to configure the workflow execution, including to define the `regions` variable to point to your BED file. If desired, set up `predesigned_guides` in `config.yaml`.  

For non-Engreitz Lab users, large input files can be downloaded [here](https://drive.google.com/drive/u/1/folders/1F5-v0KopsE7hshjwMbHEryXd2wkDdR2Q):
    
    hg19.CRISPR.bit         Custom bit-compressed index for off-target scoring for hg19
    mm9.CRISPR.sorted.bit   Custom bit-compressed index for off-target scoring for mm9
    filteredGuides.210615Combined.bed.gz    Pre-designed and pre-scored gRNAs in a large number of regions in the human genome (hg19), including all gene promoters, GATA1 and MYC loci, and others. 
    regions.210615Combined.bed  Regions corresponding to the gRNAs designed above.
    

### Step 5: Execute workflow

Activate the conda environment:

    conda activate CRISPRDesignerSnakemake 
    ## Currently, this doesn't work yet on Sherlock:  Instead: conda activate Engreitz Lab

Test your configuration by performing a dry-run via

    snakemake -n

Execute the workflow locally via

    snakemake --cores $N

using `$N` cores or run it in a cluster environment via

`
snakemake \
  --config java_memory=15g \
  --cores 1 \
  --jobs 50 \
  --cluster "sbatch -n 1 -c 1 --mem 16G -t 12:00:00 -p owners -J CRISPRDesigner_{rule} -o logs/{rule}_{wildcards} -e logs/{rule}_{wildcards}"
`

For more about cluster configuration using snakemake, see [here](https://www.sichong.site/2020/02/25/snakemake-and-slurm-how-to-manage-workflow-with-resource-constraint-on-hpc/)

## Outputs

Final outputs of the pipeline will be found in `results/GuideDesign/`. Key files are:

`designGuides.txt` example:
`chr	start	end	locus	score	strand	GuideSequenceWithPAM	guideSet	SSC
chrX	47655734	47655754	chrX:47655734-47655754:-	69.41302489032086	-	CAAGCAACCAAGAGTATTTGAGG	K562|chrX:47655746-47656047	0
chrX	47655787	47655807	chrX:47655787-47655807:-	76.32325648993465	-	CAGAGGCAGCAAAAGGCCTAGGG	K562|chrX:47655746-47656047	0
chrX	47655787	47655807	chrX:47655787-47655807:-	76.32298400105441	-	CAGAGGCAGCAAAAGGCCTAGGG	K562|chrX:47655746-47656047	0
chrX	47655788	47655808	chrX:47655788-47655808:-	66.18525320395382	-	TCAGAGGCAGCAAAAGGCCTAGG	K562|chrX:47655746-47656047	0
chrX	47655794	47655814	chrX:47655794-47655814:-	66.54001770837637	-	CATTCTTCAGAGGCAGCAAAAGG	K562|chrX:47655746-47656047	0

Column description:
chr         chromosome
start       start coordinate of gRNA spacer
end         end coordinate of gRNA spacer
locus       coordinates of gRNA spacer
score       The score has two components. The integer component (0-100) is a specificity score, where 100 is good (high specificity, low off-targets) and 0 is bad (low specificity, high off-target potential). The decimal component (0.0-0.1) is a efficiency score, where 0.1 is good and 0.0 is bad.
strand      genomic strand of gRNA spacer
GuideSequenceWithPAM    Sequence of gRNA spacer plus trailing NGG PAM sequence from genome
guideSet    String that matches one of the input regions
SSC         [ignore]


`designGuides.bed` has a subset of columns and is formatted as a BED file for viewing in a genome browser.
