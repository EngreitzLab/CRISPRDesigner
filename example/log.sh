###########################################################################
## Jesse Engreitz
## 6/14/21
## CRISPRi library targeting all DNase peaks in GATA1 locus in K562, GM12878, and HCT116 cell lines
## This log.sh file lists commands that will need to be modified for future projects,
##  and is meant to be run by copy/pasting each line sequentially into your shell

###########################################################################
## Set key variables for the project
PROJECT=$OAK/Projects/CRISPRDesign/210614_GATA1LocusCRISPRi/; cd $PROJECT
CODEDIR=$PROJECT/CRISPRiTilingDesign/
SIZES=/oak/stanford/projects/genomics-refs/refs/hg19/hg19.chrom.sizes
GENOME_FASTA=/oak/stanford/projects/genomics-refs/refs/hg19/male.hg19.fa
OFF_TARGET_BITS=$OAK/Projects/CRISPR/OffTargets/hg19.CRISPR.bit
PROMOTERS=$GROUP_HOME/Software/ABC-Enhancer-Gene-Prediction/reference/RefSeqCurated.170308.bed.CollapsedGeneBounds.TSS500bp.bed


## Download CRISPR designer code
git clone git@github.com:broadinstitute/CRISPRiTilingDesign.git
git clone git@github.com:EngreitzLab/CRISPRDesigner.git

## If necessary, install the conda environment (already installed on Stanford Sherlock in $GROUP_HOME/Software/anaconda3/envs/):
## conda env create -f CRISPRiTilingDesign/CRISPRDesigner.yml
conda activate EngreitzLab


###########################################################################
## Set up directories
mkdir -p $PROJECT/{01_ChooseRegions,02_RunCRISPRDesigner,03_Subpools,04_CombinePools}


#######################################################################################
## 01_ChooseRegions
## Output of this section:  
##      - A BED file containing chr,start,end,name (no header) listing all of the regions 
##        in which to design gRNAs

ABCLIST=/oak/stanford/groups/engreitz/Projects/ABC/191216_ABC/config/210221.ABCCellTypeTable.ABCPaperV3.LocusPlots.txt
CELLTYPES="K562 HCT116 GM12878"  ## Matching MergedCellType column of $ABCLIST
RANGE=1000000  ## Distance on either side of gene to include DNase peaks
GENES="GATA1"  ## comma-delimited

## Set genes to tile:
echo $GENES | tr ',' '\n' > $PROJECT/01_ChooseRegions/ChosenGenes.txt

## Grab the promoter regions for each of the selected genes
grep -w -f $PROJECT/01_ChooseRegions/ChosenGenes.txt $PROMOTERS | awk -v OFS=$'\t' '{ $4=$4 "_TSS"; print $0 }'> $PROJECT/01_ChooseRegions/ChosenGenes.Promoters.bed

## Create a ChosenGenes.Loci.bed by selecting 1 Mb on either side of the chosen genes
cat $PROJECT/01_ChooseRegions/ChosenGenes.Promoters.bed | bedtools slop -i stdin -b $RANGE -g $SIZES > $PROJECT/01_ChooseRegions/ChosenGenes.Loci.bed

## Grab 300bp regions centered on DNase peak summits from the ABC candidate regions in each of the cell types
for celltype in $CELLTYPES; do
  ABCDIR=$(cat $ABCLIST |  csvtk grep -t -f MergedCellType -p $celltype | csvtk cut -t -f Neighborhoods | tail -1)
  cat $ABCDIR/../Peaks/macs2_summits.bed | bedtools intersect -u -a stdin -b $PROJECT/01_ChooseRegions/ChosenGenes.Loci.bed | \
    bedtools intersect -a stdin -b $ABCDIR/EnhancerList.bed | \
    bedtools slop -b 150 -i stdin -g $SIZES | \
    bedtools sort -i stdin -faidx $SIZES | \
    bedtools merge -i stdin -g $SIZES | \
    cut -f 1-3 | \
    awk -v celltype=$celltype '{ print $1 "\t" $2 "\t" $3 "\t" celltype "|" $1 ":" $2 "-" $3 }' > $PROJECT/01_ChooseRegions/ChosenGenes.${celltype}.summits.bed
done

## Add in full 500-bp promoter regions, not just 300-bp regions around summits, and combine multiple cell types into one file
cat $PROJECT/01_ChooseRegions/ChosenGenes.Promoters.bed $PROJECT/01_ChooseRegions/ChosenGenes.*.summits.bed | \
  cut -f 1-4 | bedtools sort -i stdin -faidx $SIZES > \
  $PROJECT/01_ChooseRegions/ChosenGenes.AllRegions.bed

## To do: Add some code reporting total number of regions and region sizes -- want to avoid any regions that are too big



#######################################################################################
## 02_RunCRISPRDesigner

## Checkout the snakemake pipeline above
## Set up snakemake pipeline by editing CRISPRDesigner/config/config.yaml
## Then, run the CRISPRDesigner snakemake pipeline:
cd $PROJECT/CRISPRDesigner/
mkdir logs
snakemake &

## Or, to run on cluster for a long job with lots of gRNA scoring:
snakemake \
  --config java_memory=16g \
  --cores 1 \
  --jobs 50 \
  --cluster "sbatch -n 1 -c 1 --mem 16G -t 12:00:00 -p owners -J CRISPRDesigner_{rule} -o logs/{rule}_{wildcards} -e logs/{rule}_{wildcards}" &




## Split out design guides by locus
cat $PROJECT/01_ChooseRegions/ChosenGenes.Loci.bed | \
while read chr start end name score strand; do
  echo -e "${chr}\t${start}\t${end}" | \
    bedtools intersect -a $PROJECT/02_RunCRISPRDesigner/filteredGuides.all.bed -b stdin -g $SIZES > $PROJECT/02_RunCRISPRDesigner/filteredGuides.${name}.bed
  echo -e "chr\tstart\tend\tlocus\tscore\tstrand\tGuideSequenceWithPAM\tguideSet\tSSC" > $PROJECT/02_RunCRISPRDesigner/designGuides.${name}.bed
  cat $PROJECT/02_RunCRISPRDesigner/filteredGuides.${name}.bed | grep -v "TTTT" | awk '{ if ($5 > 50) print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $13 "\t" $14 "\t0" }' >> $PROJECT/02_RunCRISPRDesigner/designGuides.${name}.bed
done

## Add 4 guides from Philine 3/14/21 that worked in Perturb-seq but that are just outside the boundaries of this design
echo 'chr7:121037442-121037462:-
chr7:121037408-121037428:+
chr7:121170173-121170193:+
chr7:121185202-121185222:-' | cut -f 2 -d ":" | cut -f 1 -d "-" | while read line; do grep $line $OAK/Projects/CRISPRDesign/PoolDesign/190412.HyPR.LCL.Cohesin.Pools/191218.CohesinPilot/*.design.txt; done | \
  cut -f 1-6,8-10 | awk -v OFS=$'\t' '{ $7=$7 "NGG"; $8="PosControlAddition"; $9=0; print $0 }' > $PROJECT/01_WorkingGuides/PerturbSeq4GuidesManual.bed
cat $PROJECT/01_WorkingGuides/PerturbSeq4GuidesManual.bed >> $PROJECT/02_RunCRISPRDesigner/designGuides.WNT16.bed
cut -f 4 $PROJECT/01_WorkingGuides/PerturbSeq4GuidesManual.bed >> $PROJECT/01_WorkingGuides/Combined_sig_myc_guides.txt


#######################################################################################
## 03_Subpools

cat $PROJECT/01_ChooseRegions/ChosenGenes.Loci.bed | \
while read chr start end name score strand; do
  python $CODEDIR/src/MakeGuidePool.py \
      --PoolID 210213_CohesinFlowFISH_${name} \
      --input $PROJECT/02_RunCRISPRDesigner/designGuides.${name}.bed \
      --outdir $PROJECT/03_Subpools/ \
      --nCtrls 463 \
      --negCtrlList $CODEDIR/data/Weissman1000.negative_control.20bp.design.txt \
      --nGuidesPerElement 20 \
      --selectMethod even \
      --trimElements 5 \
      --vector sgOpti \
      --vectorDesigns $CODEDIR/data/CloningDesigns.txt \
      --forceGuides $PROJECT/01_WorkingGuides/Combined_sig_myc_guides.txt
done


######################################################################################
## 04_CombinePools
## First:  Edit CombinePoolsConfig.txt, and pull primer pairs from $CODEDIR/SubpoolPrimers.txt


## NOTE: WNT16 and FAM3C are adjacent, so I am including only WNT16 in the subpool config file

mkdir -p $PROJECT/04_CombinePools/

dos2unix -c mac $PROJECT/04_CombinePools/CombinePoolsConfig.txt
python $CODEDIR/src/CombineGuidePools.py \
    --config $PROJECT/04_CombinePools/CombinePoolsConfig.txt \
    --outbase $PROJECT/04_CombinePools/210311_CohesinFlowFISH  \
    > $PROJECT/04_CombinePools/210311_CohesinFlowFISH.out 

## Agilent array sizes: 7.5K, 15K, 60K, 100K, 244K




######### 
## Output FASTA file for mapping
sed 1d $PROJECT/04_CombinePools/210311_CohesinFlowFISH.full.txt | cut -f 4,9 | sort | uniq | \
  awk '{ print ">" $1 "\n" $2 }' > $PROJECT/04_CombinePools/210311_CohesinFlowFISH.mapping.fa


sed 1d $PROJECT/04_CombinePools/210211_IL2RA_PPIF.full.txt | cut -f 41,46,57 | sort | uniq | \
  awk '{ print $3 "-" $1 "\t" $2 }' > $PROJECT/04_CombinePools/210211_IL2RA_PPIF.mapping.txt


#########
## Output design file for Charlie's analysis script
echo "chr start	end name score strand GuideSequence GuideSequenceMinusG MappingSequence OffTargetScore target subpool OligoID" | tr ' ' '\t' > $PROJECT/04_CombinePools/210211_IL2RA_PPIF.customDesign.txt
sed 1d $PROJECT/04_CombinePools/210211_IL2RA_PPIF.full.txt | \
  awk '{ print $1 "\t" $2 "\t" $3 "\t" $4 "\t0\t" $9 "\t" $46 "\t" $46 "\t" $46 "\t0\t" $4 "\t" $53 "-" $57 "\t" $57 "-" $41 }' | sort | uniq >> $PROJECT/04_CombinePools/210211_IL2RA_PPIF.customDesign.txt


210311_CohesinFlowFISH.full.txt 
