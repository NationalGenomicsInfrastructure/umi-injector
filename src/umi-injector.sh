#!/bin/bash

####################################################################################################
# umi-injector 0.0.1 
####################
# Ramshackle bash and awk script to integrate Unique Molecular Identifiers (UMIs)
# from a separate FastQ file into the header of another FastQ file.
#
# Temporary solution until our cooler and faster Rust project "umi-transfer"
# (https://github.com/SciLifeLab/umi-transfer) is mature enough to be used. 
####################################################################################################

version="0.0.1"



###### parse the options and their arguments #######################################################

arg_invalid() { echo -e "\x01\033[1;31m\x02 Error: $* \x01\033[0m\x02" >&2; exit 2; }  # print complain to stderr and exit with error
arg_required() { if [ -z "$OPTARG" ]; then arg_invalid "No argument was provided for the -$OPT option"; fi; }
arg_requirevalid() { if [[ ! -e "$OPTARG" ]] && [[ ! -L "$OPTARG" ]]; then arg_invalid "Argument to -$OPT option is not a valid file"; fi; }
arg_overwrite() { if [ -e "$OPTARG" ]; then arg_invalid " $OPTARG already exists! Please choose -$OPT differently"; fi; }
arg_numeric() { if [ ! -z ${OPTARG//[[:digit:]]/} ]; then arg_invalid "The argument to -$OPT needs to be numeric"; fi; }  #removes all digits; it wasn't numeric if something remains.
arg_dispensable() { if [ -n "$OPTARG" ]; then arg_invalid "No argument is allowed for the -$OPT option"; fi; }
paired() { if [[ -n "$in2" ]] || [[ -n "$out2" ]]; then paired=true; echo "in2 out2"; fi; } # If either pair option in set, they must have arguments as well. 
set_defaults() { verbose="${verbose:-false}"; log="${logger:-}"; threads="${threads:-1}"; sep="${sep:-:}"; }

# print help when -h or --help is invoked

help() { 
    echo -e "\n\n \x01\033[1;34m\x02 umi-injector $version \x01\033[0m\x02";
    echo -e "  integrates UMI sequences from a third FastQ file into the read names of paired FastQs.\n"
    strfmt="  \x01\033[0;100m\x02 %-15s \x01\033[0m\x02 %-37s \x01\033[2m\x02 %s \x01\033[0m\x02 \n"
    printf "${strfmt}" \
                "-h / --help"  "prints this help."  "" \
                "-v / --verbose"  "reports some statistics to stdout"   "${verbose}" \
                "-1 / --in1="  "path to a FastQ file with reads"   "${in1}" \
                "-2 / --in2="  "optional FastQ file with mates"   "${in2}" \
                "-3 / --out1=" "path to write the output to"   "${out1}" \
                "-4 / --out2=" "optional output for the mated reads"   "${out2}" \
                "-u / --umi=" "FastQ file with the matched UMIs"   "${umi}" \
                "-l / --log=" "optional path to logfile"   "${logger}" \
                "-n / --threads=" "PER FILE threads for (de)compression"   "${threads}" \
                "-s / --sep=" "separator between readname and UMI"   "${sep}" 
    echo -e "\n  Lycka till, ${USER}!"
    exit 0; }

# getops only supports parsing of one-letter options. To enable long options nonetheless, a generic
# "-" option is introduced. Getops will assume "-long" being the argument of the "-" option 
# if "--long" was provided and return "-long=argument" if "--long=argument" was submitted.

while getopts hv1:2:3:4:u:l:n:s:-: OPT
do
    if [ "$OPT" = "-" ]; then     # long option: manual parsing of the true arguments is required.
        OPT="${OPTARG%%=*}"       # extract the name of the long option.
        OPTARG="${OPTARG#$OPT}"   # get the long option argument (may be empty).
        OPTARG="${OPTARG#=}"      # remove an assigning `=` from a possible long option argument. 
    fi
    case "$OPT" in
        h | help )      set_defaults; help ;;
        v | verbose )   arg_dispensable; verbose=true ;;
        1 | in1 )       arg_required; arg_requirevalid; in1="$OPTARG" ;;
        2 | in2 )       arg_required; arg_requirevalid; in2="$OPTARG" ;;
        3 | out1 )      arg_required; arg_overwrite; out1="$OPTARG" ;;
        4 | out2 )      arg_required; arg_overwrite; out2="$OPTARG" ;;
        u | umi )       arg_required; arg_requirevalid; umi="$OPTARG" ;;
        l | log )       arg_required; logger="$OPTARG" ;;
        n | threads )   arg_required; arg_numeric; threads="$OPTARG" ;;
        s | sep )       arg_required; sep="$OPTARG" ;;
        ??* )           arg_invalid "Invalid option --$OPT" ;;  # bad long option. 
        ? )             exit 2 ;;  # bad short option (getopts will throw an error.)
    esac
done
shift $((OPTIND-1)) # remove what was already parsed from $@ list

# set default values for all arguments of optional options.
set_defaults 

# check that the required arguments to in1, out1 and umi have been provided
# if either --in2 or --out2 has been provided, set paired mode and include in check.

for arg in in1 out1 umi $(paired) ; do
    if [ -z "${!arg:-}" ] ; then
        missing+=", --$arg"
    fi
done
if [ -n "${missing}" ] ; then
    arg_invalid "${missing##,} must be provided!" #trim the first comma from missing
fi


###### handle both, compressed and uncompressed input & output #####################################

# quoting is necessary here: see https://stackoverflow.com/a/52538533 and https://www.vidarholen.net/contents/blog/?p=716

for input in ${in1} ${umi} ${in2}; do
    if [[ $(file "$input") == *"compressed"* ]]; then
        filehandles+=("pigz -cd -p ${threads} \"$input\"")
    else
        filehandles+=("cat \"$input\"")
    fi
done

for output in ${out1} ${out2}; do
    if [[ "$output" == *".gz" ]]; then
        outhandles+=("1") #set 1 for compressed output
    else
        outhandles+=("0") #set 0 for uncompressed output
    fi
done

###### process the files with awk and paste ########################################################

start=`date +%s`
if [[ -n "$in2" ]]; then

    # paired version

    paste <(eval ${filehandles[0]}) <(eval ${filehandles[1]}) <(eval ${filehandles[2]}) | paste - - - - | \
    awk -F "\t" -v in1="${in1}" -v out1="${out1}" -v out1h=${outhandles[0]} -v in2="${in2}" -v out2="${out2}" -v out2h=${outhandles[1]} -v threads="${threads}" -v version="$version" -v logger="$logger" \
    'BEGIN{OFS="\n"; \
    {if(out1h==0) output1=sprintf("tee > %s", out1); else output1=sprintf("pigz -p %d > %s", threads , out1)}; \
    {if(out2h==0) output2=sprintf("tee > %s", out2); else output2=sprintf("pigz -p %d > %s", threads , out2)}}; \
    match($1,/@[A-Z0-9:]+/) {headerold1=$1; headernew1=substr( $1, RSTART, RLENGTH )":"$5substr( $1, RSTART+RLENGTH )}{print headernew1,$4,"+",$10 | output1};
    match($3,/@[A-Z0-9:]+/) {headerold2=$3; headernew2=substr( $3, RSTART, RLENGTH )":"$5" 2"substr( $3, RSTART+RLENGTH+2)}{print headernew2,$6,"+",$12 | output2}; \
    END{if(logger!="") printf sprintf("{\n \"version\" : \"%s\",\n \"records\" : \"%s\",\n \"io_1\" : [\"%s\",\"%s\"],\n \"header_1\" : [\"%s\",\"%s\"],\n \"io_2\" : [\"%s\",\"%s\"],\n \"header_2\" : [\"%s\",\"%s\"]\n}",version,NR,in1,out1,headerold1,headernew1,in2,out2,headerold2,headernew2) >> logger }'

else

    # single file version

    paste <(eval ${filehandles[0]}) <(eval ${filehandles[1]}) | paste - - - - | \
    awk -F "\t" -v in1="${in1}" -v out1="${out1}" -v out1h=${outhandles[0]} -v threads="${threads}" -v version="$version" -v logger="$logger" \
    'BEGIN{OFS="\n"; \
    {if(out1h==0) output1=sprintf("tee > %s", out1); else output1=sprintf("pigz -p %d > %s", threads , out1)}}; \
    match($1,/@[A-Z0-9:]+/){headerold=$1;headernew=substr( $1, RSTART, RLENGTH )":"$4substr( $1, RSTART+RLENGTH)}{print headernew,$3,"+",$7 | output1}; \
    END{if(logger!="") printf sprintf("{\n \"version\" : \"%s\",\n \"records\" : \"%s\",\n \"io_1\" : [\"%s\",\"%s\"],\n \"header_1\" : [\"%s\",\"%s\"]\n}",version,NR,in1,out1,headerold,headernew) >> logger }'

fi
end=`date +%s`


if [[ "$verbose" = true ]]; then
    echo "umi-injector $version finished integrating ${umi} in $((end-start))s"
fi