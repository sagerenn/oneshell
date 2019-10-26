#!/bin/bash

virsh_console_expect(){
    local instance=$1
    local instance_user=$2
    local instance_pass=$3
    local text_function="$4"
    local text_optionals="$5"
    local base64_cmds=$(typeset -f $text_function | sed "\$a $text_function $text_optionals" | base64 -w 0)

    echo "{$instance}"
    echo ""

    expect -c "
        spawn virsh console $instance
        expect -re \".*character.*\"
        send \"\r\"
        expect {
            -re \".*ogin.*\" {
                send \"$instance_user\r\"
                expect -r \".*assword.*\"
                send \"$instance_pass\r\"
            }

            -re \".*assword.*\" {
                send \"$instance_pass\r\"
            }
        }
        expect {
            -re \"${instance_user}@.*\[#$]\" {
                send \"echo '${base64_cmds}' | base64 -di  | bash \r\n\"
                expect -re \"${instance_user}@.*\[#$]\"
                send \"exit \r\n\"
            }

            \"incorrect\" {
                send \"\035 \r\"
                exit 1
            }
        }
        expect -re \"${instance_user}\"
        send \"\035 \r\"
    " 2>&1 | grep -viE "base64 -di|Last login|character|spawn|virsh console|${instance_user}@.*[#$]|assword:|login:|Kernel.*on|CentOS Linux|ubuntu linux"

}

