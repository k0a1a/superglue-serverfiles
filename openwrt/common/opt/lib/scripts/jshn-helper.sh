#!/bin/bash

ifaceStat() {
  . /usr/share/libubox/jshn.sh
  local _IFACE=$1
  local _STATUS="$(runSuid ubus call network.interface.$_IFACE status 2>/dev/null)"
  if [[ "$_STATUS" != "" ]]; then
    local State=""
    local Iface=""
    local Uptime=""
    local IP4=""
    local IP6=""
    local Subnet4=""
    local Subnet6=""
    local Gateway4=""
    local Gateway6=""
    local DNS=""
    local Protocol=""
    json_load "${_STATUS:-{}}"
    json_get_var State up
    json_get_var Uptime uptime
    json_get_var Iface l3_device
    json_get_var Protocol proto

    if json_get_type Status ipv4_address && [ "$Status" = array ]; then
      json_select ipv4_address
      json_get_type Status 1
      if [ "$Status" = object ]; then
        json_select 1
        json_get_var IP4 address
        json_get_var Subnet4 mask
        [ "$IP4" != "" ] && [ "$Subnet4" != "" ] && IP4="$IP4,$Subnet4"
      fi
    fi
    json_select
    if json_get_type Status ipv6_address && [ "$Status" = array ]; then
      json_select ipv6_address
      json_get_type Status 1
      if [ "$Status" = object ]; then
        json_select 1
        json_get_var IP6 address
        json_get_var Subnet6 mask
        [ "$IP6" != "" ] && [ "$Subnet6" != "" ] && IP6="$IP6,$Subnet6"
      fi
    fi
    json_select
    if json_get_type Status route && [ "$Status" = array ]; then
      json_select route
      local Index="1"
      while json_get_type Status $Index && [ "$Status" = object ]; do
        json_select "$((Index++))"
        json_get_var Status target
        case "$Status" in
          0.0.0.0)
            json_get_var Gateway4 nexthop;;
          ::)
          json_get_var Gateway6 nexthop;;
        esac
       json_select ".."
      done  
    fi
    json_select
    if json_get_type Status dns_server && [ "$Status" = array ]; then
      json_select dns_server
      local Index="1"
      while json_get_type Status $Index && [ "$Status" = string ]; do
        json_get_var Status "$((Index++))"
        DNS="${DNS:+$DNS }$Status"
      done
    fi
    if [ "$State" == "1" ]; then
      [ "$IP4" != "" ] && _echo "$IP4,$Gateway4," 
      [ "$IP6" != "" ] && _echo "$IP6,$Gateway6,"
    _echo "$Iface,$Uptime,"
    [ "$DNS" != "" ] && _echo "$DNS"
    fi
  fi

#  json_get_type _IFSTAT ipv4_address
#  if json_get_type _IFSTAT ipv4_address && [[ "$_IFSTAT" == 'array' ]]; then
#    json_select ipv4_address
#    json_get_type _IFSTAT 1
#    if [[ "$_IFSTAT" == 'object' ]]; then
#      json_select 1
#      json_get_var IP4 address
#      json_get_var Subnet4 mask
#      [[ "$IP4" != '' ]] && [[ "$Subnet4" != '' ]] && IP4="$IP4/$Subnet4"
#    fi
#  fi
#  logThis $IP4
}

