#!/bin/bash

# 호스트네임 입력 받기
read -p "Enter hostname for this machine: " hostname
echo "Setting hostname to $hostname..."
hostnamectl set-hostname "$hostname"

# IP 주소 입력 받기
read -p "Enter static IP address (e.g., 192.168.1.23): " static_ip

# 게이트웨이 주소 입력 받기
read -p "Enter gateway address (e.g., 192.168.1.1): " gateway_ip

# 패키지 업데이트
echo "Updating system packages..."
apt update
apt upgrade -y
echo "System packages updated."

# 한국 타임존 설정
echo "Setting timezone to Asia/Seoul..."
timedatectl set-timezone Asia/Seoul
echo "Timezone set to Asia/Seoul."

# .bashrc 파일 다운로드
echo "Downloading .bashrc from GitHub..."
curl -o /root/.bashrc https://raw.githubusercontent.com/dalso0418/dalso-config/main/.bashrc
echo ".bashrc downloaded and applied."

# 필수 패키지 설치 (기존 설치 여부를 체크함)
if ! command -v cloud-init &> /dev/null; then
    echo "Installing cloud-init..."
    apt install cloud-init -y
    echo "cloud-init installed."
else
    echo "cloud-init is already installed. Skipping installation."
fi

if ! command -v vim &> /dev/null; then
    echo "Installing vim..."
    apt install vim -y
    echo "vim installed."
else
    echo "vim is already installed. Skipping installation."
fi

if ! command -v net-tools &> /dev/null; then
    echo "Installing net-tools..."
    apt install net-tools -y
    echo "net-tools installed."
else
    echo "net-tools is already installed. Skipping installation."
fi

if ! command -v qemu-guest-agent &> /dev/null; then
    echo "Installing qemu-guest-agent..."
    apt install qemu-guest-agent -y
    systemctl enable qemu-guest-agent
    echo "qemu-guest-agent installed and enabled."
else
    echo "qemu-guest-agent is already installed. Skipping installation."
fi

# Docker 설치 (기존 설치 여부를 체크함)
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    echo "Docker installed and enabled."
else
    echo "Docker is already installed. Skipping installation."
fi

## Dockge 설정
# Dockge 관련 디렉토리 생성 및 설정
echo "Configuring Dockge..."
mkdir -p /opt/stacks /opt/dockge
cd /opt/dockge

# compose.yaml 파일 다운로드 (기존 파일이 없는 경우에만 다운로드)
if [ ! -f compose.yaml ]; then
    echo "Downloading compose.yaml for Dockge..."
    curl -o compose.yaml https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml
    echo "compose.yaml downloaded."
fi

# Docker Compose를 사용하여 서버 시작
echo "Starting Dockge server with Docker Compose..."
docker compose up -d
echo "Dockge server started."

## 네트워크 설정 변경
echo "Updating netplan configuration..."

# netplan 설정 파일 경로
netplan_dir="/etc/netplan"

# 현재 활성화된 네트워크 인터페이스 찾기
active_interface=$(ip route get 8.8.8.8 | awk '{print $5}')

# 기존 설정 파일들을 찾아서 백업하고 새로운 설정 적용
for file in $netplan_dir/*.yaml; do
    echo "Processing $file..."

    # 파일의 존재 확인
    if [ -f "$file" ]; then
        # 기존 파일을 백업
        cp "$file" "$file.backup$(date +%Y%m%d-%H%M%S)"
        echo "Backup of $file created."

        # 파일명 추출
        filename=$(basename "$file")

        # 새로운 설정 파일 생성
        cat > "$netplan_dir/$filename" <<EOF
network:
  version: 2
  ethernets:
    $active_interface:
      dhcp4: no
      addresses:
        - $static_ip/24
      routes:
        - to: 0.0.0.0/0
          via: $gateway_ip
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

        echo "New netplan configuration applied to $netplan_dir/$filename."

        # 네트워크 설정 적용
        echo "Applying netplan configuration..."
        netplan apply
        echo "Netplan configuration applied."
    fi
done

echo "Script completed."
