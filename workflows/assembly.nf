/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowAssembly.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.kraken1_db, params.kraken2_db, params.blast_db, params.gtdb_db, params.busco_db ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet or directory not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// CONFIGS: Import configs for this workflow
//

// BUSCO config
if(params.busco_config){
    ch_busco_config_file = Channel.fromPath( "${params.busco_config}" )
} else {
    ch_busco_config_file = []
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULES: Local modules
//
include { INFILE_HANDLING_UNIX                                } from "../modules/local/infile_handling_unix/main"

include { REMOVE_PHIX_BBDUK                                   } from "../modules/local/remove_phix_bbduk/main"
include { TRIM_READS_TRIMMOMATIC                              } from "../modules/local/trim_reads_trimmomatic/main"
//include { TRIM_READS_FASTP                                  } from "../modules/local/trim_reads_fastp/main"
include { OVERLAP_PAIRED_READS_FLASH                          } from "../modules/local/overlap_paired_reads_flash/main"
//include { OVERLAP_PAIRED_READS_PEAR                         } from "../modules/local/overlap_paired_reads_pear/main"

include { KRAKEN1_DB_PREPARATION_UNIX                         } from "../modules/local/kraken1_db_preparation_unix/main"
include { READ_CLASSIFY_KRAKEN_ONE                            } from "../modules/local/read_classify_kraken/main"
include { KRAKEN2_DB_PREPARATION_UNIX                         } from "../modules/local/kraken2_db_preparation_unix/main"
include { READ_CLASSIFY_KRAKEN_TWO                            } from "../modules/local/read_classify_kraken2/main"
//include { READ_CLASSIFY_CENTRIFUGE                          } from "../modules/local/read_classify_centrifuge/main"

include { EXTRACT_READ_ALIGNMENT_DEPTHS_BEDTOOLS              } from "../modules/local/extract_read_alignment_depths_bedtools/main"
include { CALCULATE_COVERAGE_UNIX                             } from "../modules/local/calculate_coverage_unix/main"

include { MLST_MLST                                           } from "../modules/local/mlst_mlst/main"
//include { MLST_SRST2                                        } from "../modules/local/mlst_srst2/main"

include { ANNOTATE_PROKKA                                     } from "../modules/local/annotate_prokka/main"
//include { ANNOTATE_BACTA                                    } from "../modules/local/annotate_bacta/main"

include { EXTRACT_16S_BIOPYTHON                               } from "../modules/local/extract_16S_biopython/main"
include { EXTRACT_16S_BARRNAP                                 } from "../modules/local/extract_16S_barrnap/main"
//include { 16S_EXTRACT_RNAMMER                               } from "../modules/local/16S_extract_rnammer/main"
include { BLAST_DB_PREPARATION_UNIX                           } from "../modules/local/blast_db_preparation_unix/main"
include { ALIGN_16S_BLAST                                     } from "../modules/local/align_16S_blast/main"
include { BEST_16S_BLASTN_BITSCORE_TAXON_PYTHON               } from "../modules/local/best_16S_blastn_bitscore_taxon_python/main"
include { SPLIT_MULTIFASTA_ASSEMBLY_BIOPYTHON                 } from "../modules/local/split_multifasta_assembly_biopython/main"

include { GTDBTK_DB_PREPARATION_UNIX                          } from "../modules/local/gtdbtk_db_preparation_unix/main"
include { GTDBTK_CLASSIFYWF as QA_ASSEMBLY_GTDBTK             } from "../modules/nf-core/gtdbtk/classifywf/main"
include { BUSCO_DB_PREPARATION_UNIX                           } from "../modules/local/busco_db_preparation_unix/main"
include { BUSCO as QA_ASSEMBLY_BUSCO                          } from "../modules/nf-core/busco/main"
include { QA_ASSEMBLY_QUAST                                   } from "../modules/local/qa_assembly_quast/main"
//include { QA_ASSEMBLY_CAT                                   } from "../modules/local/qa_assembly_cat/main"
//include { QA_ASSEMBLY_CHECKM2                               } from "../modules/local/qa_assembly_checkm2/main"

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK                                         } from "../subworkflows/local/input_check"
include { DOWNSAMPLE                                          } from "../subworkflows/local/downsampling"
include { ASSEMBLE_CONTIGS                                    } from "../subworkflows/local/assemble_contigs"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CREATE CHANNELS FOR INPUT FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// PhiX Reference
if (params.phix_reference) {
    ch_phix_reference = Channel
                            .fromPath(params.phix_reference, checkIfExists: true)
                            .map{
                                file ->
                                    if ( file.extension in ['fasta', 'fas', 'fa', 'fna'] ) {
                                        [ file ]
                                    } else {
                                        error("PhiX reference file not in supported extension: .fasta, .fas, .fa, .fna")
                                    }
                            }
} else {
    error("Path to PhiX reference not specified. Please supply a PhiX reference file in FastA format via `--phix_reference` parameter.")
}

// Adapter Reference
if (params.adapter_reference) {
    ch_adapter_reference = Channel
                            .fromPath(params.adapter_reference, checkIfExists: true)
                            .map{
                                file ->
                                    if ( file.extension in ['fasta', 'fas', 'fa', 'fna'] ) {
                                        [ file ]
                                    } else {
                                        error("Adapter reference file not in supported extension: .fasta, .fas, .fa, .fna")
                                    }
                            }
} else {
    error("Path to Adapter reference not specified. Please supply an adapter reference file in FastA format via `--adapter_reference` parameter.")
}

// GTDB
if (params.gtdb_db) {
    ch_gtdbtk_db_file = file(params.gtdb_db, checkIfExists: true)
} else {
    ch_gtdbtk_db_file = Channel.empty()
}

// BUSCO
if (params.busco_db) {
    ch_busco_db_file = file(params.busco_db, checkIfExists: true)
} else {
    ch_busco_db_file = Channel.empty()
}

// kraken
if (params.kraken1_db) {
    ch_kraken1_db_file = file(params.kraken1_db, checkIfExists: true)
} else {
    ch_kraken1_db_file = Channel.empty()
}

// kraken2
if (params.kraken2_db) {
    ch_kraken2_db_file = file(params.kraken2_db, checkIfExists: true)
} else {
    ch_kraken2_db_file = Channel.empty()
}

// NCBI BLAST
if (params.blast_db) {
    ch_blast_db_file = file(params.blast_db, checkIfExists: true)
} else {
    ch_blast_db_file = Channel.empty()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ASSEMBLY {

    // SETUP: Define empty channels to concatenate certain outputs
    ch_versions             = Channel.empty()
    ch_ssu_species          = Channel.empty()
    ch_mlst_summary         = Channel.empty()
    ch_qc_filecheck         = Channel.empty()
    ch_blast_summary        = Channel.empty()
    ch_cleaned_summary      = Channel.empty()
    ch_alnstats_summary     = Channel.empty()
    ch_assembly_summary     = Channel.empty()
    ch_genome_cov_summary   = Channel.empty()
    ch_phix_removal_summary = Channel.empty()

    /*
    ================================================================================
                            Preprocessing and Cleaning FastQ files
    ================================================================================
    */

    // SUBWORKFLOW: Check input for samplesheet or pull inputs from directory
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    // Check input files meet size criteria
    INFILE_HANDLING_UNIX (
        INPUT_CHECK.out.raw_reads
    )
    ch_versions = ch_versions.mix(INFILE_HANDLING_UNIX.out.versions)

    // SUBWORKFLOW: Downsample FastQ files
    DOWNSAMPLE (
        INFILE_HANDLING_UNIX.out.input
    )
    ch_versions = ch_versions.mix(DOWNSAMPLE.out.versions)

    // PROCESS: Run bbduk to remove PhiX reads
    REMOVE_PHIX_BBDUK (
        DOWNSAMPLE.out.reads,
        ch_phix_reference
    )
    ch_versions = ch_versions.mix(REMOVE_PHIX_BBDUK.out.versions)

    ch_phix_removal_summary = ch_phix_removal_summary
                                .mix(REMOVE_PHIX_BBDUK.out.phix_summary)
                                .collectFile(
                                    name:       "Summary.PhiX_removal.tab",
                                    keepHeader: true,
                                    storeDir:   "${params.outdir}/qa"
                                )

    // PROCESS: Run trimmomatic to clip adapters and do quality trimming
    TRIM_READS_TRIMMOMATIC (
        REMOVE_PHIX_BBDUK.out.phix_removed,
        ch_adapter_reference
    )
    ch_versions = ch_versions.mix(TRIM_READS_TRIMMOMATIC.out.versions)

    // PROCESS: Run flash to merge overlapping sister reads into singleton reads
    OVERLAP_PAIRED_READS_FLASH (
        TRIM_READS_TRIMMOMATIC.out.trimmo
    )
    ch_versions = ch_versions.mix(OVERLAP_PAIRED_READS_FLASH.out.versions)

    /*
    ================================================================================
                                    Taxonomic information
    ================================================================================
    */

    // Prepare kraken1 database for use
    if ( ch_kraken1_db_file ) {
        if ( ch_kraken1_db_file.extension in ['gz', 'tgz'] ) {
            // Expects to be .tar.gz!
            KRAKEN1_DB_PREPARATION_UNIX (
                ch_kraken1_db_file
            )
            ch_versions = ch_versions.mix(KRAKEN1_DB_PREPARATION_UNIX.out.versions)

            ch_db_for_kraken1 = KRAKEN1_DB_PREPARATION_UNIX.out.db

        } else if ( ch_kraken1_db_file.isDirectory() ) {
            ch_db_for_kraken1 = Channel
                                    .fromPath(
                                        "${ch_kraken1_db_file}/{database}.{idx,kdb}",
                                        checkIfExists: true
                                    )
                                    .combine(
                                        Channel
                                            .fromPath(
                                                "${ch_kraken1_db_file}/taxonomy/{names,nodes}.dmp",
                                                checkIfExists: true
                                            )
                                    )
                                    .collect()
                                    .map{
                                        file ->
                                            if (file.size() >= 4) {
                                                [ file[0].getParent() ]
                                            } else {
                                                error("Kraken requires 'database.{idx,kdb}' and 'taxonomy/{names,nodes}.dmp' files!")
                                            }
                                        }
        } else {
            error("Unsupported object given to --kraken1_db, database must be supplied as either a directory or a .tar.gz file!")
        }
    } else {
        ch_db_for_kraken1 = Channel.empty()
    }

    // PROCESS: Run kraken1 on paired cleaned reads
    READ_CLASSIFY_KRAKEN_ONE (
        OVERLAP_PAIRED_READS_FLASH.out.gzip_reads,
        ch_db_for_kraken1
    )
    ch_versions = ch_versions.mix(READ_CLASSIFY_KRAKEN_ONE.out.versions)

    // Prepare kraken2 database for use
    if ( ch_kraken2_db_file ) {
        if ( ch_kraken2_db_file.extension in ['gz', 'tgz'] ) {
            // Expects to be .tar.gz!
            KRAKEN2_DB_PREPARATION_UNIX (
                ch_kraken2_db_file
            )
            ch_versions = ch_versions.mix(KRAKEN2_DB_PREPARATION_UNIX.out.versions)

            ch_db_for_kraken2 = KRAKEN2_DB_PREPARATION_UNIX.out.db

        } else if ( ch_kraken2_db_file.isDirectory() ) {
            ch_db_for_kraken2 = Channel
                                    .fromPath( "${ch_kraken2_db_file}/*.k2d" )
                                    .collect()
                                    .map{
                                        file ->
                                            if (file.size() >= 3) {
                                                [ file[0].getParent() ]
                                            } else {
                                                error("Kraken2 requires '{hash,opts,taxo}.k2d' files!")
                                            }
                                    }
        } else {
            error("Unsupported object given to --kraken2_db, database must be supplied as either a directory or a .tar.gz file!")
        }
    } else {
        ch_db_for_kraken2 = Channel.empty()
    }

    // PROCESS: Run kraken2 on paired cleaned reads
    READ_CLASSIFY_KRAKEN_TWO (
        OVERLAP_PAIRED_READS_FLASH.out.gzip_reads,
        ch_db_for_kraken2
    )
    ch_versions = ch_versions.mix(READ_CLASSIFY_KRAKEN_TWO.out.versions)

    /*
    ================================================================================
                                    Assembly
    ================================================================================
    */

    ASSEMBLE_CONTIGS (
        OVERLAP_PAIRED_READS_FLASH.out.gzip_reads
    )
    ch_versions = ch_versions.mix(ASSEMBLE_CONTIGS.out.versions)

    /*
    ================================================================================
                            Assembly Information
    ================================================================================
    */

    // PROCESS: Run Bedtools to extract coverage from the pre-computed BAM alignment file
    EXTRACT_READ_ALIGNMENT_DEPTHS_BEDTOOLS (
        ASSEMBLE_CONTIGS.out.bam
    )
    ch_versions = ch_versions.mix(EXTRACT_READ_ALIGNMENT_DEPTHS_BEDTOOLS.out.versions)

    // Collect all Summary Stats and concatenate into one file
    ch_alnstats_summary = ch_alnstats_summary
                            .mix(EXTRACT_READ_ALIGNMENT_DEPTHS_BEDTOOLS.out.summary_alnstats)
                            .collectFile(
                                name:     "Summary.Illumina.CleanedReads-AlnStats.tab",
                                keepHeader: true,
                                storeDir: "${params.outdir}/qa"
                            )

    // PROCESS: Run MLST to find MLST for each polished assembly
    MLST_MLST (
        ASSEMBLE_CONTIGS.out.bam
            .join(ASSEMBLE_CONTIGS.out.assembly)
    )
    ch_versions = ch_versions.mix(MLST_MLST.out.versions)

    // Collect all MLST Summaries and concatenate into one file
    ch_mlst_summary = ch_mlst_summary
                        .mix(MLST_MLST.out.summary_mlst)
                        .collectFile(
                            name:     "Summary.MLST.tab",
                            storeDir: "${params.outdir}/qa"
                        )

    // PROCESS: Annotate the polished assembly using Prokka
    ANNOTATE_PROKKA (
        ASSEMBLE_CONTIGS.out.bam
            .join(ASSEMBLE_CONTIGS.out.assembly)
    )
    ch_versions = ch_versions.mix(ANNOTATE_PROKKA.out.versions)

    /*
    ================================================================================
                            Evaluate 16S
    ================================================================================
    */

    // PROCESS: Attempt to extract 16S rRNA gene records from annotation file
    EXTRACT_16S_BIOPYTHON (
        ANNOTATE_PROKKA.out.annotation
            .join(ASSEMBLE_CONTIGS.out.assembly)
    )
    ch_versions = ch_versions.mix(EXTRACT_16S_BIOPYTHON.out.versions)

    // PROCESS: Extract 16S rRNA gene sequences with Barrnap if missing from 16S_EXTRACT_BIOPYTHON
    EXTRACT_16S_BARRNAP (
        ANNOTATE_PROKKA.out.annotation
            .join(ASSEMBLE_CONTIGS.out.assembly)
            .join(EXTRACT_16S_BIOPYTHON.out.extracted_rna)
    )
    ch_versions = ch_versions.mix(EXTRACT_16S_BARRNAP.out.versions)

    // Prepare BLAST database for use
    if ( ch_blast_db_file ) {
        if ( ch_blast_db_file.extension in ['gz', 'tgz'] ) {
            // Expects to be .tar.gz!
            BLAST_DB_PREPARATION_UNIX (
                ch_blast_db_file
            )
            ch_versions = ch_versions.mix(BLAST_DB_PREPARATION_UNIX.out.versions)

            ch_db_for_blast = BLAST_DB_PREPARATION_UNIX.out.db
                                .map{
                                    file ->
                                        [ file[0].toString().split(".${file[0].getExtension()}") ]
                                }
                                .flatten()

        } else if ( ch_blast_db_file.isDirectory() ) {
            ch_db_for_blast = Channel
                                    .fromPath( "${ch_blast_db_file}/16S_ribosomal_RNA.n*" )
                                    .collect()
                                    .map{
                                        file ->
                                            if (file.size() >= 3) {
                                                [ file[0].toString().split(".${file[0].getExtension()}") ]
                                            } else {
                                                error("16S_ribosomal_RNA BLAST database requires at least '16S_ribosomal_RNA.{nin,nsq,nhr}' files.")
                                            }
                                    }
                                    .flatten()
        } else {
            error("Unsupported object given to --blast_db, database must be supplied as either a directory or a .tar.gz file!")
        }
    } else {
        ch_db_for_blast = Channel.empty()
    }

    // PROCESS: Run Blast on predicted 16S ribosomal RNA genes
    ALIGN_16S_BLAST (
        EXTRACT_16S_BARRNAP.out.extracted_base
            .join(ASSEMBLE_CONTIGS.out.assembly),
        ch_db_for_blast
    )
    ch_versions = ch_versions.mix(ALIGN_16S_BLAST.out.versions)

    // PROCESS: Filter Blast output for best alignment, based on bitscore
    BEST_16S_BLASTN_BITSCORE_TAXON_PYTHON (
        ALIGN_16S_BLAST.out.blast_tsv
            .join(ASSEMBLE_CONTIGS.out.assembly)
    )
    ch_versions = ch_versions.mix(BEST_16S_BLASTN_BITSCORE_TAXON_PYTHON.out.versions)

    // Collect all BLAST Summaries and concatenate into one file
    ch_blast_summary = ch_blast_summary
                        .mix(BEST_16S_BLASTN_BITSCORE_TAXON_PYTHON.out.blast_summary)
                        .collectFile(
                            name:     "Summary.16S.tab",
                            storeDir: "${params.outdir}/qa"
                        )

    // Collect all BLAST Top Species Summaries and concatenate into one file
    ch_ssu_species = ch_ssu_species
                        .mix(BEST_16S_BLASTN_BITSCORE_TAXON_PYTHON.out.ssu_species)
                        .collectFile(
                            name:     "16S-top-species.tsv",
                            storeDir: "${params.outdir}/ssu"
                        )

    /*
    ================================================================================
                            Evaluate contigs
    ================================================================================
    */

    /*
     * QUAST: Genome assembly evaluation tool
     */

    // PROCESS: Run QUAST on the polished assembly for quality assessment and
    //  report the number of cleaned basepairs used to form the assembly
    QA_ASSEMBLY_QUAST (
        OVERLAP_PAIRED_READS_FLASH.out.gzip_reads
            .join(ASSEMBLE_CONTIGS.out.assembly)
    )
    ch_versions = ch_versions.mix(QA_ASSEMBLY_QUAST.out.versions)

    // Collect all Assembly Summaries and concatenate into one file
    ch_assembly_summary = ch_assembly_summary
                            .mix(QA_ASSEMBLY_QUAST.out.summary_assemblies)
                            .collectFile(
                                name:       "Summary.Assemblies.tab",
                                keepHeader: true,
                                storeDir:   "${params.outdir}/qa"
                            )

    // Collect all Cleaned Read/Base Summaries and concatenate into one file
    ch_cleaned_summary = ch_cleaned_summary
                            .mix(QA_ASSEMBLY_QUAST.out.summary_reads)
                            .collectFile(
                                name:     "Summary.Illumina.CleanedReads-Bases.tab",
                                storeDir: "${params.outdir}/qa"
                            )

    // PROCESS: Calculate genome assembly depth of coverage
    CALCULATE_COVERAGE_UNIX (
        QA_ASSEMBLY_QUAST.out.qa_summaries
            .join(EXTRACT_READ_ALIGNMENT_DEPTHS_BEDTOOLS.out.summary_stats)
    )
    ch_versions = ch_versions.mix(CALCULATE_COVERAGE_UNIX.out.versions)

    // Collect all Genome Coverage Summaries and concatenate into one file
    ch_genome_cov_summary = ch_genome_cov_summary
                                .mix(CALCULATE_COVERAGE_UNIX.out.genome_coverage)
                                .collectFile(
                                    name:     "Summary.Illumina.GenomeCoverage.tab",
                                    storeDir: "${params.outdir}/qa"
                                )

    /*
     * GTDB-Tk: taxonomic classification using a GTDB reference
     */

    // PROCESS: Classify assembly FastA file using GTDB-Tk
    if (!params.skip_gtdbtk && params.gtdb_db) {
        ch_contigs = ASSEMBLE_CONTIGS.out.assembly
                        .map {
                            meta, bins ->
                                def meta_new = meta.clone()
                                meta_new['assembler'] = "${params.assembler}"
                                [ meta_new, bins ]
                        }

        if ( ch_gtdbtk_db_file.extension in ['gz', 'tgz'] ) {
            // Expects to be .tar.gz!
            GTDBTK_DB_PREPARATION_UNIX (
                ch_gtdbtk_db_file
            )
            ch_versions = ch_versions.mix(GTDBTK_DB_PREPARATION_UNIX.out.versions)

            ch_db_for_gtdbtk = GTDBTK_DB_PREPARATION_UNIX.out.db

        } else if ( ch_gtdbtk_db_file.isDirectory() ) {
            ch_db_for_gtdbtk = Channel
                                .fromPath( "${ch_gtdbtk_db_file}/*", type: 'dir', maxDepth: 1 )
                                .collect()
                                .map{
                                    [ it[0].getSimpleName(), it ]
                                }
        } else {
            error("Unsupported object given to --gtdb_db, database must be supplied as either a directory or a .tar.gz file!")
        }

        // PROCESS: Perform GTDBTk on assembly FastA file
        QA_ASSEMBLY_GTDBTK (
            ch_contigs,
            ch_db_for_gtdbtk
        )
        ch_versions = ch_versions.mix(QA_ASSEMBLY_GTDBTK.out.versions)
    }

    /*
     * BUSCO: predict genes on contigs
     */

    // PROCESS: Classify contigs with BUSCO
    if (!params.skip_busco && params.busco_db) {
        if ( ch_busco_db_file.extension in ['gz', 'tgz'] ) {
            // Expects to be tar.gz!
            BUSCO_DB_PREPARATION_UNIX(
                ch_busco_db_file
            )
            ch_versions = ch_versions.mix(BUSCO_DB_PREPARATION_UNIX.out.versions)

            ch_db_for_busco = BUSCO_DB_PREPARATION_UNIX.out.db

        } else if ( ch_busco_db_file.isDirectory() ) {
            // Expects directory in <database>/lineages/<lineage>_odb10 format!
            ch_db_for_busco = Channel
                                .fromPath(ch_busco_db_file)
                                .map{
                                    db ->
                                        if ( db.getSimpleName().contains('odb10') ) {
                                            if ( db.getParent().getSimpleName() == "lineages" ) {
                                                db.getParent().getParent()
                                            } else {
                                                error("Unsupported object given to --busco_db, database directory must be in format `<database>/lineages/<lineage>_odb10`!")
                                            }
                                        } else {
                                            db
                                        }
                                }
        } else {
            error("Unsupported object given to --busco_db, database must be supplied as either a directory or a .tar.gz file!")
        }

        ch_lineage_for_busco_db = Channel
                                    .of(ch_busco_db_file)
                                    .map{
                                        db ->
                                            db = db.getSimpleName()
                                            db.contains('odb10') ? db : 'auto'
                                    }

        // PROCESS: Split assembly FastA file into individual contig files
        SPLIT_MULTIFASTA_ASSEMBLY_BIOPYTHON (
            ASSEMBLE_CONTIGS.out.assembly
        )
        ch_versions = ch_versions.mix(SPLIT_MULTIFASTA_ASSEMBLY_BIOPYTHON.out.versions)

        // PROCESS: Perform BUSCO analysis on contigs
        QA_ASSEMBLY_BUSCO (
            SPLIT_MULTIFASTA_ASSEMBLY_BIOPYTHON.out.split_multifasta_assembly_dir,
            ch_lineage_for_busco_db,
            ch_db_for_busco,
            ch_busco_config_file
        )
        ch_versions = ch_versions.mix(QA_ASSEMBLY_BUSCO.out.versions)
    }

    /*
    ================================================================================
                        Collect version and QC information
    ================================================================================
    */

    // PATTERN: Collate method for version information
    ch_versions
        .unique()
        .collectFile(
            name:     "software_versions.yml",
            storeDir: params.logpath
        )

    // Collect all QC File Checks and concatenate into one file
    ch_qc_filecheck = ch_qc_filecheck
        .concat(
            INFILE_HANDLING_UNIX.out.qc_input_filecheck,
            REMOVE_PHIX_BBDUK.out.qc_phix_genome_filecheck,
            REMOVE_PHIX_BBDUK.out.qc_phix_removed_filecheck,
            TRIM_READS_TRIMMOMATIC.out.qc_adapters_filecheck,
            TRIM_READS_TRIMMOMATIC.out.qc_removed_adapters_filecheck,
            OVERLAP_PAIRED_READS_FLASH.out.qc_nonoverlap_filecheck,
            ASSEMBLE_CONTIGS.out.qc_filechecks,
            ANNOTATE_PROKKA.out.qc_annotated_filecheck,
            EXTRACT_16S_BARRNAP.out.qc_ssu_extracted_filecheck,
            EXTRACT_16S_BARRNAP.out.qc_ssu_renamed_filecheck,
            ALIGN_16S_BLAST.out.qc_blastn_filecheck,
            BEST_16S_BLASTN_BITSCORE_TAXON_PYTHON.out.qc_filtered_blastn_filecheck
        )
        .collectFile(
            name:     "Summary.QC_File_Checks.tab",
            storeDir: "${params.outdir}/qa",
            sort:     { it.getSimpleName() }
        )

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
