params.read_triplets = "$projectDir/test_data/reads/reads_{1,2,3}*.gz"
params.outdir = "results"

process UMI_INJECTOR {
    container 'umi-injector'
    cpus 2

    input:
    tuple val(sample_id), path(read_triplets)

    output:
    tuple val(sample_id), path('*_with_umi.fastq.gz')

    publishDir params.outdir
    script:
    """
        umi-injector.sh --in1 ${read_triplets[0]} --umi ${read_triplets[1]}  --in2 ${read_triplets[2]} \
            --out1 ${sample_id}_R1_with_umi.fastq.gz --out2 ${sample_id}_R2_with_umi.fastq.gz \
            --threads ${task.cpus} --sep ':'
    """
}


pattern = ~/(\w+)_R*[1-3]\.(fastq|fq).gz$/

workflow {
    Channel.fromPath(params.read_triplets).view()
    Channel
        .fromFilePairs(params.read_triplets, size: 3) { file -> (file.name =~ pattern)[0][1] }
        .set{ read_triplets_ch }
    UMI_INJECTOR(read_triplets_ch)
}