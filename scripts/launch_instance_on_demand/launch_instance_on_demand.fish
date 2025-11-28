#!/usr/bin/env fish
# Get the latest NixOS ARM AMI
set AMI_ID (aws ec2 describe-images \
  --owners 427812963091 \
  --filters 'Name=name,Values=nixos/25.11*' 'Name=architecture,Values=arm64' \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "Using AMI: $AMI_ID"

# Launch on-demand instance
# have to use gp2 b/c philly does not support gp3
set INSTANCE_ID (aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type c7g.2xlarge \
  --key-name yubikey \
  --security-group-ids sg-0d988b9eb0abb6542 \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":100,"VolumeType":"gp2","DeleteOnTermination":true}}]' \
  --user-data file:///tmp/nixos-builder-userdata.txt \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=nixos-builder}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched instance: $INSTANCE_ID"
echo "Waiting for instance to be running..."

aws ec2 wait instance-running --instance-ids $INSTANCE_ID

set PUBLIC_IP (aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Instance is running!"
echo "Public IP: $PUBLIC_IP"
echo "Instance ID: $INSTANCE_ID (save this for stop/start commands)"
echo ""
echo "To stop when done: aws ec2 stop-instances --instance-ids $INSTANCE_ID"
echo "To start again: aws ec2 start-instances --instance-ids $INSTANCE_ID"
