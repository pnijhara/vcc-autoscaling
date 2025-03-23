#!/bin/bash

PROJECT_ID="<GCP-PROJECT-ID>"
ZONE="us-central1-a"
MACHINE_TYPE="e2-medium"
IMAGE="projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
INSTANCE_NAME="autoscaled-instance-$(date +%s)"

# Create GCP VM

gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image="$IMAGE" \
    --tags="autoscaled" \
    --metadata=startup-script='#!/bin/bash
    sudo apt update -y
    sudo apt install -y nginx
    echo "<h1>Website is running on GCP</h1>" | sudo tee /var/www/html/index.html
    sudo systemctl restart nginx
    sudo systemctl enable nginx'

sleep 30

INSTANCE_IPS=$(gcloud compute instances list --format="get(networkInterfaces[0].accessConfigs[0].natIP)" --filter="status=RUNNING")

NGINX_CONF="/etc/nginx/sites-available/load_balancer"

sudo cp $NGINX_CONF "${NGINX_CONF}.bak"

echo "upstream backend {" | sudo tee $NGINX_CONF
echo "    server 127.0.0.1:8080;" | sudo tee -a $NGINX_CONF

for ip in $INSTANCE_IPS; do
    echo "    server $ip:80;" | sudo tee -a $NGINX_CONF
done

echo "}" | sudo tee -a $NGINX_CONF

echo "server {
    listen 80;
    location / {
        proxy_pass http://backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}" | sudo tee -a $NGINX_CONF

sudo systemctl restart nginx
