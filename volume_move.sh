#!/bin/bash

# 설정 변수
BACKUP_DIR=$(pwd)/backups
DOCKER_IMAGE="busybox"  # 사용할 Docker 이미지
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"  # 사용할 SSH 키 경로

# 옵션 선택 받기
echo "작업 옵션을 선택하세요:"
echo "1. Docker 볼륨 백업 및 이동"
echo "2. Docker 볼륨만 백업"
echo "3. 로컬 데이터만 원격 서버와 동기화"
read -p "옵션 번호를 입력하세요 (1, 2, 또는 3): " ACTION_OPTION

# 사용자 입력 받기
read -p "원격 서버 사용자 이름을 입력하세요: " NEW_SERVER_USER
read -p "원격 서버 주소를 입력하세요: " NEW_SERVER_ADDRESS

# SSH 키 복사
echo "Copying SSH key to new server..."
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "SSH key not found. Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f "$HOME/.ssh/id_rsa" -N ""
fi
if ! ssh-copy-id -i "${SSH_KEY_PATH}" ${NEW_SERVER_USER}@${NEW_SERVER_ADDRESS}; then
    echo "Error: Failed to copy SSH key to new server."
    exit 1
fi

# 작업 옵션에 따라 추가 정보 입력받기 및 실행
if [ "$ACTION_OPTION" == "1" ]; then
    read -p "백업 파일을 저장할 원격 서버 경로를 입력하세요: " NEW_SERVER_PATH

    # 현재 사용 중인 Docker 볼륨 목록 가져오기
    VOLUME_LIST=$(docker volume ls --format "{{.Name}}")
    VOLUME_ARRAY=($VOLUME_LIST)

    # Docker 볼륨 목록 출력
    echo "현재 사용 중인 Docker 볼륨 목록:"
    for i in "${!VOLUME_ARRAY[@]}"; do
        echo "$((i+1)). ${VOLUME_ARRAY[i]}"
    done

    # 사용자로부터 백업할 볼륨 선택받기
    read -p "백업할 Docker 볼륨의 번호를 콤마(,)로 구분하여 입력하세요 (예: 1,3,5): " VOLUME_SELECTION

    # 선택된 볼륨 번호를 배열로 변환
    IFS=',' read -r -a SELECTED_VOLUMES <<< "$VOLUME_SELECTION"

    # 선택된 볼륨 이름을 배열로 변환
    VOLUMES=()
    for i in "${SELECTED_VOLUMES[@]}"; do
        VOLUMES+=("${VOLUME_ARRAY[i-1]}")
    done

    # 이미지 사전 다운로드
    echo "Pulling Docker image ${DOCKER_IMAGE}..."
    docker pull ${DOCKER_IMAGE}

    # 백업 디렉토리 생성
    mkdir -p ${BACKUP_DIR}

    # 1. Docker Volume 데이터를 tar로 백업
    for VOLUME in "${VOLUMES[@]}"; do
        BACKUP_FILE="${BACKUP_DIR}/${VOLUME}.tar"
        echo "Backing up Docker Volume ${VOLUME}..."
        if ! docker run --rm -v ${VOLUME}:/volume:ro -v ${BACKUP_DIR}:/backup ${DOCKER_IMAGE} tar cvf /backup/${VOLUME}.tar /volume; then
            echo "Error: Backup failed for volume ${VOLUME}."
            exit 1
        fi
    done

    # 2. 백업 파일을 새로운 서버로 복사
    echo "Copying backup files to new server..."
    if ! scp ${BACKUP_DIR}/*.tar ${NEW_SERVER_USER}@${NEW_SERVER_ADDRESS}:${NEW_SERVER_PATH}; then
        echo "Error: Failed to copy backup files to new server."
        exit 1
    fi

    # 원격 서버에 필요한 디렉토리 생성
    echo "Creating necessary directories on the remote server..."
    REMOTE_DIR_COMMAND="
    mkdir -p ${NEW_SERVER_PATH}
    "
    if ! ssh ${NEW_SERVER_USER}@${NEW_SERVER_ADDRESS} "${REMOTE_DIR_COMMAND}"; then
        echo "Error: Failed to create directories on the remote server."
        exit 1
    fi

    # 3. 새로운 서버에서 Docker Volume 생성 및 복원
    echo "Restoring volumes on new server..."
    REMOTE_RESTORE_COMMAND="
    VOLUMES=(${VOLUMES[@]})
    docker pull ${DOCKER_IMAGE}
    for VOLUME in \${VOLUMES[@]}; do
        if ! docker volume ls | grep -q \$VOLUME; then
            docker volume create \$VOLUME
        fi
        docker run --rm -v \${VOLUME}:/volume -v ${NEW_SERVER_PATH}:/backup ${DOCKER_IMAGE} tar xvf /backup/\$VOLUME.tar -C /
    done
    "
    if ! ssh ${NEW_SERVER_USER}@${NEW_SERVER_ADDRESS} "${REMOTE_RESTORE_COMMAND}"; then
        echo "Error: Failed to restore volumes on new server."
        exit 1
    fi
elif [ "$ACTION_OPTION" == "2" ]; then
    read -p "백업 파일을 저장할 경로를 입력하세요: " NEW_SERVER_PATH

    # 현재 사용 중인 Docker 볼륨 목록 가져오기
    VOLUME_LIST=$(docker volume ls --format "{{.Name}}")
    VOLUME_ARRAY=($VOLUME_LIST)

    # Docker 볼륨 목록 출력
    echo "현재 사용 중인 Docker 볼륨 목록:"
    for i in "${!VOLUME_ARRAY[@]}"; do
        echo "$((i+1)). ${VOLUME_ARRAY[i]}"
    done

    # 사용자로부터 백업할 볼륨 선택받기
    read -p "백업할 Docker 볼륨의 번호를 콤마(,)로 구분하여 입력하세요 (예: 1,3,5): " VOLUME_SELECTION

    # 선택된 볼륨 번호를 배열로 변환
    IFS=',' read -r -a SELECTED_VOLUMES <<< "$VOLUME_SELECTION"

    # 선택된 볼륨 이름을 배열로 변환
    VOLUMES=()
    for i in "${SELECTED_VOLUMES[@]}"; do
        VOLUMES+=("${VOLUME_ARRAY[i-1]}")
    done

    # 이미지 사전 다운로드
    echo "Pulling Docker image ${DOCKER_IMAGE}..."
    docker pull ${DOCKER_IMAGE}

    # 백업 디렉토리 생성
    mkdir -p ${BACKUP_DIR}

    # 1. Docker Volume 데이터를 tar로 백업
    for VOLUME in "${VOLUMES[@]}"; do
        BACKUP_FILE="${BACKUP_DIR}/${VOLUME}.tar"
        echo "Backing up Docker Volume ${VOLUME}..."
        if ! docker run --rm -v ${VOLUME}:/volume:ro -v ${BACKUP_DIR}:/backup ${DOCKER_IMAGE} tar cvf /backup/${VOLUME}.tar /volume; then
            echo "Error: Backup failed for volume ${VOLUME}."
            exit 1
        fi
    done

    # 2. 백업 파일을 로컬 경로로 이동
    echo "Moving backup files to specified path..."
    if ! mv ${BACKUP_DIR}/*.tar ${NEW_SERVER_PATH}; then
        echo "Error: Failed to move backup files to specified path."
        exit 1
    fi
elif [ "$ACTION_OPTION" == "3" ]; then
    read -p "동기화할 로컬 데이터 경로를 입력하세요 (예: /opt/stacks/authentik): " LOCAL_DATA_PATH
    read -p "동기화할 원격 데이터 경로를 입력하세요 (예: /opt/stacks/authentik): " REMOTE_DATA_PATH

    # 원격 서버에 필요한 디렉토리 생성
    echo "Creating necessary directories on the remote server..."
    REMOTE_DIR_COMMAND="
    mkdir -p ${REMOTE_DATA_PATH}
    "
    if ! ssh ${NEW_SERVER_USER}@${NEW_SERVER_ADDRESS} "${REMOTE_DIR_COMMAND}"; then
        echo "Error: Failed to create directories on the remote server."
        exit 1
    fi

    # 4. 로컬 데이터 경로를 원격지와 동기화
    echo "Syncing local data path to remote server..."
    if ! rsync -avz ${LOCAL_DATA_PATH}/ ${NEW_SERVER_USER}@${NEW_SERVER_ADDRESS}:${REMOTE_DATA_PATH}; then
        echo "Error: Failed to sync local data path to remote server."
        exit 1
    fi
else
    echo "Invalid option selected. Exiting."
    exit 1
fi

echo "Migration and synchronization completed."
