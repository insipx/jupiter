#!/usr/bin/env fish
# ~/bin/build-session
# to use this script you must use the launch_instance script and have the instance configured as a remote builder
# in your nixos configuration: https://nix.dev/manual/nix/2.18/advanced-topics/distributed-builds

set INSTANCE_ID "i-0393659a48a0da9e4"  # Your on-demand instance ID (you'll get this from the launch script)

switch $argv[1]
  case start
    echo "Starting build server..."
    aws ec2 start-instances --instance-ids $INSTANCE_ID
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID

    echo "Builder ready at `arm64-builder.insipx.xyz`"

  case stop
    echo "Stopping build server..."
    aws ec2 stop-instances --instance-ids $INSTANCE_ID

  case status
    aws ec2 describe-instances --instance-ids $INSTANCE_ID \
      --query 'Reservations[0].Instances[0].State.Name' --output text

  case '*'
    echo "Usage: build-session {start|stop|status}"
end
