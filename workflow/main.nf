params.read_triplets = "$projectDir/test_data/reads/reads_{1,2,3}*.gz"
params.outdir = "results"
params.cpus = 6
params.memory = 6.GB
params.time = 8.h

process UMI_INJECTOR {
    container '/proj/ngi2016004/nobackup/singularity/images/umi-injector:0.0.1--a87c3de712ca.sif'
    cpus params.cpus
    memory params.memory
    time params.time

    input:
    tuple val(sample_id), path(read_triplets)

    output:
    tuple val(sample_id), path('*_with_umi.fastq.gz')

    publishDir params.outdir
    script:
    def threads = Math.round(Math.floor(task.cpus / 5))
    """
        umi-injector.sh --in1=${read_triplets[0]} --umi=${read_triplets[1]}  --in2=${read_triplets[2]} \
            --out1=${sample_id}_R1_with_umi.fastq.gz --out2=${sample_id}_R2_with_umi.fastq.gz \
            --threads=$threads --sep=':'
    """
}


pattern = ~/(\w+)_R*[1-3](.*)\.(fastq|fq).gz$/

workflow {
    Channel
        .fromFilePairs(params.read_triplets, size: 3) { file -> def (_, first, second) = (file.name =~ pattern)[0]; return first+second }
        .set{ read_triplets_ch }
    UMI_INJECTOR(read_triplets_ch)
}
