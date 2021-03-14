from snakemake.utils import validate
import pandas as pd

# this container defines the underlying OS for each job when using the workflow
# with --use-conda --use-singularity
singularity: "docker://continuumio/miniconda3"

##### load config and sample sheets #####

configfile: "config/config.yaml"
validate(config, schema="../schemas/config.schema.yaml")


####### helpers ###########

def all_input(wildcards):

    wanted_input = []

    # Predesigned guide regions
    wanted_input.extend([
    	"results/GuideDesign/filteredGuides.bed",
    	"results/GuideDesign/designGuides.txt",
    	"results/GuideDesign/designGuides.bed"
    	])

    return wanted_input