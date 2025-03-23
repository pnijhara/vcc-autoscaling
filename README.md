# **Auto-Scaling Website Deployment (Local VM + GCP)**

This repository provides a step-by-step guide to deploying a simple website on a local VM and automatically scaling it to GCP when CPU usage exceeds 75%. The local VM acts as the main access point with Nginx dynamically distributing traffic to cloud instances.

---
## **Prerequisites**
- A local VM running Ubuntu/Debian
- GCP account with CLI configured (`gcloud auth login`)
- Nginx installed on the local VM

---
## **Step 1: Install Nginx on Local VM**
```bash
sudo apt update -y
sudo apt install -y nginx
```

## **Step 2: Create a Simple Website**
```bash
echo "<h1>Welcome</h1>" | sudo tee /var/www/html/index.html
sudo systemctl restart nginx
```

## **Step 3: Configure CPU Monitoring**
### **Create `monitor_cpu.sh`**
```bash
nano ~/monitor_cpu.sh
```
Paste the following content:
```bash
#!/bin/bash

THRESHOLD=75  # CPU threshold for scaling

get_cpu_usage() {
    PREV_TOTAL=0
    PREV_IDLE=0
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    PREV_IDLE=$idle
    PREV_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
    sleep 1
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    IDLE=$idle
    TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
    DIFF_IDLE=$((IDLE - PREV_IDLE))
    DIFF_TOTAL=$((TOTAL - PREV_TOTAL))
    DIFF_USAGE=$((100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL))
    echo "$DIFF_USAGE"
}

while true; do
    CPU_USAGE=$(get_cpu_usage)
    if (( CPU_USAGE > THRESHOLD )); then
        echo "$(date) - High CPU detected: $CPU_USAGE%. Scaling..."
        ~/deploy_cloud.sh
    fi
    sleep 1
done
```
Make the script executable:
```bash
chmod +x ~/monitor_cpu.sh
```

## **Step 4: Deploy Auto-Scaling on GCP**
### **Create `deploy_cloud.sh`**
```bash
nano ~/deploy_cloud.sh
```
Paste the following content:
```bash
#!/bin/bash
PROJECT_ID="GCP-PROJECT-ID"
ZONE="us-central1-a"
MACHINE_TYPE="e2-medium"
IMAGE="projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts"
INSTANCE_NAME="autoscaled-instance-$(date +%s)"

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
```
Make the script executable:
```bash
chmod +x ~/deploy_cloud.sh
```

## **Step 5: Configure Nginx Load Balancer on Local VM**
```bash
sudo nano /etc/nginx/sites-available/load_balancer
```
Paste the following configuration:
```nginx
upstream backend {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```
Enable and restart Nginx:
```bash
sudo ln -s /etc/nginx/sites-available/load_balancer /etc/nginx/sites-enabled/
sudo systemctl restart nginx
```

## **Step 6: Start Monitoring and Test Scaling**
### **Start CPU Monitoring**
```bash
~/monitor_cpu.sh
```
### **Simulate High CPU Load**
```bash
yes > /dev/null &
```
Run this command 4-5 times to trigger scaling.

### **Check if GCP Instance is Created**
```bash
gcloud compute instances list
```

## **Step 7: Verify Load Balancing**
1. **Visit Local VM IP** → It should balance between local and cloud VM.
2. **Kill Load Generation Processes**
   ```bash
   pkill yes
   ```

## **Step 8: Cleanup**
To delete all GCP instances:
```bash
gcloud compute instances delete $(gcloud compute instances list --format="get(name)") --quiet
```

---
### 🎯 **Congratulations! Your auto-scaling system is ready! 🚀**
