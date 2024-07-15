#!/bin/bash

# 현재 사용자를 기준으로 HOME 디렉토리 설정
USER_HOME=$(eval echo ~$USER)

# OCI CLI 설치 확인 및 설치
if ! command -v oci &> /dev/null
then
    echo "OCI CLI가 설치되어 있지 않습니다. 설치를 진행합니다."
    bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
else
    echo "OCI CLI가 이미 설치되어 있습니다."
fi

# .env 파일을 읽어서 환경 변수 설정
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
else
    echo ".env 파일을 찾을 수 없습니다."
    exit 1
fi

# OCI 설정 파일 경로
OCI_CONFIG_DIR="$USER_HOME/.oci"
OCI_CONFIG_FILE="$OCI_CONFIG_DIR/config"

# 필요한 JSON 파일 경로
AVAILABILITY_CONFIG_FILE="$OCI_CONFIG_DIR/availabilityConfig.json"
INSTANCE_OPTIONS_FILE="$OCI_CONFIG_DIR/instanceOptions.json"
SHAPE_CONFIG_FILE="$OCI_CONFIG_DIR/shapeConfig.json"
SSH_KEY_FILE="$OCI_CONFIG_DIR/ssh-key.key"

# 필요한 디렉토리 생성
mkdir -p "$OCI_CONFIG_DIR"

# JSON 파일 생성
cat > "$AVAILABILITY_CONFIG_FILE" <<EOF
{
    "recoveryAction": "RESTORE_INSTANCE"
}
EOF

cat > "$INSTANCE_OPTIONS_FILE" <<EOF
{
    "areLegacyImdsEndpointsDisabled": false
}
EOF

cat > "$SHAPE_CONFIG_FILE" <<EOF
{
    "ocpus": 4,
    "memoryInGBs": 24
}
EOF

# SSH 키 파일 생성
if [ ! -f "$SSH_KEY_FILE" ]; then
    ssh-keygen -t rsa -b 2048 -f "$SSH_KEY_FILE" -N ""
else
    echo "SSH 키 파일이 이미 존재합니다."
fi

# OCI 설정 초기화
if [ ! -f "$OCI_CONFIG_FILE" ]; then
    echo "OCI 설정을 초기화합니다."
    oci setup config --file "$OCI_CONFIG_FILE" <<EOF
$OCI_CONFIG_FILE
$USER_OCID
$TENANCY_OCID
$REGION
n
$SSH_KEY_FILE
EOF
else
    echo "OCI 설정 파일이 이미 존재합니다."
fi

# 로그 파일 설정
LOG_DIR="$USER_HOME/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/oci_instance_launch_$(date '+%Y-%m-%d_%H-%M-%S').log"

# OCI 인스턴스 생성 명령어 실행 및 로그 기록
$USER_HOME/bin/oci compute instance launch \
 --availability-domain "$AVAILABILITY_DOMAIN" \
 --compartment-id "$COMPARTMENT_ID" \
 --boot-volume-size-in-gbs "$BOOT_VOLUME_SIZE_IN_GBS" \
 --shape VM.Standard.A1.Flex \
 --subnet-id "$SUBNET_ID" \
 --assign-private-dns-record true \
 --assign-public-ip true \
 --availability-config "file://$AVAILABILITY_CONFIG_FILE" \
 --display-name "$DISPLAY_NAME" \
 --image-id "$IMAGE_ID" \
 --instance-options "file://$INSTANCE_OPTIONS_FILE" \
 --shape-config "file://$SHAPE_CONFIG_FILE" \
 --ssh-authorized-keys-file "${SSH_KEY_FILE}.pub" &> "$LOG_FILE"

echo "로그 파일: $LOG_FILE"
