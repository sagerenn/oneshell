#!/bin/bash

add_log_time(){
    awk '{ print "["strftime("%Y-%m-%d %H:%M:%S",systime())"]  "$0 }' 
}

set_csv_bom(){
    printf '\xEF\xBB\xBF' > $1
}
