#/bin/bash
######
# SoftEther VPN Client wrapper for OSX and Linux
# Shaun Prince - TriNimbus Technologies, inc.
###

## Configuration
CLIENT="/var/root/vpnclient"       # Where the binaries are installed
TAP="tap0"                         # Your tunnel/tap interface
VNIC="PccProd"                     # SoftEther virtual network interface
SUBNET="172.18.0.0/16"             # Destination subnet CIDR
GATEWAY="172.18.160.1"             # Destination router
ACCOUNT="PCC"                      # SoftEther VPN Client account settings

## Declare functions
# make sure that state is not carried through multiple executions of this script
function cleanup {
  iam=""
  vnicconnect=""
  network=""
  virtualnic=""
  vpnstatus=""
  me=""
  interface=""
  iam=`whoami`
  me=`basename "$0"`
}

# debugging and error output of current state
function dumpvars {
  echo "iam: $iam"
  echo "vnicconnect: $vnicconnect"
  echo "network: $network"
  echo "virtualnic: $virtualnic"
  echo "vpnstatus: $vpnstatus"
  echo "me: $me"
  echo "interface: $interface"
}

function checkRequirements {
  echo "Running $me:$CLIENT-$ACCOUNT-$TAP-$VNIC-$SUBNET-$GATEWAY as $iam"
  if [[ $iam == "root" ]]; then
    echo "Sufficient permissions available"
    vnicconnect=`ps -ef | grep vpnclient | grep execsvc | tail -n 1 | awk -F " " {'print $9'}`
    if [[ $vnicconnect == "execsvc" ]]; then
      network="available"
      echo "Network VPN client service is $network"
      virtualnic=`$CLIENT/vpncmd localhost /CLIENT /CMD NicList | grep $VNIC | awk -F "|" {'print $2'}`
      if [[ $virtualnic == $VNIC ]]; then
        network="configured"
        echo "Network VPN client service is $network"
        vpnstatus=`$CLIENT/vpncmd localhost /CLIENT /CMD AccountList | grep Status | awk -F "|" {'print $2'}`
        if [[ $vpnstatus == "Offline" ]]; then
          network="ready"
          echo "Network VPN client service is $network and VPN is $vpnstatus"
        else
          if [[ $vpnstatus == "Connected" ]]; then
            network="connected"
            echo "Network VPN client service is $network and VPN is $vpnstatus"
          else
            network="unconfigured"
            echo "Network VPN client service is $network"
            dumpvars
            echo "try something like: $CLIENT/vpncmd localhost /CLIENT /CMD AccountCreate PCC"
            exit 1
          fi
        fi
      else
        network="notready"
        echo "Network VPN client service is $network"
        dumpvars
        echo "try something like: $CLIENT/vpncmd localhost /CLIENT /CMD NicCreate $VNIC"
        exit 1
      fi
    else
      network="notstarted"
      echo "Network VPN client service is $network"
      #interface=`ifconfig | grep $TAP | awk -F ":" {'print $1'}`
    fi
  else
    network="unknown"
    echo "Insufficient permissions to continue"
    dumpvars
    echo "try something like: sudo $me, or sudo ./$me"
    exit 1
  fi
}

function start {
  if [[ $network == "notstarted" ]]; then
    cd $CLIENT && $CLIENT/vpnclient start
    checkRequirements
  fi
  case $network in
    connected)
      echo "Already connected, please disconnect first using: $me stop"
      ;;
    ready)
      echo "Connecting to $ACCOUNT..."
      $CLIENT/vpncmd localhost /CLIENT /CMD AccountConnect $ACCOUNT
      sleep 5
      checkRequirements
      if [[ $vpnstatus == "Connected" ]]; then
        ipconfig set $TAP DHCP
        sleep 10
        route -n add $SUBNET $GATEWAY
        echo "Done!"
      else
        echo "Connection to $ACCOUNT has failed"
        dumpvars
        stop
        exit 1
      fi
      ;;
    *)
      echo "Network is not ready, please review the console output, check network status and/or VPN account settings"
      dumpvars
      exit 1
      ;;
  esac
}


#$CLIENT/vpncmd localhost /CLIENT /CMD NicEnable $VNIC
#


function stop { # disconnect and clean-up
  $CLIENT/vpncmd localhost /CLIENT /CMD AccountDisconnect PCC
  sleep 2
  $CLIENT/vpnclient stop
  sleep 1
  sudo route -n delete $SUBNET
  echo "Disconnected and cleaned-up the mess"
}

## Main program
# accept command switches
case $1 in
  check)
    echo "$me: Checking requirements..."
    cleanup
    checkRequirements
    ;;
  start)
    echo "$me: Connecting to $ACCOUNT..."
    cleanup
    checkRequirements
    start
    ;;
  stop)
    echo "$me: Disconnecting, and cleaning-up the mess..."
    cleanup
    stop
    ;;
  *)
    echo "Usage: $me check|start|stop"
    ;;
esac
