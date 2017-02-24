#!/bin/bash
##########################################################
# An elaborate SoftEther VPN software control script
#
# 2015-12-22 -Shaun Prince - TriNimbus Technologies, Inc.
#
##########################################################

# Configuration
RUN=vpncmd
RUN_DIR=~/bin/vpnclient
SERVER=localhost

# Main Program
cd $RUN_DIR
export ARG1=$1
export ARG2=$2

# Declare functions
function operation {
  # Executing requested operation
  echo "Connecting to \"$ARG1\"."
  ./$RUN $SERVER /client /CMD="account$status $ARG1"
  if [ "$?" = "0" ]
  then
    echo "Operation \"$ARG2\" to site \"$ARG1\" executed successfully."
    # Request DHCP lease from the remote server
    if [ "$ARG2" = "start" ]
    then
      network=`sudo /sbin/ifconfig | grep -i $ARG1 | awk '{ print $1 }'`
      echo "Bringing up VPN interface \"$network\"."
      sudo dhclient $network
    if [ "$?" = "0" ]
    then
      echo "Successfully connected to \"$ARG1\"."
      exit 0
    else
      error
    fi
    exit 0
  else
    echo "Operation \"$ARG2\" to \"$ARG1\" failed. Check the VPN Client config name, refer to the above error or use 'vpncmd list' to get a list of valid names."
    exit 1
  fi
}

function usage {
  echo "usage: vpncmd list | <site> <operation>"
  echo ""
  echo "parameters:"
  echo "list	- List the currently configured accounts"
  echo "site	- specify a site connection name to perform an operation. ignored when used with 'list'."
  echo "operation - 'stop', 'start' and 'status' are the only valid operations. Ignored when used with 'list'."
  echo ""
  exit 0
}

function error {
  echo "Something messed-up. Please check your syntax."
  echo ""
  usage
  exit 1
}

function notfound {
  echo "The specified VPN Client name was incorrect or no longer exists. To view the available list, try 'vpncmd list'."
  echo ""
  error
  usage
  exit 1
}

# Parse the user input
if [ -z "$1" ]
then
  # assume interactive
  ./vpncmd
else

  # Check for account listing only
  case "$1" in
    list) echo "Listing VPN Client accounts"
      ./$RUN $SERVER /client /CMD=accountlist
      exit 0
    ;;
    *) # Qualify the requested operation
      case "$2" in
        start) echo "Executing VPN Client Connect"
          export status=connect
          operation
        ;;
        stop) echo "Executing VPN Client Disconnect"
          export status=disconnect
          operation
        ;;
        status) echo "Executing VPN Client status"
          export status=get
          operation
        ;;
        *) error
        ;;
      esac
    ;;
  esac
fi
