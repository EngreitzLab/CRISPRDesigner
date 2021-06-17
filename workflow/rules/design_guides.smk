### Design and score gRNAs

import subprocess

rule combine_predesigned_guides:
	input:
		regions = [config["predesigned_guides"][guide_set]["regions"] for guide_set in config["predesigned_guides"]],
		genome_sizes = config["genome_sizes"]
	output:
		combined_regions = "results/GuideDesign/predesignedGuideRegions.bed"
	run:
		if len(input.regions) > 0:
			shell(f"cat {input.regions} | bedtools sort -i stdin -faidx {input.genome_sizes} > {output.combined_regions}")
		else:
			shell(f"touch {output.combined_regions}")


rule get_predesigned_guides:
	input:
		predesigned_guides = [config["predesigned_guides"][guide_set]["guides"] for guide_set in config["predesigned_guides"]],
		regions = config["regions"],
		genome_sizes = config["genome_sizes"]
	output:
		guides_in_regions = "results/GuideDesign/filteredGuides.predesigned.bed"
	run:
		if len(input.predesigned_guides) > 0:
			shell("""cat {input.predesigned_guides} | awk -v OFS=$'\t' '{{ $14="FILLER"; print $0 }}' | bedtools sort -i stdin -faidx {input.genome_sizes} | uniq | \
bedtools intersect -a stdin -b {input.regions} -wa -wb | cut -f 1-13,18 > {output.guides_in_regions}
""")
		else:
			shell(f"touch {output.guides_in_regions}")


rule subtract_predesigned_regions:
	input:
		predesigned = "results/GuideDesign/predesignedGuideRegions.bed",
		regions = config["regions"],
		genome_sizes = config["genome_sizes"]
	output:
		regions_minus_predesigned = "results/GuideDesign/newRegions.bed"
	shell:
		"bedtools slop -i {input.predesigned} -b -22 -g {input.genome_sizes} |"
		"bedtools sort -i stdin -faidx {input.genome_sizes} |"
		"bedtools subtract -a {input.regions} -b stdin -g {input.genome_sizes} >"
		"{output.regions_minus_predesigned}"



rule find_all_guides:
	## Find all NGG PAM guides in the selected regions
	input:
		regions = "results/GuideDesign/newRegions.bed",
		genome_fasta = config["genome_fasta"],
		off_target_bits = config["off_target_bits"]
	output:
		guides = "results/GuideDesign/allGuides.bed"
	params:
		mem = config["java_memory"]
	run:
		try:
			command = f"java -Xmx{params.mem} -jar workflow/scripts/CRISPRDesigner.jar \
TARGETS={input.regions} OUTPUT_DIR=results/GuideDesign/ \
GENOME_FASTA={input.genome_fasta} \
LENIENT=false \
OFF_TARGETS={input.off_target_bits} \
SKIP_PAIRING=true \
DIVIDE_AND_CONQUER=false \
SKIP_SCORING=true"
			print("Running: " + command)
			proc_output = subprocess.check_output(command, shell=True) 
		except subprocess.CalledProcessError as exc:
			if 'filteredGuides.bed' in exc.output:
				print("Snakemake caught Java Exception: Ignore this error, which is expected")
				pass
			else:
				raise
		# the Java script will throw an error when using SKIP_SCORING=true, even when everything works


checkpoint scatter_scores:
	input:
		guides = "results/GuideDesign/allGuides.bed"
	output:
		scatterdir = directory('results/GuideDesign/scatter')
	params:
		split_guides = config["split_guides"]
	shell:
		"""
		mkdir {output}
		split --lines={params.split_guides} -d {input.guides} {output}/guides.
		for file in {output}/guides.*; do 
		  mkdir -p {output}/dir-$(basename $file)
		  mv $file {output}/dir-$(basename $file)/allGuides.bed
		  mv {output}/dir-$(basename $file) $file
		done
		"""

rule score_guides:
	input:
		guide_scatter = 'results/GuideDesign/scatter/guides.{i}/',
		regions = config["regions"],
		genome_fasta = config["genome_fasta"],
		off_target_bits = config["off_target_bits"]
	output:
		scored = 'results/GuideDesign/scatter/guides.{i}/filteredGuides.bed'
	params:
		mem = config["java_memory"]
	shell:
		"java -Xmx{params.mem} -jar workflow/scripts/CRISPRDesigner.jar \
		  TARGETS={input.regions} \
		  OUTPUT_DIR={input.guide_scatter} \
		  GENOME_FASTA={input.genome_fasta} \
		  LENIENT=false \
		  OFF_TARGETS={input.off_target_bits} \
		  SKIP_PAIRING=true \
		  DIVIDE_AND_CONQUER=false \
		  SKIP_SCORING=false \
		  SKIP_GENERATION=true || true"	
		# SKIP_GENERATION=true means that the script will read a set of guides present in "OUTPUT_DIR/allGuides.bed"
		# SKIP_SCORING=false means that the script will conduct the off-targeting scoring calculation


def aggregate_input(wildcards):
	'''
	aggregate the file names of the files generated at the scatter step
	'''
	checkpoint_output = checkpoints.scatter_scores.get().output.scatterdir
	ivals = glob_wildcards(os.path.join(checkpoint_output, 'guides.{i}/allGuides.bed')).i
	#print("ivals={}".format(ivals))
	return expand('{dir}/guides.{i}/filteredGuides.bed', dir=checkpoint_output, i=ivals)


rule gather_guide_scores:
	input:
		aggregate_input
	output:
		combined = 'results/GuideDesign/filteredGuides.new.bed'
	shell:
		'''
		cat {input} > {output.combined}
		'''

rule combine_new_predesigned:
	input:
		newguides = 'results/GuideDesign/filteredGuides.new.bed',
		predesigned = 'results/GuideDesign/filteredGuides.predesigned.bed',
		genome_sizes = config["genome_sizes"]
	output:
		combinedGuides = 'results/GuideDesign/filteredGuides.bed'
	shell:
		"""
		cat {input.newguides} {input.predesigned} | bedtools sort -i stdin -faidx {input.genome_sizes} | uniq > {output.combinedGuides}
		"""

rule filter_guides:
	input:
		combined_guides = 'results/GuideDesign/filteredGuides.bed',
		genome_sizes = config["genome_sizes"]
	output:
		design_guides = 'results/GuideDesign/designGuides.txt',
		design_guides_igv = 'results/GuideDesign/designGuides.bed'
	shell:
		"""
		echo -e "chr\tstart\tend\tlocus\tscore\tstrand\tGuideSequenceWithPAM\tguideSet\tSSC" > {output.design_guides}
		cat {input.combined_guides} | grep -v "TTTT" | awk '{{if ($5 > 50) print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $13 "\t" $14 "\t0" }}' >> {output.design_guides}
		sed 1d {output.design_guides} | cut -f 1-6 | uniq > {output.design_guides_igv}
		"""
 