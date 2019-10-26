#!/bin/bash

ascii_to_character() {
    [[ "$1" -lt 256 ]] || return 1
    printf "\\$(printf '%03o' "$1")\n"
}

character_to_ascii() {
    local char="$1"
    LC_CTYPE=C printf '%d\n' "'$char"
}

string_to_chars(){
    local string=$1
    local i
    for ((i=0; i<${#string}; i++)); do echo "${string:$i:1}"; done
}

ascii_encrypt(){
    local string=$1
    local mode=$2
    local char
    local num=0
    local salt=( 73 76 90 74 )
    for ((char=0; char<${#string}; char++))
    do
        local ascii=`character_to_ascii "${string:$char:1}"`
        if [[ $mode == "-d" ]]; then
            local cipher=$((ascii-(${salt[num]}%5)-1))
        else
            local cipher=$((ascii+(${salt[num]}%5)+1))
        fi

        # echo -n $cipher ${salt[num]} ${string:$char:1}
        echo -n "$(ascii_to_character $cipher)"
        num=$((num+1))
        if [[ $num -eq ${#salt[@]} ]]; then
            num=0
        fi
    done
    echo
}

ascii_encrypt_base(){
    local string=$1
    local mode=$2
    if [[ $mode != "-d" ]]; then
        string=$(echo $string | base64 -w 0)
        ascii_encrypt "$string" | base64 -w 0
        echo
    else
        ascii_encrypt "$(echo $string | base64 -di)" $mode | base64 -di
    fi
}
