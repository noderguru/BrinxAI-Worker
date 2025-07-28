#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}▶ Configuring firewall and opening required ports...${NC}"
sleep 1

if ! command -v ufw &> /dev/null; then
  echo -e "${YELLOW}⚠️  UFW is not installed. Installing UFW...${NC}"
  sudo apt-get install -y ufw
fi

sudo ufw allow 5011/tcp     # BrinxAI Worker Node
sudo ufw allow 1194/udp     # VPN / OpenVPN

UFW_STATUS=$(sudo ufw status | grep -i "Status: active")
if [ -z "$UFW_STATUS" ]; then
  echo -e "${YELLOW}⚠️  UFW is currently inactive. Enabling UFW...${NC}"
  echo "y" | sudo ufw enable
else
  echo -e "${CYAN}✅ UFW is already active.${NC}"
fi

echo -e "${CYAN}📋 Current firewall rules:${NC}"
sudo ufw status verbose

echo -e "${GREEN}▶ Downloading and running BrinxAI Worker installer...${NC}"
sleep 1

INSTALLER_URL="https://raw.githubusercontent.com/admier1/BrinxAI-Worker-Nodes/main/install_brinxai_worker_amd64_deb.sh"
INSTALLER_NAME="install_brinxai_worker_amd64_deb.sh"

rm -f "$INSTALLER_NAME"
wget "$INSTALLER_URL" -O "$INSTALLER_NAME"

if [ -f "$INSTALLER_NAME" ]; then
  chmod +x "$INSTALLER_NAME"
  ./"$INSTALLER_NAME"
else
  echo -e "${RED}❌ Failed to download installer from $INSTALLER_URL${NC}"
  exit 1
fi

echo -e "${GREEN}▶ Select BrinxAI models to launch (separate by space, e.g. 1 3):${NC}"
echo -e "${CYAN}1.${NC} Text UI           (CPU: 4 | RAM: 4GB | Port: 5000)"
echo -e "${CYAN}2.${NC} Rembg             (CPU: 2 | RAM: 2GB | Port: 7000)"
echo -e "${CYAN}3.${NC} Upscaler          (CPU: 2 | RAM: 2GB | Port: 3000)"
echo -e "${CYAN}4.${NC} Stable Diffusion  (CPU: 8 | RAM: 8GB | Port: 5050)"
read -p "Enter your choices (e.g. 1 3): " -a model_choices

docker network create brinxai-network &>/dev/null || true

run_model() {
  NAME=$1
  CPU=$2
  MEM=$3
  PORT=$4
  IMAGE=$5
  echo -e "${CYAN}▶ Launching $NAME...${NC}"
  docker rm -f $NAME &>/dev/null || true
  docker run -d --name $NAME --restart=unless-stopped \
    --network brinxai-network --cpus=$CPU --memory=${MEM}m \
    -p 127.0.0.1:$PORT:$PORT $IMAGE
}

for choice in "${model_choices[@]}"; do
  case "$choice" in
    1) run_model "text-ui" 4 4096 5000 "admier/brinxai_nodes-text-ui:latest" ;;
    2) run_model "rembg" 2 2048 7000 "admier/brinxai_nodes-rembg:latest" ;;
    3) run_model "upscaler" 2 2048 3000 "admier/brinxai_nodes-upscaler:latest" ;;
    4) run_model "stable-diffusion" 8 8192 5050 "admier/brinxai_nodes-stabled:latest" ;;
    *) echo -e "${RED}❌ Invalid choice: $choice${NC}" ;;
  esac
done

echo -e "${GREEN}✅ Selected models have been started successfully.${NC}"
echo -e "${YELLOW}To view logs, use:${NC} ${CYAN}docker logs -f <container_name>${NC}"
