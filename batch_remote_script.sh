#!/bin/bash
# This script is used for running the commands or function in the remote servers.
# maintained by Sage Ren

interact(){
    interactive_prompt_msg 3 "Please enter the host list by line" host_ip_list
    server_list=$oneshell_log/${present_time}_host_ip_list.txt
    echo "$host_ip_list" > $server_list
    interactive_prompt_msg 3 "Please enter commands by line" input_command yes
    input_command=$( echo "$input_command" | base64 -di | sed -e "\$a\}" -e "1 i\ input_command\(\)\{" )
    running_method=input_command
    eval "$input_command"
    interactive_prompt_msg 2 "Please enter the number of parallel proccess" parallel_no

}

custom_option(){
    local shell_option='
        -b|--background) # run commands in the background of the remote servers.
            background=yes
            shift
            ;;
        -scmd|--switch-cmd) # the simple command need to run in the switch
            [ "$2" ] && switch_cmd="$2" && shift
            shift
            ;;
        -f|--file) # the file of server list (ip~~port~~user~~pass|key~~password|key)
            [ "$2" ] && server_list=$2 && shift
            shift
            ;;
        -lib|--library) # the library need to be imported to remote servers and the running commands require
            [ "$2" ] && import_library=$2 && shift
            shift
            ;;
        --remote-debug) # open the remote debug
            remote_debug=yes
            shift
            ;;
        -s|--script) # the standalone script need to run
            [ "$2" ] && running_script=$2 && shift
            shift
            ;;
        -m|--method) # the function need to run
            [ "$2" ] && running_method=$2 && shift
            shift
            ;;
        -P|--parallel) # run commands on multiple threads
            [ "$2" ] && parallel_no=$2 && shift
            shift
            ;;
        -cmd|--command) # the simple command need to run in the servers
            [ "$2" ] && running_command="$2" && shift
            shift
            ;;
        -o|--option) # the options for the running commands in the remote servers
            [ "$2" ] && running_optional=$2 && shift
            shift
            ;;
        -sv|--sercue-var) # the variables need to be hidden in the process of remote servers
            [ "$2" ] && sercue_var=$2 && shift
            shift
            ;;
        -r|--result) # specific the remote path to save the log
            [ "$2" ] && result_path=$2 && shift
            shift
            ;;
        --ip) # test for one server
            [ "$2" ] && test_ip=$2 && shift
            shift
            ;;
        --exip) # export the variable (self_ip) of ssh ip to remote server
            export_self_ip=yes
            shift
            ;;
        --log) # the debug log in local
            [ "$2" ] && local_log=$2 && shift
            shift
            ;;
        -kw|--keyword) # the keyword need to be parsed in the local log
            [ "$2" ] && include_keyword=$2 && shift
            shift
            ;;
        -nkw|--no-keyword) # the keyword is not in the local log
            [ "$2" ] && exclude_keyword=$2 && shift
            shift
            ;;
        -lt|--log-table) # extract the info from log to table
            log_table=yes
            shift
            ;;
        -sm|--ssh-mode) # the ssh mode (1:expect,2:sshpass_simple,3:sshpass_heredoc) to run the commands
            [ "$2" ] && ssh_mode=$2 && shift
            shift
            ;;
        -u|--ssh-user) # the ssh username to brute force
            [ "$2" ] && ssh_user="$2" && shift
            shift
            ;;
        -p|--ssh-pass) # the ssh password to brute force
            [ "$2" ] && ssh_pass="$2" && shift
            shift
            ;;
        -po|--ssh-port) # the ssh port to brute force
            [ "$2" ] && ssh_port="$2" && shift
            shift
            ;;
    '

    echo "$shell_option"
}

check_variable(){
    if [[ $local_log ]] && [[ -f $local_log ]] && ( [[ $include_keyword ]] || [[ $exclude_keyword ]] )
    then

        if [[ $log_table != "yes" ]]; then
            log_table=no
        fi

        if ! ( grep -qE "^\[END\]$" $local_log )
        then
            sed -i '/^\[[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\]$/i [END]' $local_log
            echo "[END]" >> $local_log
        fi

        awk -v include_keyword="$include_keyword" -v exclude_keyword="$exclude_keyword" -v log_table="$log_table" '
        {
            if($0~/^\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\]$/){
                gsub(/[\[\]]/,"",$0);
                a=$0;
                b=0;
                c=0;
                while(getline){
                    if($0=="[END]"){
                        break;
                    };

                    if(length(include_keyword) > 0 && length(exclude_keyword) > 0){
                        if(tolower($0) ~ tolower(include_keyword)){
                            b++;
                        }
                        if(tolower($0) ~ tolower(exclude_keyword)){
                            c-=9999999999;
                        }else{
                            c++;
                        }
                    }else{
                        if(length(include_keyword) > 0){
                            keyword=include_keyword
                            if(tolower($0) ~ tolower(keyword)){
                                b++;
                                c++;
                                if(log_table=="yes"){
                                    print a,$0;
                                }
                            }
                        }

                        if(length(exclude_keyword) > 0){
                            keyword=exclude_keyword
                            if(tolower($0) ~ tolower(keyword)){
                                b-=9999999999;
                            }else{
                                b++;
                                c++;
                                if(log_table=="yes"){
                                    print a,$0;
                                }
                            }
                        }

                    }


                }

                if(b==0 && log_table=="yes"){
                    print a" CMD ERROR";
                }

                if(b>0 && c>0 && log_table=="no"){
                    print a;
                }

            }
        }' $local_log
        exit 0
    fi


    if [[ "$running_method" ]] && [[ $(declare -f $running_method | wc -l) -eq 0 ]]; then
        find_import_library=($(find $oneshell_dir -name "*.sh" | xargs -I @@ grep -HE "^\s*$running_method\s*\(\s*\)\s*\{\s*$" @@ | awk -F ':' '{print $1}' | xargs -I @@ readlink -f @@ | sort -u))
        case ${#find_import_library[@]} in
            0) echo "The method is undefine!" && exit 1 ;;
            1) 
                if ! ( check_function_script ${find_import_library[@]} )
                then
                    echo "The ${find_import_library[@]} has other normal commands besides functions!" && exit 1
                fi
            ;;
            *) echo "The method is repeat in ${find_import_library[@]}!" && exit 1 ;;
        esac
    fi

    if [[ "$import_library" ]] || [[ "$find_import_library" ]] ; then
        import_library=($(echo "${import_library[@]} ${find_import_library[@]}" | tr ' ' '\n' | sed "/^$/d; s#^~#$HOME#g" | sort -u | xargs -I @@ readlink -f @@))
    fi

    if ! ( [[ -f "$running_script" ]] || [[ "$switch_cmd" ]] || [[ "$running_command" ]] || \
     ( [[ "$running_method" ]] && [[ $(declare -f $running_method | wc -l) -gt 0 ]] ) || \
     ( [[ "$import_library" ]] && cat ${import_library[*]} | grep -q $running_method ) )
    then
        echo "Please enter the command/method/script need to run!"
        exit 1
    fi

    if [[ ! $test_ip ]] && [[ ! $server_list ]] ; then
        echo "Please input some servers!"
        exit 1
    fi

    # import_library="$oneshell_dir/libs/linux.sh $import_library"

    if ! [[ "$background" == "yes" ]]; then
    background=no
    fi

    if ! [[ "$export_self_ip" == "yes" ]]; then
    export_self_ip=no
    fi

    if ! [[ "$remote_debug" == "yes" ]]; then
    remote_debug=no
    fi

    if [[ "$ssh_mode" == "1" ]]; then
        ssh_mode=1
        if [[ "$running_command" ]]
        then
            input_command(){
                base64 -di <<< $1 | bash
            }
            running_method=input_command
            running_optional=$(echo "$running_command" | base64 -w 0)
        fi
    elif [[ "$ssh_mode" == "2" ]]; then
        if [[ "$running_command" ]]
        then
            running_method="$running_command"
        else
            exit 1
        fi
    else
        ssh_mode=3

        if [[ "$running_command" ]]
        then
            input_command(){
                base64 -di <<< $1 | bash
            }
            running_method=input_command
            running_optional=$(echo "$running_command" | base64 -w 0)
        fi
    fi

    if [[ "$ssh_user" ]] && [[ "$ssh_pass" ]] && [[ "$ssh_port" ]] && ( [[ "$server_list" ]] || [[ "$test_ip" ]] ); then

        if [[ -f "$ssh_user" ]]; then
            ssh_user=($(cat "$ssh_user"))
        else
            ssh_user=($(echo "$ssh_user"))
        fi

        if [[ -f "$ssh_pass" ]]; then
            ssh_pass=($(cat "$ssh_pass"))
        else
            ssh_pass=($(echo "$ssh_pass"))
        fi

        if [[ -f "$ssh_port" ]]; then
            ssh_port=($(cat "$ssh_port"))
        else
            ssh_port=($(echo "$ssh_port"))
        fi

        if [[ -f "$server_list" ]]; then
            test_ip=($(cat "$server_list"))
        else
            test_ip=($(echo "$test_ip"))
        fi
        
        print_all_info=yes
        server_list=$oneshell_log/${present_time}_host_ip_list.txt
        for ssh_user_single in ${ssh_user[@]}
        do
            for ssh_pass_single in ${ssh_pass[@]}
            do
                for ssh_port_single in ${ssh_port[@]}
                do
                    for test_ip_single in ${test_ip[@]}
                    do

                        echo "$test_ip_single${field_separator}$ssh_port_single${field_separator}$ssh_user_single${field_separator}$ssh_pass_single${field_separator}password" >> $server_list

                    done
                done
            done
        done

    fi

    if ! [[ "$print_all_info" == "yes" ]]; then
    print_all_info=no
    fi


    if [[ "$server_list" ]]; then
        target_list=$server_list
        # if [[ $(cat $server_list| wc -l) -le 150 ]]; then
        
        # else
        # split -l 150 $server_list $oneshell_log/${present_time}_split_
        # target_list=(`ls $oneshell_log/${present_time}_split_*`)
        # log_file=$oneshell_log/${present_time}_$(basename $0).log
        # fi
    elif [[ "$test_ip" ]]; then
        target_list=$test_ip

    fi

    if [[ -f $target_list ]]; then
        clean_text_list $target_list
    fi


    if [[ "$running_script" ]]; then
        local running_script_name=`basename $running_script | sed -e 's/\..*sh$//g' -e 's/[^0-9a-zA-Z]/_/g' -e 's/^[_]\+//g'`
        # cat $running_script | grep -v '^#!.*bin.*sh$' | sed -e "\$a\}" -e "1 i\ $running_script_name\(\)\{" > "$oneshell_log/${present_time}_running_script.sh"
        # source "$oneshell_log/${present_time}_running_script.sh"
        local script_content=$(cat $running_script | grep -v '^#!.*bin.*sh$' | sed -e "\$a\}" -e "1 i\ $running_script_name\(\)\{")
        eval "$script_content"
        running_method=$running_script_name
    fi

    if ! [[ $parallel_no ]]; then
        parallel_no=1
    fi

    if [[ $parallel_no -gt 15 ]]; then
        echo "The number of thread should not be larger than 15!"
        exit 1
    fi

}

source $(dirname `readlink -f $0`)/base.sh

oneshell_arg custom_option "$@"

source <(recursive_import $oneshell_dir batch_remote_script)
source <(recursive_import $oneshell_dir batch_switch_cmd)


check_variable


[[ $(declare -f $running_method | wc -l) -gt 0 ]] && export -f $running_method

if [[ "$switch_cmd" ]]; then
    batch_switch_cmd "$target_list" "$field_separator" "$switch_cmd" "$log_file"
else
    # if [[ ${#target_list[@]} -le 1 ]]; then
    #     batch_remote_script "$target_list" "$field_separator" "$running_method" "$running_optional" "$log_file" "$background" "$remote_debug" "$import_library"
    # else
    #     for target in ${target_list[@]}
    #     do
    #         batch_remote_script "$target" "$field_separator" "$running_method" "$running_optional" "$log_file" "$background" "$remote_debug" "$import_library" &
    #     done
    #     echo "Please wait for the background task to finish~~"
    #     wait
    #     echo "Please check the log: $log_file"
    # fi

    if ! ( [[ -f $target_list ]] && [[ $parallel_no -gt 1 ]] ) ; then
        batch_remote_script "$target_list" "$field_separator" "$running_method" "$running_optional" "$log_file" \
        "$background" "$remote_debug" "$sercue_var" "${import_library[*]}" "$ssh_mode" "$export_self_ip" "$print_all_info" | tee -a "$log_file"
    else
        multi_thread_run(){
            local target_ip=$1
            local remote_cmd_log=$(batch_remote_script "$target_ip" "$field_separator" "$running_method" "$running_optional" \
            "$log_file" "$background" "$remote_debug" "$sercue_var" "${import_library[*]}" "$ssh_mode" "$export_self_ip" "$print_all_info")
            echo "$remote_cmd_log"
        }

        tempfifo=$(date +%s%N)
        mkfifo ${tempfifo}
        exec 729<>${tempfifo}
        rm -f ${tempfifo}

        for ((i=1;i<=${parallel_no};i++))
        do
        {
            echo 
        }
        done >&729

        for target_ip in `awk '{print $0}' $target_list`
        do
        {
            read -u729
            {
                multi_thread_run $target_ip | tee -a "$log_file"
                echo ""
                echo "" >&729
            } & 
        } 
        done

        wait

        exec 729>&-

        # thread_count=0
        # loop_count=0
        # while read target_ip
        # do
        #     loop_count=$((loop_count+1))
        #     if [[ $thread_count -lt $parallel_no ]]; then
        #     combine_cmd=$(echo -n "$combine_cmd multi_thread_run $target_ip &")
        #     thread_count=$((count+1))
        #         if [[ $thread_count -eq $parallel_no ]] || [[ $loop_count -eq $(cat $target_list| wc -l) ]]; then
        #         cat <(eval $combine_cmd)
        #         # source <(eval $combine_cmd)
        #         combine_cmd=""
        #         thread_count=0
        #         fi
        #     fi
        # done < "$target_list"

    fi

    if [[ "$debug" = "yes" ]]; then
        echo
        echo $log_file
    fi
fi
