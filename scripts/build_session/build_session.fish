#!/usr/bin/env fish
# ~/bin/build-session
# Manage multiple build servers on AWS

set ARM64_INSTANCE_ID "i-0393659a48a0da9e4"
set FREEBSD_INSTANCE_ID ""  # Set this after launching FreeBSD instance with launch_freebsd_builder

function show_usage
    echo "Usage: build-session {start|stop|status} [arm64|freebsd|all]"
    echo ""
    echo "Examples:"
    echo "  build-session start arm64     - Start ARM64 NixOS builder"
    echo "  build-session start freebsd   - Start FreeBSD builder"
    echo "  build-session start all       - Start both builders"
    echo "  build-session stop all        - Stop both builders"
    echo "  build-session status          - Show status of all builders"
end

set builder $argv[2]
if test -z "$builder"
    set builder "all"
end

function start_instance
    set id $argv[1]
    set name $argv[2]
    if test -z "$id"
        echo "Error: Instance ID not set for $name"
        return 1
    end
    echo "Starting $name..."
    aws ec2 start-instances --instance-ids $id
    aws ec2 wait instance-running --instance-ids $id
    set ip (aws ec2 describe-instances --instance-ids $id \
      --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "$name ready - IP: $ip"
end

function stop_instance
    set id $argv[1]
    set name $argv[2]
    if test -z "$id"
        echo "Error: Instance ID not set for $name"
        return 1
    end
    echo "Stopping $name..."
    aws ec2 stop-instances --instance-ids $id
end

function show_status
    set id $argv[1]
    set name $argv[2]
    if test -z "$id"
        echo "$name: Not configured"
        return
    end
    set state (aws ec2 describe-instances --instance-ids $id \
      --query 'Reservations[0].Instances[0].State.Name' --output text)
    if test "$state" = "running"
        set ip (aws ec2 describe-instances --instance-ids $id \
          --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
        echo "$name ($id): $state - IP: $ip"
    else
        echo "$name ($id): $state"
    end
end

switch $argv[1]
  case start
    switch $builder
      case arm64
        start_instance $ARM64_INSTANCE_ID "ARM64 NixOS builder"
      case freebsd
        start_instance $FREEBSD_INSTANCE_ID "FreeBSD builder"
      case all
        start_instance $ARM64_INSTANCE_ID "ARM64 NixOS builder" &
        if test -n "$FREEBSD_INSTANCE_ID"
            start_instance $FREEBSD_INSTANCE_ID "FreeBSD builder" &
        end
        wait
      case '*'
        echo "Unknown builder: $builder"
        show_usage
    end

  case stop
    switch $builder
      case arm64
        stop_instance $ARM64_INSTANCE_ID "ARM64 NixOS builder"
      case freebsd
        stop_instance $FREEBSD_INSTANCE_ID "FreeBSD builder"
      case all
        stop_instance $ARM64_INSTANCE_ID "ARM64 NixOS builder"
        if test -n "$FREEBSD_INSTANCE_ID"
            stop_instance $FREEBSD_INSTANCE_ID "FreeBSD builder"
        end
      case '*'
        echo "Unknown builder: $builder"
        show_usage
    end

  case status
    show_status $ARM64_INSTANCE_ID "ARM64 NixOS"
    show_status $FREEBSD_INSTANCE_ID "FreeBSD"

  case '*'
    show_usage
end
