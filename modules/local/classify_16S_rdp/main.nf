process CLASSIFY_16S_RDP {

    tag { "${meta.id}-${meta.assembler}" }
    container "tpaisie/rdp@sha256:ee388dff2e17c567946b7f2bf326765586d30f4ea0a203800616c44f599d53cc"

    input:
    tuple val(meta), path(assembly)

    output:
    path("${meta.id}-${meta.assembler}.16S_RDP.tsv"), emit: summary_16S_rdp
    path(".command.{out,err}")
    path("versions.yml")                                 , emit: versions

    shell:
    '''
    source bash_functions.sh

    # RDP Classifier on 16S
    msg "INFO: Running RDP Classifier"

    if [[ -s !{assembly} ]]; then
      classifier classify \
        -o "!{meta.id}-!{meta.assembler}.16S_RDP.tsv" \
        16S.${meta.id}-${meta.assembler}.fa

      sed -i \
        '1i Filename\tPubMLST scheme name\tSequence type\tAllele IDs' \
        "!{meta.id}-!{meta.assembler}.16S_RDP.tsv"
    fi


    # Get process version information
    cat <<-END_VERSIONS > versions.yml
    "!{task.process}":
        rdp: $(classifier --version | awk '{print $2}')
    END_VERSIONS
    '''
}