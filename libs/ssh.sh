#!/bin/bash


simple_remote_func(){
    local SSH_IP=$1
    local SSH_PORT=$2
    local SSH_USER=$3
    local SSH_PASS=$4
    local SSH_METHOD=$5
    local function=$6
    local background=$7
    local options=$8

    if [[ "$SSH_METHOD" = "password" ]]
    then
        if [ "$SSH_PASS" ]
        then
            local SSH_RUN="sshpass -p $SSH_PASS ssh"
        else
            local SSH_RUN="ssh -o NumberOfPasswordPrompts=0"
        fi
    elif [ "$SSH_METHOD" = "key" ]
    then
        local SSH_RUN="ssh -i $SSH_PASS"
    fi
    echo ""
    echo "{$SSH_IP}"
    echo ""

$SSH_RUN -p ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP} << EOF 2>&1 | grep -vi "Warning: Permanently" | grep -iv "Get password suc" | grep -ivE "rmp.*cdn" | grep -ivE "^host.*port" | grep -v "seudo-terminal" | grep -v "failed login"

    echo "Start $function"
    echo ""
    $(typeset -f $function)
    export -f $function

    if [[ $background == "no" ]]; then
        $function $options 2>&1
    elif [[ $background == "yes" ]]; then
        mkdir -p /tmp/oneshell_\$USER/`date +%Y%m%d`
        nohup bash -c "time $function $options" 2>&1 > /tmp/oneshell_\$USER/`date +%Y%m%d`/`date +%Y%m%d%H%M%S%N`_$function.log 2>&1 &
    fi
EOF

    echo ""
    echo ""
}


run_remote_script(){
    ### import add_log_time
    local SSH_IP=$1
    local SSH_PORT=$2
    local SSH_USER=$3
    local SSH_PASS=$4
    local SSH_METHOD=$5
    local function=$6
    local options="$7"

    local log_file=$8
    local background=$9 && shift
    local debug=$9 && shift
    local sercue_var=(`echo $9`) && shift
    local support_lib_list=(`echo $9`) && shift
    local ssh_mode=$9 && shift # 1: expect; 2: sshpass_simple; 3: sshpass_heredoc
    local export_self_ip=$9 && shift
    local print_all_info=$9

    local support_lib_tmp
    local support_content_list=()
    local support_lib_func=()

    for support_lib_tmp in ${support_lib_list[@]}
    do
        support_lib_func+=(`extract_file_func $support_lib_tmp`)
        support_content_list+=("`cat $support_lib_tmp | grep -vE '^#!.*bin.*sh' | base64 -w 0`")
    done
    if [[ "$SSH_METHOD" = "password" ]]
    then
        if [ "$SSH_PASS" ]
        then
            local SSH_RUN="sshpass -p $SSH_PASS ssh"
        else
            local SSH_RUN="ssh -o NumberOfPasswordPrompts=0"
        fi
    elif [ "$SSH_METHOD" = "key" ]
    then
        local SSH_RUN="ssh -i $SSH_PASS"
    fi
    echo ""
    echo "[$SSH_IP]"
    echo ""


    if [[ $ssh_mode == "1" ]] && [[ "$SSH_PASS" ]]; then

    local base64_cmds=$(echo "
        echo 'Start $function'
        echo ''
        $(echo ${support_content_list[@]} | tr ' ' '\n' | base64 -d)
        $(echo "YWRkX2xvZ190aW1lKCl7CiAgICBhd2sgJ3sgcHJpbnQgIlsic3RyZnRpbWUoIiVZLSVtLSVkICVIOiVNOiVTIixzeXN0aW1lKCkpIl0gICIkMCB9JyAKfQo=" | base64 -d)
        $(typeset -f $function)
        export -f $function
        if [[ '$print_all_info' == 'yes' ]]
        then
            echo '$SSH_IP~~$SSH_PORT~~$SSH_USER~~$SSH_PASS~~$SSH_METHOD'
        fi
        if echo '${sercue_var[@]}' | grep -q '='
        then
            export '${sercue_var[@]}'
        fi
        if [[ '$export_self_ip' == 'yes' ]]; then
            export self_ip=${SSH_IP}
        fi
        if [[ '$background' == 'no' ]]
        then
        $function $options 2>&1
        elif [[ '$background' == 'yes' ]]; then
            mkdir -p /tmp/oneshell_\$USER/`date +%Y%m%d`
            if [[ '$debug' == 'yes' ]]; then
            nohup bash -vx -c 'time $function $options' 2>&1 | add_log_time > /tmp/oneshell_\$USER/`date +%Y%m%d`/`date +%Y%m%d%H%M%S%N`_$function.log 2>&1 &
            else
            nohup bash -c 'time $function $options' | add_log_time > /tmp/oneshell_\$USER/`date +%Y%m%d`/`date +%Y%m%d%H%M%S%N`_$function.log 2>&1 &
            fi
        fi
    " | base64 -w 0)

    expect -c "
    set timeout 60
    log_user 0
    spawn ssh -p ${SSH_PORT} -o PreferredAuthentications=password -o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP}
    log_user 1
    expect -re \"^.*${SSH_USER}.*assword:\s*$\"
    log_user 0
    send {${SSH_PASS}\r}
    log_user 1
    expect {
        -re \"${SSH_USER}@.*\[#$]\" {
            send \"echo '${base64_cmds}' | base64 -di  | bash \r\n\"
            expect -re \"${SSH_USER}@.*\[#$]\"
            exit 0
        }
        \"denied\" {
            exit 1
        }
        \"refused\" {
            exit 1
        }
    }
    expect eof  
    " | grep -vE "${SSH_USER}@.*[#$]" | grep -v "spawn ssh" | grep -vi "Warning: Permanently" | grep -iv "Get password suc" | grep -ivE "rmp.*cdn" | grep -ivE "^host.*port" | grep -v "seudo-terminal" | grep -v "failed login" | grep -viE "Last login.*from" | grep -vE "root@${SSH_IP}.*password"
    # send \"`echo ${support_content_list[@]} | tr ' ' '\n' | base64 -d`\r\"
    # expect -re \"${SSH_USER}@.*[#$]\"
    # send \"for i in ${support_lib_func[@]}; do export -f \$i; done\r\"
    # expect -re \"${SSH_USER}@.*[#$]\"
    # send \"$(typeset -f $function); export -f $function\r\"
    # expect -re \"${SSH_USER}@.*[#$]\"
    # send \"$function $options\r\"
    # expect eof
    elif [[ $ssh_mode == "2" ]]; then

    $SSH_RUN -p ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP} "
        $function
    " 2>&1 | grep -vi "Warning: Permanently" | grep -iv "Get password suc" | grep -ivE "rmp.*cdn" | grep -ivE "^host.*port" | grep -v "seudo-terminal" | grep -v "failed login"

    else

$SSH_RUN -p ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP} << EOF 2>&1 | grep -vi "Warning: Permanently" | grep -iv "Get password suc" | grep -ivE "rmp.*cdn" | grep -ivE "^host.*port" | grep -v "seudo-terminal" | grep -v "failed login"

    echo "Start $function"
    echo ""
    `echo ${support_content_list[@]} | tr ' ' '\n' | base64 -d`
    for i in ${support_lib_func[@]}
    do 
        export -f \$i
    done
    $(typeset -f $function)
    export -f $function

    if [[ $print_all_info == "yes" ]]
    then
        echo "$SSH_IP~~$SSH_PORT~~$SSH_USER~~$SSH_PASS~~$SSH_METHOD"
    fi

    if echo ${sercue_var[@]} | grep -q "="
    then
        export ${sercue_var[@]}
    fi

    if [[ $export_self_ip == "yes" ]]; then
        export self_ip=${SSH_IP}
    fi

    if [[ $background == "no" ]]
    then
    $function $options 2>&1
    elif [[ $background == "yes" ]]; then
        $(typeset -f add_log_time)
        export -f add_log_time
        mkdir -p /tmp/oneshell_\$USER/`date +%Y%m%d`
        if [[ $debug == "yes" ]]; then
        nohup bash -c "set -vx; $function $options" 2>&1 | add_log_time > /tmp/oneshell_\$USER/`date +%Y%m%d`/`date +%Y%m%d%H%M%S%N`_$function.log 2>&1 &
        else
        nohup bash -c "$function $options" | add_log_time > /tmp/oneshell_\$USER/`date +%Y%m%d`/`date +%Y%m%d%H%M%S%N`_$function.log 2>&1 &
        fi
    fi
EOF
    fi

    echo ""
    echo ""
}


batch_remote_script(){
    ### import run_remote_script
    local target_list=$1
    local field_separator=$2
    local function=$3
    local options=$4
    local log_file=$5
    local background=$6
    local debug=$7
    local sercue_var=$8
    local support_lib_list=$9 && shift
    local ssh_mode=$9 && shift
    local export_self_ip=$9 && shift
    local print_all_info=$9
    if [[ -f $target_list ]]
    then
        local SSH_INFO
        for SSH_INFO in `awk '{print $0}' $target_list`
        do
            if echo $SSH_INFO | grep -q "$field_separator"
            then
            local SSH_IP=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $1}')
            local SSH_PORT=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $2}')
            local SSH_USER=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $3}')
            local SSH_PASS=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $4}')
            local SSH_METHOD=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $5}')
            local SSH_OPTIONS=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $6}')
            else
            local SSH_IP=$SSH_INFO
            local SSH_PORT=22
            local SSH_USER=root
            local SSH_METHOD=password
            fi
            run_remote_script "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$function" "$SSH_OPTIONS $options" "$log_file" "$background" "$debug" "$sercue_var" "$support_lib_list" "$ssh_mode" "$export_self_ip" "$print_all_info"
        done
    elif echo $target_list | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -q "$field_separator"
    then
        local SSH_IP=$(echo "${target_list}"|awk -F "$field_separator" '{print $1}')
        local SSH_PORT=$(echo "${target_list}"|awk -F "$field_separator" '{print $2}')
        local SSH_USER=$(echo "${target_list}"|awk -F "$field_separator" '{print $3}')
        local SSH_PASS=$(echo "${target_list}"|awk -F "$field_separator" '{print $4}')
        local SSH_METHOD=$(echo "${target_list}"|awk -F "$field_separator" '{print $5}')
        local SSH_OPTIONS=$(echo "${target_list}"|awk -F "$field_separator" '{print $6}')
        run_remote_script "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$function" "$SSH_OPTIONS $options" "$log_file" "$background" "$debug" "$sercue_var" "$support_lib_list" "$ssh_mode" "$export_self_ip" "$print_all_info"
    elif echo $target_list | grep -qE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
    then
        local SSH_IP=$target_list
        local SSH_PORT=22
        local SSH_USER=root
        local SSH_PASS=""
        local SSH_METHOD=password
        run_remote_script "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$function" "$options" "$log_file" "$background" "$debug" "$sercue_var" "$support_lib_list" "$ssh_mode" "$export_self_ip" "$print_all_info"
    fi
}

switch_remote_cmd(){
    local SSH_IP=$1
    local SSH_PORT=$2
    local SSH_USER=$3
    local SSH_PASS=$4
    local SSH_METHOD=$5
    local command=$6
    local log_file=$7
    local count=0
    if [[ "$SSH_METHOD" = "password" ]]
    then
        if [ "$SSH_PASS" ]
        then
            local SSH_RUN="ssh"
        else
            local SSH_RUN="ssh -o NumberOfPasswordPrompts=0"
        fi
    elif [ "$SSH_METHOD" = "key" ]
    then
        local SSH_RUN="ssh -i $SSH_PASS"
    fi
    echo "" >> "$log_file"
    echo "" >> "$log_file"
    echo ""
    echo "[$SSH_IP]" | tee -a "$log_file"
    echo ""
    until echo "$expect_ssh" | grep -q '>'
    do
    
    local expect_ssh=$(expect -c "
    set timeout 15
    spawn ${SSH_RUN} -p ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP}
    expect \"assword:\"
    send \"${SSH_PASS}\r\"
    expect \">\"
    send \"${command}\r\"
    expect {
        -nocase -re \"more\[^\>]*$\" {
        send \"\r\"
        exp_continue
        }
    }
    expect eof
    ") 2>$log_file
    
    count=$((count+1))

    if [[ $count -ge 3 ]]; then
        break
    fi

    done
# echo "$expect_ssh" >/tmp/oneshell_renxz/20190131/`date +%s`_expect.log
    if echo "$expect_ssh" | grep -iqE "Connection to [0-9.]* closed"
    then
        SSH_RUN="sshpass -p $SSH_PASS ssh"
        yes "" | $SSH_RUN -p ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP} "$command" 2>$log_file
    else
        echo "$expect_ssh"
    fi
    echo ""
    echo "[END]" >> "$log_file"
}

batch_switch_cmd(){
    ### import switch_remote_cmd
    local target_list=$1
    local field_separator=$2
    local command=$3
    local log_file=$4
    local SSH_INFO
    if [[ -f $target_list ]]
    then
        while read SSH_INFO
        do
            if echo $SSH_INFO | grep -q "$field_separator"
            then
            local SSH_IP=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $1}')
            local SSH_PORT=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $2}')
            local SSH_USER=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $3}')
            local SSH_PASS=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $4}')
            local SSH_METHOD=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $5}')
            else
            local SSH_IP=$SSH_INFO
            local SSH_PORT=22
            local SSH_USER=root
            local SSH_METHOD=password
            fi
            switch_remote_cmd "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$command" "$log_file"
        done < "$target_list"
    elif echo $target_list | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -q "$field_separator"
    then
        local SSH_IP=$(echo "${target_list}"|awk -F "$field_separator" '{print $1}')
        local SSH_PORT=$(echo "${target_list}"|awk -F "$field_separator" '{print $2}')
        local SSH_USER=$(echo "${target_list}"|awk -F "$field_separator" '{print $3}')
        local SSH_PASS=$(echo "${target_list}"|awk -F "$field_separator" '{print $4}')
        local SSH_METHOD=$(echo "${target_list}"|awk -F "$field_separator" '{print $5}')
        switch_remote_cmd "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$command" "$log_file"
    elif echo $target_list | grep -qE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
    then
        local SSH_IP=$target_list
        local SSH_PORT=22
        local SSH_USER=root
        local SSH_PASS=""
        local SSH_METHOD=password
        switch_remote_cmd "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$command" "$log_file"
    fi
}


scp_sync_file(){

    local SSH_IP=$1
    local SSH_PORT=$2
    local SSH_USER=$3
    local SSH_PASS=$4
    local SSH_METHOD=$5
    local local_path="$6"
    local remote_path="$7"
    local direction=$8
    local transfer_mode=$9 && shift
    local remote_user=$9 && shift
    local ssh_mode=$9

    if [[ $remote_user == "yes" ]]; then
        remote_path=`echo $remote_path | sed "s/[$]USER/$SSH_USER/g"`
    fi

    if [ "$SSH_METHOD" = "password" ]
    then
        if [ "$SSH_PASS" ]
        then
            local SCP_RUN="sshpass -p $SSH_PASS scp"
        else
            local SCP_RUN="scp -o NumberOfPasswordPrompts=0"
        fi
    elif [ "$SSH_METHOD" = "key" ]
    then
        local SCP_RUN="scp -i $SSH_PASS"
    fi
    echo ""
    echo "[$SSH_IP]"
    echo ""

    if [[ $direction -eq 1 ]]; then
        if [[ $ssh_mode == "2" ]]; then
            $SCP_RUN -v -r -P ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 $local_path ${SSH_USER}@${SSH_IP}:$remote_path 2>&1 | grep -viE "debug1|Sink|OpenSSH|uthenticated|Entering directory" | sed 's/^.*ending[ ]*file[ ]*modes:[ ]*[^ ]*[ ]*[^ ]*[ ]*//g'
        elif [[ $ssh_mode == "1" ]]; then
            expect -c "
            set timeout 15
            spawn $SCP_RUN -r -P ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 $local_path ${SSH_USER}@${SSH_IP}:$remote_path
            expect \"assword:\"
            send {${SSH_PASS}\r}
            expect {
                -re \"${SSH_USER}@.*\[#$]\" {
                    exit 0
                }
                \"denied\" {
                    exit 1
                }
                \"refused\" {
                    exit 1
                }
            }
            expect eof
            "
        fi
    elif [[ $direction -eq 2 ]]; then
        if [[ $transfer_mode -eq 1 ]]; then
            if [[ $ssh_mode == "2" ]]; then
                $SCP_RUN -v -r -P ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP}:$remote_path $local_path 2>&1 | grep -viE "debug1|Sink|OpenSSH|uthenticated|Entering directory" | sed 's/^.*ending[ ]*file[ ]*modes:[ ]*[^ ]*[ ]*[^ ]*[ ]*//g'
            elif [[ $ssh_mode == "1" ]]; then
                expect -c "
                set timeout 15
                spawn $SCP_RUN -r -P ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP}:$remote_path $local_path
                expect \"assword:\"
                send \"${SSH_PASS}\r\"
                expect eof
                "
            fi
        elif [[ $transfer_mode -gt 1 ]]; then
            mkdir -p $local_path/$SSH_IP

            if [[ $ssh_mode == "2" ]]; then

                $SCP_RUN -v -r -P ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP}:$remote_path $local_path/$SSH_IP 2>&1 | grep -viE "debug1|Sink|OpenSSH|uthenticated|Entering directory" | sed 's/^.*ending[ ]*file[ ]*modes:[ ]*[^ ]*[ ]*[^ ]*[ ]*//g'
            
            elif [[ $ssh_mode == "1" ]]; then
                expect -c "
                set timeout 15
                spawn $SCP_RUN -r -P ${SSH_PORT} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=3 ${SSH_USER}@${SSH_IP}:$remote_path $local_path/$SSH_IP
                expect \"assword:\"
                send \"${SSH_PASS}\r\"
                expect eof
                "
            fi
        fi
    fi

    echo ""
    echo ""
}

batch_sync_file(){
    ### import scp_sync_file
    local target_list=$1
    local field_separator=$2
    local local_path="$3"
    local remote_path="$4"
    local direction=$5
    local transfer_mode=$6
    local remote_user=$7
    local ssh_mode=$8
    local SSH_INFO
    if [[ -f $target_list ]]
    then
        while read SSH_INFO
        do
            if echo $SSH_INFO | grep -q "$field_separator"
            then
            local SSH_IP=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $1}')
            local SSH_PORT=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $2}')
            local SSH_USER=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $3}')
            local SSH_PASS=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $4}')
            local SSH_METHOD=$(echo "${SSH_INFO}"|awk -F "$field_separator" '{print $5}')
            else
            local SSH_IP=$SSH_INFO
            local SSH_PORT=22
            local SSH_USER=root
            local SSH_METHOD=password
            fi
            scp_sync_file "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$local_path" "$remote_path" "$direction" "$transfer_mode" "$remote_user" "$ssh_mode"
        done < "$target_list"
    elif echo $target_list | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -q "$field_separator"
    then
        local SSH_IP=$(echo "${target_list}"|awk -F "$field_separator" '{print $1}')
        local SSH_PORT=$(echo "${target_list}"|awk -F "$field_separator" '{print $2}')
        local SSH_USER=$(echo "${target_list}"|awk -F "$field_separator" '{print $3}')
        local SSH_PASS=$(echo "${target_list}"|awk -F "$field_separator" '{print $4}')
        local SSH_METHOD=$(echo "${target_list}"|awk -F "$field_separator" '{print $5}')
        scp_sync_file "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$local_path" "$remote_path" "$direction" "$transfer_mode" "$remote_user" "$ssh_mode"
    elif echo $target_list | grep -qE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
    then
        local SSH_IP=$target_list
        local SSH_PORT=22
        local SSH_USER=root
        local SSH_PASS=""
        local SSH_METHOD=password
        scp_sync_file "$SSH_IP" "$SSH_PORT" "$SSH_USER" "$SSH_PASS" "$SSH_METHOD" "$local_path" "$remote_path" "$direction" "$transfer_mode" "$remote_user" "$ssh_mode"
    fi
}

