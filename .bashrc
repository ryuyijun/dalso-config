#!/bin/bash

# 포어그라운드에서 실행할 부분
foreground_tasks() {
    echo "Starting foreground tasks..."

    # 호스트네임 입력 받기
    read -p "Enter hostname for this machine: " hostname
    echo "Setting hostname to $hostname..."
    hostnamectl set-hostname "$hostname"

    # IP 주소 입력 받기
    read -p "Enter static IP address (e.g., 192.168.1.100): " static_ip

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
    curl -o /root/.bashrc https://raw.githubusercontent.com/dalso0418/ds-cloud-init/main/.bashrc
    echo ".bashrc downloaded and applied."

    # 필수 패키지 설치
    echo "Installing essential packages..."
    apt install cloud-init vim net-tools qemu-guest-agent -y

    # qemu-guest-agent 서비스 활성화
    echo "Enabling qemu-guest-agent service..."
    systemctl enable qemu-guest-agent
    echo "qemu-guest-agent service enabled."

    # Docker 설치
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    echo "Docker installed and enabled."

    ## Dockge 설정
    # Dockge 관련 디렉토리 생성 및 설정
    echo "Configuring Dockge..."
    mkdir -p /opt/stacks /opt/dockge
    cd /opt/dockge

    # compose.yaml 파일 다운로드
    echo "Downloading compose.yaml for Dockge..."
    curl -o compose.yaml https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml
    echo "compose.yaml downloaded."

    # Docker Compose를 사용하여 서버 시작
    echo "Starting Dockge server with Docker Compose..."
    docker compose up -d
    echo "Dockge server started."

    ## 네트워크 설정 변경
    echo "Updating netplan configuration..."

    # 인터페이스 찾기 (첫 번째로 나오는 인터페이스를 사용)
    interface=$(ip addr | awk '/^[0-9]+:/ {current=$2} /inet / {print current; exit}' | sed 's/://')
    echo "Found interface: $interface"

    # netplan 설정 파일 경로
    netplan_file="/etc/netplan/01-netcfg.yaml"

    # 기존 파일이 있는지 확인하고 백업 후 새로운 설정 파일 생성
    if [ -f "$netplan_file" ]; then
        # 기존 파일 백업
        cp "$netplan_file" "$netplan_file.backup"
        echo "Backup of $netplan_file created."

        # 새로운 설정 파일 생성
        cat > "$netplan_file" <<EOF
network:
  version: 2
  ethernets:
    $interface:
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

        echo "New configuration applied to $netplan_file."

        # 네트워크 설정 적용
        echo "Applying netplan configuration..."
        netplan apply
        echo "Netplan configuration applied."
    else
        echo "Netplan configuration file $netplan_file not found."
        echo "Creating new netplan configuration..."

        # 새로운 설정 파일 생성
        cat > "$netplan_file" <<EOF
network:
  version: 2
  ethernets:
    $interface:
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

        echo "New netplan configuration created at $netplan_file."

        # 네트워크 설정 적용
        echo "Applying netplan configuration..."
        netplan apply
        echo "Netplan configuration applied."
    fi

    echo "Foreground tasks completed."
}

# 포어그라운드 작업 실행
foreground_tasks
