#!/bin/bash
# This script is used to exchange the files between the local and the remote.
# maintained by Sage Ren

interact(){
    echo "test"
}

order_no=0
custom_option(){
    local shell_option='
        -f|--file) # the file of server list
            [ "$2" ] && server_list=$2 && shift
            shift
            ;;
        -P|--parallel) # run commands on multiple threads
            [ "$2" ] && parallel_no=$2 && shift
            shift
            ;;
        -lp|--local-path) # the local path to exchange the files
            [ "$2" ] && local_path=($(eval echo $2)) && local_order=$order_no && order_no=$((order_no+1)) && shift
            shift
            ;;
        -rp|--remote-path) # the remote path to exchange the files
            [ "$2" ] && remote_path="$2" && remote_order=$order_no && order_no=$((order_no+1)) && shift
            shift
            ;;
        -dm|--direct-mode) # the direction to sync the files, 1: local to remote; 2: remote to local
            [ "$2" ] && direct_mode=$2 && shift
            shift
            ;;
        -tm|--transfer-mode) # the mode to sync the files, 1: file to file; 2: file to dir; 3: dir to dir
            [ "$2" ] && transfer_mode=$2 && shift
            shift
            ;;
        -sm|--ssh-mode) # the ssh mode (1:expect,2:sshpass) to run the commands
            [ "$2" ] && ssh_mode=$2 && shift
            shift
            ;;
        -ru|--remote-user) # parse $USER to remote user in the remote path
            remote_user=yes
            shift
            ;;
        --ip) # test for one server
            [ "$2" ] && test_ip=$2 && shift
            shift
            ;;
    '

    echo "$shell_option"
}

check_variable(){
    if [[ ! $local_path ]] || [[ ! $remote_path ]]
    then
        echo "Please enter the local path and the remote path!"
        exit 1
    fi

    local_path="${local_path[@]}"


    if ! [[ $direct_mode ]]; then
        if [[ $local_order -gt $remote_order ]]; then
            direct_mode=2
        else
            direct_mode=1
        fi
    fi

    if ! [[ $ssh_mode ]]; then
        ssh_mode=2
    fi

    if [[ $direct_mode -eq 2 ]] && [[ -d $local_path ]] && [[ -f $server_list ]]
    then
        local_path=$(readlink -f $local_path)/$(basename $server_list | sed 's/\..*$//g')
    fi

    if ! [[ $parallel_no ]]; then
        parallel_no=1
    fi

    if ! [[ $remote_user ]]; then
        remote_user=no
    fi

    if [[ "$test_ip" ]]; then
    target_list=$test_ip
    elif [[ "$server_list" ]]; then
        target_list=$server_list
    fi

    if [[ $direct_mode -eq 2 ]] && [[ ! -f $target_list ]]; then
        local_path=$(readlink -f $local_path)/$(date +%Y%m%d%H%M)
    fi
    
    if [[ -f $target_list ]]; then
        clean_text_list $target_list
    fi

    if [[ ! "$transfer_mode" ]]; then
        transfer_mode=2
    fi

}

source $(dirname `readlink -f $0`)/base.sh
oneshell_arg custom_option "$@"
source $oneshell_dir/libs/ssh.sh
export -f scp_sync_file
export -f batch_sync_file
check_variable

if ! ( [[ -f $target_list ]] && [[ $parallel_no -gt 1 ]] ); then
    script -q -c "batch_sync_file '$target_list' '$field_separator' '$local_path' '$remote_path' '$direct_mode' \
    '$transfer_mode' '$remote_user' '$ssh_mode'"  | awk '
        {
            if($0!~/Get password suc/ && $0!~/Warning: Permanently/ && $0!~/Killed by/ && $0!~/^host:.*port/ && $0!~/spawn/ && $0!~/rmp.*cdn/){
                print $0
            }
        }'
else
    multi_thread_run(){
        local target_ip=$1
        local remote_cmd_log=$(script -q -c "batch_sync_file '$target_ip' '$field_separator' '$local_path' '$remote_path' \
        '$direct_mode' '$transfer_mode' '$remote_user' '$ssh_mode'")
        echo "$remote_cmd_log"  | grep -v "Get password suc" | grep -v "Warning: Permanently" | \
        grep -vE "^host:.*port" | grep -vi "Killed by" | grep -vi "spawn" | grep -viE "rmp.*cdn"
    }

    tempfifo=$(date +%s%N)
    mkfifo ${tempfifo}
    exec 730<>${tempfifo}
    rm -f ${tempfifo}

    for ((i=1;i<=${parallel_no};i++))
    do
    {
        echo 
    }
    done >&730

    for target_ip in `cat $target_list`
    do
    {
       
        read -u730
        {
            multi_thread_run $target_ip
            echo ""
            echo "" >&730
        } & 
    } 
    done

    wait

    exec 730>&-
fi
