#!/bin/bash

# detect the linux distribution
check_linux_distr(){
if cat /etc/*-release | grep -qi "centos"
then
    export PKGM=yum
    export user_add=useradd
elif cat /etc/*-release | grep -qiE "(debian|ubuntu)"
then
    export PKGM=apt-get
    export user_add=adduser
fi
}

move_all_file(){
    local first_path=$(readlink -f $(dirname "$1"))
    local sec_path=$(readlink -f $(dirname "$2"))
    mv $first_path/{.,}* $sec_path/
    # move include hidden files
    # mv /path/subfolder/* /path/subfolder/.* /path/
}

merge_dirs_file(){
    local first_path=$(readlink -f $(dirname "$1"))
    local sec_path=$(readlink -f $(dirname "$2"))
    cp -rlf $first_path/{.,}* $sec_path/
    # rm -rf $first_path
}

set_global_env(){
    echo "$1" >> ~/.bash_profile
    echo "$1" >> ~/.bashrc
}


batch_install_dependencies(){
    local dependencies=( $@ )
    check_linux_distr
    for deps in ${dependencies[@]}
    do
        local install_times=0
        until eval $deps --version | grep -q linux
        do
            eval sudo $PKGM install -y --quiet $deps
            install_times=$((install_times+1))
            [[ $install_times -ge 5 ]] && exit 1
        done
    done
}


extract_file_func(){
    if [ "$1" ]
    then
        local script_file=$1
        cat $script_file | awk -F '(' '
        BEGIN{
            a=0;
        }
        {
            if($0~/\(\s*\)\s*\{\s*$/){
                gsub(/\s/,"",$1);
                print $1;
                a+=1;
                while(a>0 && getline){
                    if($0~/^\s*\}\s*$/){
                        a=a-1;
                    }
                    if($0~/\{\s*$/){
                        a+=1;
                    }
                }
            }
        }'
    else
        xargs cat | awk -F '(' '
        BEGIN{
            a=0;
        }
        {
            if($0~/\(\s*\)\s*\{\s*$/){
                gsub(/\s/,"",$1);
                print $1;
                a+=1;
                while(a>0 && getline){
                    if($0~/^\s*\}\s*$/){
                        a=a-1;
                    }
                    if($0~/\{\s*$/){
                        a+=1;
                    }
                }
            }
        }'
    fi
}

run_file_funcs(){
    local script_file=$1
    local function_list=`extract_file_func $script_file`
    source $script_file
    local $func
    for func in ${function_list[@]}
    do
        $func
    done
}


export_file_funcs(){
    local script_file=$1
    source $script_file
    local function_list=(`extract_file_func $script_file`)
    local $func
    for func in ${function_list[@]}
    do
#        $(typeset -f $func)
        export -f $func
    done
}


recursive_import(){
    # source <(recursive_import module_path function)
    local working_dir=$1
    local function=$2
    local script_path=$(grep -rH "$function()" $working_dir | awk -F ":" '{
        print $1
    }')

    local function_content=$(awk -v var="$function" -F '(' '
        BEGIN{
            a=0;
        }
        {
            if($0 ~ var && $0~/\(\s*\)\s*\{\s*$/){
                gsub(/\s/,"",$1);
                print $0;
                a+=1;
                while(a>0 && getline){
                    print $0;
                    if($0~/^\s*\}\s*$/){
                        a=a-1;
                    }
                    if($0~/\{\s*$/){
                        a+=1;
                    }
                }
            }
        }' $script_path)

    local dep_functions=($(echo "$function_content" | awk -v var="$working_dir" '{
        if($0~/### import/){
            gsub(/.*### import /,"",$0)
            if($0 ~ /from/){
                gsub(" from","",$0)
                print $2"~~"$1
            }else{
                print var"~~"$0
            }
        }
    }'))

    local dep_function
    for dep_function in ${dep_functions[@]}
    do
        recursive_import $(echo $dep_function | sed 's/~~/ /g')
    done

    # `echo "$function_content"`
    echo "$function_content"
}


# remove the duplicate and empty line
clean_text_list(){
    local server_list=$1
    cp ${server_list} ${server_list}.bak
    cat $server_list.bak | sort -u > $server_list
    rm -f $server_list.bak
    echo "" >> $server_list
    sed -i 's/^ *//g' $server_list
    sed -i 's/ *$//g' $server_list
    sed -i '/^$/d' $server_list
}


generate_rand_num(){
    local max=$1
    if [[ $2 ]]; then
    min=$2
    else
    min=1
    fi
    echo $(( $(date +%s%N) % ($max-$min+1) + $min ))
}

get_rand_item(){
    if [[ $# -eq 2 ]]; then
        local total_num=$1
        local list_file=$2
        cp $list_file $list_file.bak
        list_file=$list_file.bak
    else
        local total_num=$1
        local list_file=/tmp/`date +%s%N`_list_$USER.log
        if ! [[ $total_num ]]; then
            total_num=1
        fi
        awk '{print $0}' > $list_file
    fi
    clean_text_list $list_file
    local i
    for (( i=0; i<total_num; i++ ))
    do
        if [[ $(cat $list_file | wc -l) -gt 0 ]]; then
        local rand_no=$(generate_rand_num $(cat $list_file | wc -l))
        local rand_item=`cat -n $list_file | awk -v var="$rand_no" '{
            if($1==var){
                first = $1;
                $1 = "";
                print $0;
            }
        }' | sed 's/^ //'`
        echo "$rand_item"
        sed -i "/$rand_item/d" $list_file
        else
        break
        fi
    done
    rm -f $list_file
}

remote_global_setting(){
    export oneshell_log=/tmp/oneshell_$USER/`date +%Y%m%d`
    export oneshell_result_dir=/home/oneshell_$USER/`date +%Y%m%d`
    mkdir -p $oneshell_log
    mkdir -p $oneshell_result_dir
}

check_function_script(){
    local function_script=$1
    local return_code=`awk '
    BEGIN{
        a=0;
    }
    {
        while($0~/^#/ || $0~/^$/ || $0 ~ /^\s*$/){
            if(getline == 0){
                exit;
            }
        }
        if($0~/\(\s*\)\s*\{\s*$/){
            a+=1
            while(a>0 && getline){
                if($0~/^\s*\}/){
                    a=a-1;
                }
                if($0~/\{\s*$/){
                    a+=1;
                }
            }
        }else{
            a+=1;
            exit;
        }
    }
    END{
        if(a>0){
            print "1";
        }else{
            print "0";
        }
    }' $function_script`
    return $return_code
}

remote_sql_command(){
    if ! [[ $mysql_username ]]; then
    local mysql_host="$1"
    local mysql_port="$2"
    local mysql_username="$3"
    local mysql_password="$4"
    local sql_command="$5"
    fi
    # mysql --host="$mysql_host" --password="$mysql_password" --user="$mysql_username" --port="$mysql_port" --execute="$sql_command"
mysql --host="$mysql_host" --password="$mysql_password" --user="$mysql_username" --port="$mysql_port" << EOF
$sql_command
EOF
}


interactive_prompt_msg(){
    local prompt_mode=$1 # 1: choice; 2: input; 3: multi-line input
    local prompt_msg=$2
    local input_variable=$3
    local base64_encode=$4
    case $prompt_mode in 
        1)
            echo
            echo "$prompt_msg"
            read -p "Your choise (Y/n) :" $input_variable

            until eval echo \${$input_variable} | grep -iqE "^[yn]"
            do
                read -p "Please enter the correct choice (Y/n) : " $input_variable
            done

            if eval echo \${$input_variable} | grep -iqE "^y"
            then
                eval $input_variable="yes"
            elif eval echo \${$input_variable} | grep -iqE "^n"
            then
                eval $input_variable="no"
            fi
        ;;
        2)
            local input_sercue=$4
            echo
            echo "$prompt_msg"
            if [[ $input_sercue == "yes" ]]; then
                read -s -p "Please enter: " $input_variable && echo
            else
                read -p "Please enter: " $input_variable
            fi
            echo
            eval $input_variable=$(echo \${$input_variable} | sed 's/^\s*\(.*\)\s*$/\1/g')
        ;;
        3)

            echo
            echo "$prompt_msg"
            echo
            echo "Press 'ctrl+d' to continue"
            echo "Please enter: "
            if [[ $base64_encode == "yes" ]]; then
                eval $input_variable="'$(cat | base64 -w 0)'"
            else
                eval $input_variable="'$(cat)'"
            fi
            echo
            echo
            echo "Please wait~~"
            echo
            if [[ $base64_encode != "yes" ]]; then
                local tmp_variable=$(eval echo "\"""\${$input_variable}""\"" | awk '
                    BEGIN{
                        a=0;
                    }
                    {
                        if(length($0)>0 && $0~/[^\s]/){
                            a++;
                        }
                        if(a>0){
                            print $0;
                        }
                    }')
                local tmp_variable=$(tac <(echo "$tmp_variable") | awk '
                    BEGIN{
                        a=0;
                    }
                    {
                        if(length($0)>0 && $0~/[^\s]/){
                            a++;
                        }
                        if(a>0){
                            print $0;
                        }
                    }')
                local tmp_variable=$(tac <(echo "$tmp_variable"))
                eval $input_variable="'$tmp_variable'"
            fi
        ;;
    esac
}


list_ip_segment(){
    local start_ip=$1
    local end_ip=$2
    local start_ip_array=($(echo "$start_ip" | sed 's/\./ /g'))
    local end_ip_array=($(echo "$end_ip" | sed 's/\./ /g'))
    local num
    local temp_count=( 0 0 0 0 )
    local h
    for num in ${!start_ip_array[@]}
    do
        if [[ ${start_ip_array[$num]} -gt 255 ]]; then
            echo "The start ip is illegal~"
            return 1
        fi

        if [[ ${end_ip_array[$num]} -gt 255 ]]; then
            echo "The end ip is illegal~"
            return 1
        fi

        if [[ ${end_ip_array[$num]} -gt ${start_ip_array[$num]} ]]; then
            temp_count[$num]=1
        fi

        if [[ ${start_ip_array[$num]} -gt ${end_ip_array[$num]} ]] && echo ${temp_count[@]} | grep -vq "1"
        then
            echo "The range of ip list is illegal~"
            return 1
        fi

    done

    if [[ "${temp_count[*]}" == "0 0 0 1" ]] || [[ "${temp_count[*]}" == "0 0 0 0" ]]; then
        # local temp_no
        # for temp_no in `seq ${start_ip_array[3]} ${end_ip_array[3]}`
        # do
        #     echo "${start_ip_array[0]}.${start_ip_array[1]}.${start_ip_array[2]}.$temp_no"
        # done
        if [[ ${start_ip_array[3]} -eq 0 ]]; then
            start_ip_array[3]=1
        fi
        eval echo "${start_ip_array[0]}.${start_ip_array[1]}.${start_ip_array[2]}.{${start_ip_array[3]}..${end_ip_array[3]}}" | sed 's/ /\n/g'
    else

        while true
        do
            if [[ ${start_ip_array[3]} -eq 0 ]]; then
            start_ip_array[3]=1
            fi
            for h in `seq ${start_ip_array[3]} 254`
            do
                echo "${start_ip_array[0]}.${start_ip_array[1]}.${start_ip_array[2]}.$h"
            done
            start_ip_array[3]=1
            start_ip_array[2]=$((${start_ip_array[2]}+1))
            if [[ ${start_ip_array[2]} -gt 255 ]]; then
                start_ip_array[2]=0
                start_ip_array[1]=$((${start_ip_array[1]}+1))
            fi

            if [[ ${start_ip_array[1]} -gt 255 ]]; then
                start_ip_array[1]=0
                start_ip_array[0]=$((${start_ip_array[0]}+1))
            fi

            if [[ "${start_ip_array[0]}.${start_ip_array[1]}.${start_ip_array[2]}" == "${end_ip_array[0]}.${end_ip_array[1]}.${end_ip_array[2]}" ]]; then
                for h in `seq 1 ${end_ip_array[3]}`
                do
                    echo "${start_ip_array[0]}.${start_ip_array[1]}.${start_ip_array[2]}.$h"
                done
                return 0
            fi

        done


    fi
}


loop_list_func(){
    local count=0
    local folder=$1
    loop_list(){
        local dir=$1
        local item
        local i
        local item_list=(`ls $dir`)
        for item in ${!item_list[@]}
        do
            for((i=1;i<=count;i++))
            do
                echo -n "    "
            done

            echo ${item_list[item]}

            if [[ -d $dir/${item_list[item]} ]] && [[ $(ls $dir/${item_list[item]} | wc -l) -gt 0 ]]
            then
                count=$((count+1))
                loop_list $dir/${item_list[item]}
            fi

            if [[ $((item+1)) == ${#item_list[@]} ]]
            then
                count=$((count-1))
            fi

        done
    }

    loop_list $folder
}
