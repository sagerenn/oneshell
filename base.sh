#!/bin/bash

global_setting(){

    local deps=( sshpass expect bash )
    for dep in ${deps[@]}
    do
        if ! ( whereis $dep | grep -q "/bin" )
        then
            echo -e "The $dep is missing! \nPlease check the deps: ${deps[@]}"
            exit 1
        fi
    done

    export present_time=`date +%Y%m%d%H%M%S%N`
    export field_separator='~~'
    export oneshell_dir=`oneshell_env`

    export oneshell_log=$(dirname `readlink -f $oneshell_dir`)/log/`date +%Y%m%d`
    export oneshell_result=$(dirname `readlink -f $oneshell_dir`)/result/`date +%Y%m%d`
    export oneshell_tool=$(dirname `readlink -f $oneshell_dir`)/tool
    export oneshell_raw=$(dirname `readlink -f $oneshell_dir`)/raw
    export oneshell_config=$(dirname `readlink -f $oneshell_dir`)/config
    source $oneshell_dir/libs/linux.sh

    mkdir -p $oneshell_log
    mkdir -p $oneshell_result
}

# check out the absolute path of oneshell
oneshell_env(){
    local temp_path=$(dirname `readlink -f $0`)

    until ls -d ${temp_path}/*/ 2>/dev/null | grep libs 2>&1 >/dev/null
    do
        temp_path=$(dirname "$temp_path")
        if [[ $temp_path == '/' ]]; then
            echo "Please make sure the path of this script is correct!"
            exit 1
        fi
    done
    echo $temp_path

}

oneshell_arg(){
    local custom_option=`$1`; shift 
    local input_script

    usage(){
        echo ""
        awk '{
            while(getline){
                if($0~/^#/ && $0!~/bin.*sh/){
                    gsub(/^#/,"",$0);
                    gsub(/^[ ]+/,"",$0);
                    printf "  "$0"\n";
                }else{
                    exit;
                }
            }
        }' $(readlink -f $0)
        echo ""
        echo ""
        echo "$input_script" | grep ')' | grep -E '^\s*\-' | \
        grep -E "[a-zA-Z0-9]" | awk -F '#' '{ printf "%-30s %s\n", $1, $2 }'
        echo ""

    }

input_script=$(
cat << EOF
if [ \$# -eq 0 ]
then
    interact
else
    while true
    do
    case "\$1" in
        $custom_option
        --debug) # open the debug mode
            debug=yes
            shift
            ;;
        -h|--help) # print the help
            usage
            exit
            ;;
        -*|--*)
            echo "invalid option '\$1'" >&2
            exit 1
            ;;
        *)
            if [ -z \$1 ]
            then
            break
            else
            usage
            exit 1
            fi
            ;;
    esac
    done
fi
EOF
)


    source <(echo "$input_script") "$@"

    if [ "$debug" = "yes" ] 
    then
    log_file=$oneshell_log/${present_time}_$(basename $0).log
    else
    log_file=/dev/null
    fi

}

global_setting

