configfile: "misc/masterconfig.yaml"

sample_ids, = glob_wildcards(config['raw_reads_path']+"/{sample}.R1.fastq.gz")

#print(sample_ids)
prefix = config['prefix']

logs = config['base_log_outdir']

if config['input_type'] ==  "raw_reads":
    assembly_path = config['outdir']+"/"+config['prefix']+"/shovill/assemblies"
else:
    assembly_path = config['assembly_path']

#rule all:
#    input:
#        expand(config['outdir']+"/{prefix}/shovill/shovill_out/{sample}.out", sample=sample_ids, prefix=prefix),
#        expand(config['outdir']+"/{prefix}/shovill/assemblies/{sample}.fasta", sample=sample_ids, prefix=prefix),
#        expand(config['outdir']+"/{prefix}/shovill/assembly_stats/{sample}_assembly_stats.txt", sample=sample_ids, prefix=prefix),
#        #expand(config['outdir']+"/{prefix}/summaries/assembly_stats.txt", prefix=prefix)


rule run_shovill:
    input:
        r1_filt = config['outdir']+"/{prefix}/fastp/{sample}.R1.fastq.gz",
        r2_filt = config['outdir']+"/{prefix}/fastp/{sample}.R2.fastq.gz"
    output:
        shov_out = directory(config['outdir']+"/{prefix}/shovill/shovill_out/{sample}.out"),
        assembly = config['outdir']+"/{prefix}/shovill/assemblies/{sample}.fasta"
    log:
        config['base_log_outdir']+"/{prefix}/shovill/run/{sample}.log"
    threads:
        4
    conda:
        "config/shovill.yaml"
    shell:
        """
        shovill --minlen 200 --outdir {output.shov_out} --R1 {input.r1_filt} --R2 {input.r2_filt}
        cp {output.shov_out}/contigs.fa {output.assembly}
        """

rule run_assembly_stats:
    input:
        config['outdir']+"/{prefix}/shovill/shovill_out/{sample}.out"
    output:
        config['outdir']+"/{prefix}/shovill/assembly_stats/{sample}_assembly_stats.txt"
    conda:
        "config/assembly_stats.yaml"
    shell:
        "assembly-stats -t {input}/contigs.fa > {output}"

rule combine_assembly_stats:
    input:
        expand(config['outdir']+"/{prefix}/shovill/assembly_stats/{sample}_assembly_stats.txt", sample=sample_ids, prefix=prefix)
    output:
        stats_temp = temp(config['outdir']+"/{prefix}/summaries/temp_assembly_stats.txt")
    shell:
        """
        cat {input} > {output}
        """

rule clean_assembly_stats:
    input:
        stats_temp = config['outdir']+"/{prefix}/summaries/temp_assembly_stats.txt",
    output:
        stats = config['outdir']+"/{prefix}/summaries/assembly_stats.txt"
    shell:
        """
        # Cleans file names
        perl -p -i -e 's@.*shovill_out/@@g' {input}
        perl -p -i -e 's@.out/contigs.fa@@g' {input}
        # Changes column name to name rather than filename
        perl -p -i -e 's@^filename@name@g' {input}
        #Removes duplicate headers (in this case lines starting with filename)
        awk 'FNR==1 {{ header = $0; print }} $0 != header' {input} > {output}
        """

#include: "read_cleaning.smk"