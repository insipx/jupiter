#!/usr/bin/env fish

# Get the latest NixOS ARM AMI
set AMI_ID (aws ec2 describe-images \
  --owners 427812963091 \
  --filters 'Name=name,Values=nixos/25.11*' 'Name=architecture,Values=arm64' \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "Using AMI: $AMI_ID"

# Launch the spot instance
aws ec2 request-spot-instances \
  --instance-count 1 \
  --type "persistent" \
  --launch-specification "{
    \"ImageId\": \"$AMI_ID\",
    \"InstanceType\": \"c7g.8xlarge\",
    \"KeyName\": \"yubikey\",
    \"SecurityGroupIds\": [\"sg-0d988b9eb0abb6542\"],
    \"BlockDeviceMappings\": [{
      \"DeviceName\": \"/dev/xvda\",
      \"Ebs\": {
        \"VolumeSize\": 100,
        \"VolumeType\": \"gp3\",
        \"DeleteOnTermination\": true
      }
    }],
    \"UserData\": \"$USER_DATA\"
  }"
