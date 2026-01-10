#!/usr/bin/env fish

# Get the latest FreeBSD 14.x AMI (official FreeBSD AMIs)
set AMI_ID (aws ec2 describe-images \
  --owners 118940168514 \
  --filters 'Name=name,Values=FreeBSD 14.3-RELEASE*' 'Name=architecture,Values=x86_64' \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "Using FreeBSD AMI: $AMI_ID"

# Launch on-demand instance with powerful specs
# c7i.8xlarge: 32 vCPUs, 64GB RAM - excellent for parallel builds
set INSTANCE_ID (aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type c7i.8xlarge \
  --key-name yubikey \
  --security-group-ids sg-0d988b9eb0abb6542 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":200,"VolumeType":"gp3","Iops":16000,"Throughput":1000,"DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=freebsd-builder}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched FreeBSD instance: $INSTANCE_ID"
echo "Waiting for instance to be running..."

aws ec2 wait instance-running --instance-ids $INSTANCE_ID

set PUBLIC_IP (aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Instance is running!"
echo "Public IP: $PUBLIC_IP"
echo "Instance ID: $INSTANCE_ID"
echo ""
echo "Next steps:"
echo "1. SSH in: ssh -i ~/.ssh/yubikey.pem freebsd@$PUBLIC_IP"
echo "2. Install build tools:"
echo "   sudo pkg install -y gmake cmake llvm16 git ccache ninja meson"
echo "   sudo pkg install -y rust cargo python39 go"
echo "3. Update build_session script with this Instance ID"
echo ""
echo "To configure DNS (optional):"
echo "  - Point freebsd-builder.insipx.xyz to $PUBLIC_IP"
echo ""
echo "Save this for build_session:"
echo "FREEBSD_INSTANCE_ID=\"$INSTANCE_ID\""
