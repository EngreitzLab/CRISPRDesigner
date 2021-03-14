# Snakemake workflow: CRISPRDesigner

[![Snakemake](https://img.shields.io/badge/snakemake-≥5.5.0-brightgreen.svg)](https://snakemake.bitbucket.io)
[![Build Status](https://travis-ci.org/snakemake-workflows/{{cookiecutter.repo_name}}.svg?branch=master)](https://travis-ci.org/snakemake-workflows/{{cookiecutter.repo_name}})

This is the template for a new Snakemake workflow. Replace this text with a comprehensive description covering the purpose and domain.
Insert your code into the respective folders, i.e. `scripts`, `rules`, and `envs`. Define the entry point of the workflow in the `Snakefile` and the main configuration in the `config.yaml` file.

## Authors

* Jesse Engreitz (@engreitz)

## Usage

### Step 1: Clone this github repository

[Clone](https://help.github.com/en/articles/cloning-a-repository) this to your local system, into the place where you want to perform the data analysis.

### Step 2: Install conda environment

Install Snakemake and conda environment using [conda](https://conda.io/projects/conda/en/latest/user-guide/install/index.html):

    conda env create --file workflow/envs/CRISPRDesignerSnakemake.yaml

For installation details, see the [instructions in the Snakemake documentation](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html).

### Step 3: Create input regions BED file

Create an input 'regions' BED file, with columns `chr   start   end     name`. The snakemake script will find and score guides in these regions, and label them with the provided region name.

### Step 4: Configure workflow

Configure the workflow according to your needs via editing the files in the `config/` folder. Adjust `config.yaml` to configure the workflow execution, including to define the `regions` variable to point to your BED file

### Step 5: Execute workflow

Activate the conda environment:

    conda activate CRISPRDesignerSnakemake

Test your configuration by performing a dry-run via

    snakemake -n

Execute the workflow locally via

    snakemake --cores $N

using `$N` cores or run it in a cluster environment via

`
snakemake \
  --config java_memory=16g \
  --cores 1 \
  --jobs 50 \
  --cluster "sbatch -n 1 -c 12 --mem 16G -t 2-00:00 -p engreitz -J CRISPRDesigner_{rule} -o logs/{rule}_{wildcards} -e logs/{rule}_{wildcards}"
`

For more about cluster configuration using snakemake, see [here](https://www.sichong.site/2020/02/25/snakemake-and-slurm-how-to-manage-workflow-with-resource-constraint-on-hpc/)
