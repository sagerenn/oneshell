#!/bin/bash
# This script is used for test the function in the local.
# maintained by Sage Ren

interact(){
    echo "test"
}

custom_option(){
    local shell_option='
        -lib|--library) # the library need to be imported for the method
            [ "$2" ] && import_library=$2 && shift
            shift
            ;;
        -m|--method) # the function need to run
            [ "$2" ] && running_method=$2 && shift
            shift
            ;;
        -o|--option) # the options for the running method
            [ "$2" ] && running_optional="$2" && shift
            shift
            ;;
        -cmd|--command) # the simple command to test the method
            [ "$2" ] && running_command="$2" && shift
            shift
            ;;
        -dr|--dry-run) # get the info of method/library
            dry_run=yes
            shift
            ;;
    '

    echo "$shell_option"
}


check_variable(){
    if [[ ! "$import_library" ]] || ! (cat ${import_library[@]} | grep -q $running_method)
    then
        import_libs=($(find $oneshell_dir -name "*.sh" | \
        xargs -I @@ grep -HE "^\s*$running_method\s*\(\s*\)\s*\{\s*$" @@ | awk -F ':' '{print $1}' | xargs -I @@ readlink -f @@))
        case ${#import_libs[@]} in
            0) echo "The method is undefine!" && exit 1 ;;
            1) check_function_script ${import_libs[@]} || ( echo "The ${import_libs[@]} has other normal commands besides functions!" && exit 1 ) ;;
            *) echo "The method is repeat in ${import_libs[@]}!" && exit 1 ;;
        esac
    fi

    import_library=( ${import_library[@]} ${import_libs[@]} )

    for library in ${import_library[@]}
    do
    source ${library}
    done

    if [[ $(declare -f $running_method | wc -l) -eq 0 ]]
    then
        echo "Please enter the correct method need to run!"
        exit 1
    fi

}

source $(dirname `readlink -f $0`)/base.sh
oneshell_arg custom_option "$@"

check_variable


if [[ $dry_run == "yes" ]] && [[ $running_method ]]
then
    echo ""
    cat $import_library | grep -B 1 -E "^\s*$running_method\s*\(\s*\)\s*\{\s*$" | grep '#' | \
    sed -e 's/.*#//' -e "s/^[ ]*//g" | awk -v var="$running_method" '{printf var":  "$0"\n"}'
    echo ""
    declare -f $running_method
    # declare -f $running_method | grep -E '=.*\$[0-9]' | awk -F '#' '{ gsub(/=.*/,"",$1); gsub(/^.* /,"",$1); printf "%-30s %s\n", $1, $2; }'
    echo ""
elif [[ $dry_run == "yes" ]] && [[ $import_library ]]
then
    echo
    echo $import_library
    echo 
    cat $import_library | grep -B 1 -E "\(\s*\)\s*\{\s*$" | awk -F '#' '{
        if($0~/#/){
            a=$2;
            getline;
            gsub(/[^a-zA-Z0-9_]*$/,"",$0);
            b=$0;
        }else{
            gsub(/[^a-zA-Z0-9_]*$/,"",$1);
            b=$1;
            a=$2;
        };
        printf "%-30s: %s\n", b, a 
        }' | sed '/^\s*:\s*$/d'
    echo 
else
    {
        if echo $running_optional | grep -qE "[']"
        then
        eval $running_method $running_optional
        else
        $running_method $running_optional
        fi
        eval $running_command
    }
fi

