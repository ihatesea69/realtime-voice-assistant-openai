# Terraform EC2 Deployment

Deploy HieuNghi Voice Agent to AWS EC2.

## Prerequisites

- AWS CLI configured with credentials
- Terraform 1.0+
- Existing EC2 Key Pair

## Usage

```bash
cd terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize
terraform init

# Preview
terraform plan

# Deploy
terraform apply

# Destroy when done
terraform destroy
```

## Outputs

After deployment:

- Frontend: `http://<PUBLIC_IP>:5173`
- Backend: `http://<PUBLIC_IP>:7860`
- SSH: `ssh -i ~/.ssh/<key>.pem ubuntu@<PUBLIC_IP>`

## Notes

- Uses `network_mode: host` for WebRTC compatibility
- Instance auto-starts on boot
- Logs: `/var/log/user-data.log`
