#!/bin/bash
# This script is used to simulate the performance of host.
# maintained by Sage Ren

interact(){
    echo "test"
    # exit
}

custom_option(){
    local shell_option='
        -f|--file) # the file of server list
            [ "$2" ] && list_file=$2 && shift
            shift
            ;;
        -cl|--cpu-load) # the cpu load
            [ "$2" ] && cpu_load=$2 && shift
            shift
            ;;
        -ccl|--check-cpuload) # check the cpu load
            check_cpuload=yes
            shift
            ;;
        -ct|--check-traffic) # check the cpu load
            check_traffic=yes
            shift
            ;;
        -tbw|--tcp-bandwidth) # the bandwidth of tcp, Mb/s
            [ "$2" ] && tcp_bandwidth=$2 && shift
            shift
            ;;
        -k|--kill) # terminate the process
            kill=yes
            shift
            ;;
        -ch|--check) # check the running process
            check=yes
            shift
            ;;
        -t|--time) # the test time
            [ "$2" ] && test_time=$2 && shift
            shift
            ;;
        -p|--port) # the base port of iperf
            [ "$2" ] && port=$2 && shift
            shift
            ;;
        --ip) # a single ip to check
            [ "$2" ] && test_ip=$2 && shift
            shift
            ;;
    '
    echo "$shell_option"
}

check_variable(){

    ! ([[ $list_file ]] || [[ $test_ip ]]) && echo "The target is missing! " && exit 1

    parallel_no=15


    [[ ! $test_time ]] && test_time=300

    [[ $list_file ]] && server_list="-f $list_file -P $parallel_no" && test_no=`cat $list_file | wc -l`

    [[ $test_ip ]] && server_list="--ip $test_ip" && test_no=1

    [[ ! $port ]] && port="36000"

    [[ ! $connect_mode ]] && connect_mode=tcp

    [[ "$debug" = "yes" ]] && addition_option="--debug"



}

check_test_process(){
    ps -ef | grep -v grep | grep -E "cpu_gzip_random|traffic_iperf_server|traffic_iperf_client|cpulimit|iperf3"
}

kill_test_process(){
    ps -ef | grep -v grep | grep -E "cpu_gzip_random|traffic_iperf_server|traffic_iperf_client|cpulimit|iperf3" | awk '{print $2}' | xargs kill
}

source $(dirname `readlink -f $0`)/base.sh
oneshell_arg custom_option "$@"
export_file_funcs $oneshell_dir/blibs/simulate_load.sh > /dev/null
check_variable

export -f check_test_process
export -f kill_test_process

if [[ $check == "yes" ]]; then
    bash $oneshell_dir/batch_remote_script.sh -m check_test_process $server_list $addition_option
    exit 0
fi

if [[ $kill == "yes" ]]; then
    bash $oneshell_dir/batch_remote_script.sh -m kill_test_process $server_list $addition_option
    exit 0
fi

if [[ $check_cpuload == "yes" ]]; then
    bash $oneshell_dir/batch_remote_script.sh -m top_cpu_load $server_list $addition_option
    exit 0
fi

if [[ $check_traffic == "yes" ]]; then
    bash $oneshell_dir/batch_remote_script.sh -m sar_traffic_load $server_list $addition_option
    exit 0
fi

if [[ $cpu_load ]]; then
    bash $oneshell_dir/batch_remote_script.sh -b -m cpu_gzip_random $server_list -o "$test_time $cpu_load" $addition_option
    exit 0
fi

if [[ $tcp_bandwidth ]]; then
    bash $oneshell_dir/batch_remote_script.sh -b -m traffic_iperf_server $server_list -o "$((test_time+test_no*10)) $port $test_no" $addition_option
    bash $oneshell_dir/batch_remote_script.sh --remote-debug -b -m traffic_iperf_client $server_list -o "$test_time $port $connect_mode $tcp_bandwidth $(awk -F $field_separator '{print $1}' $list_file | tr '\n' ' ' )" $addition_option
    exit 0
fi

