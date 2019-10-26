#!/bin/bash

# work for 2 cpus , not for 48 cpus
cpu_gzip_random(){
    local test_time=$1
    local cpu_load=$2
    cpulimit -l $cpu_load -i cat /dev/urandom | gzip -9 | gzip -d | gzip -9 | gzip -d > /dev/null &
    local cpu_simulate=$!
    sleep $test_time
    kill $cpu_simulate
}

top_cpu_load(){
    top -b -n 5 -d 0.2 | awk -F ',' '{if($0~/us/ && $0~/id/){print $0}}' | sort -t "," -k 4,4 -n 
}

traffic_iperf_server(){
    local test_time=$1
    local server_port=$2
    local thread_no=$3
    for ((i=1;i<=$thread_no;i++))
    do
        iperf3 --server --daemon --port $((server_port+i)) &
    done
    sleep $test_time
    ps -ef | grep -v grep | grep "iperf3 --server" | awk '{print $2}' | xargs kill
}

traffic_iperf_client(){
    local test_time=$1 && shift
    local server_port=$1 && shift
    local connect_mode=$1 && shift
    local bandwidth=$1 && shift
    local server_list=("$@")
    local self_ip=(`ifconfig | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -vE "172\.20|127\.|10\.10\.|172\.17\." | sed 's/^\s*//g' | awk '{gsub(/[^0-9.]/,"",$2); print $2}'`)
    local self_position=`echo ${server_list[@]} | tr ' ' '\n' | awk -v self_ip="$self_ip" '{if($0==self_ip){print NR;}}'`
    local target_ip
    for target_ip in ${server_list[@]}
    do
        if [[ $self_ip == $target_ip ]]; then
            continue
        fi
        iperf3 --client ${target_ip} --bitrate $(echo | awk -v target_no="${#server_list[@]}" -v bw="$bandwidth" '{printf "%0.2fM", bw/target_no}') --interval 60 --time $test_time --port $((server_port+self_position)) 1>/dev/null 2>&1 &
    done
    rm -f /tmp/cpu_load_$(date +%Y%m%d).log
    while true
    do
        sleep 3
        top -b -n 5 -d 0.2 | awk -F ',' '{if($0~/us/ && $0~/id/){print $0}}' | sort -t "," -k 4,4 -n | head -n 1 | awk '{ print "["strftime("%Y-%m-%d %H:%M:%S",systime())"]  "$0 }' >> /tmp/cpu_load_$(date +%Y%m%d).log 2>&1 &
    done &
}

sar_traffic_load(){
    echo "rxkB/s"
    sar -n DEV 1 3 | grep -vi "Average" | sort -k 6,6 -n | tail
    echo "txkB/s"
    sar -n DEV 1 3 | grep -vi "Average" | sort -k 7,7 -n | tail
}

