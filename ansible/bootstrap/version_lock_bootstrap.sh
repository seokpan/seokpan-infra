#!/usr/bin/env bash

# Owner: 이유빈
# Scope: Ansible / Project Runtime / Version Lock
# Project: 石나가는 판단
# Purpose: Project Ansible runtime bootstrap and exact version validation
# 최초 작성일: 2026-08-28 KST
# 최종 수정일: 2026-08-31 KST

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${PROJECT_ROOT}/.venv"
COLLECTION_DIR="${PROJECT_ROOT}/.ansible/collections"
REQUIREMENTS_TXT="${PROJECT_ROOT}/requirements.txt"
REQUIREMENTS_YML="${PROJECT_ROOT}/requirements.yml"

# 아래 버전은 requirements.txt와 requirements.yml의 버전과 일치해야 합니다.
REQUIRED_PYTHON_VERSION="3.12.13"
REQUIRED_ANSIBLE_CORE="2.20.8"
REQUIRED_KUBERNETES_CLIENT="36.0.3"
REQUIRED_KUBERNETES_CORE="6.5.0"
REQUIRED_MARIADB_COLLECTION="6.0.2"

echo "============================================================"
echo " Ansible Project Runtime Bootstrap"
echo "============================================================"
echo

echo "[1/8] Project root 확인"
echo "PROJECT_ROOT=${PROJECT_ROOT}"
echo

echo "[2/8] Python ${REQUIRED_PYTHON_VERSION} 확인"

if ! command -v python3.12 >/dev/null 2>&1; then
    echo "ERROR: python3.12 명령을 찾을 수 없습니다."
    echo "Python ${REQUIRED_PYTHON_VERSION}을 설치한 후 다시 실행하세요."
    exit 1
fi

PYTHON_VERSION="$(
    python3.12 \
        -c 'import sys; print(".".join(map(str, sys.version_info[:3])))'
)"

if [[ "${PYTHON_VERSION}" != "${REQUIRED_PYTHON_VERSION}" ]]; then
    echo "ERROR: Python 버전 불일치"
    echo "필요: ${REQUIRED_PYTHON_VERSION}"
    echo "실제: ${PYTHON_VERSION}"
    exit 1
fi

python3.12 --version
echo

echo "[3/8] requirements 파일 확인"

if [[ ! -f "${REQUIREMENTS_TXT}" ]]; then
    echo "ERROR: ${REQUIREMENTS_TXT} 파일이 없습니다."
    exit 1
fi

if [[ ! -f "${REQUIREMENTS_YML}" ]]; then
    echo "ERROR: ${REQUIREMENTS_YML} 파일이 없습니다."
    exit 1
fi

echo "requirements.txt: OK"
echo "requirements.yml: OK"
echo

echo "[4/8] Project venv 생성 또는 재사용"

if [[ ! -d "${VENV_DIR}" ]]; then
    python3.12 -m venv "${VENV_DIR}"
    echo "새 venv 생성 완료: ${VENV_DIR}"
elif [[ ! -x "${VENV_DIR}/bin/python" ]]; then
    echo "ERROR: ${VENV_DIR}는 정상적인 Python 가상환경이 아닙니다."
    echo "해당 디렉터리를 확인하거나 제거한 후 다시 실행하세요."
    exit 1
else
    echo "기존 venv 재사용: ${VENV_DIR}"
fi

VENV_PYTHON_VERSION="$(
    "${VENV_DIR}/bin/python" \
        -c 'import sys; print(".".join(map(str, sys.version_info[:3])))'
)"

if [[ "${VENV_PYTHON_VERSION}" != "${REQUIRED_PYTHON_VERSION}" ]]; then
    echo "ERROR: 기존 venv의 Python 버전이 요구 버전과 일치하지 않습니다."
    echo "필요: ${REQUIRED_PYTHON_VERSION}"
    echo "실제: ${VENV_PYTHON_VERSION}"
    echo "기존 ${VENV_DIR}를 확인한 후 올바른 Python 버전으로 다시 생성하세요."
    exit 1
fi

echo "venv Python 버전: ${VENV_PYTHON_VERSION}"
echo

echo "[5/8] Python Dependency 설치"

"${VENV_DIR}/bin/python" -m pip install \
    -r "${REQUIREMENTS_TXT}"

echo

echo "[6/8] Project Collection 경로 생성"

mkdir -p "${COLLECTION_DIR}"

echo "Collection path: ${COLLECTION_DIR}"
echo
export ANSIBLE_COLLECTIONS_PATH="${COLLECTION_DIR}"

echo "[7/8] Ansible Collection 설치"

"${VENV_DIR}/bin/ansible-galaxy" collection install \
    -r "${REQUIREMENTS_YML}" \
    -p "${COLLECTION_DIR}"

echo

echo "[8/8] Version 검증"

ACTUAL_ANSIBLE_CORE="$(
    "${VENV_DIR}/bin/python" \
        -c 'import ansible.release; print(ansible.release.__version__)'
)"

ACTUAL_KUBERNETES_CLIENT="$(
    "${VENV_DIR}/bin/python" \
        -c 'import kubernetes; print(kubernetes.__version__)'
)"

ACTUAL_KUBERNETES_CORE="$(
    "${VENV_DIR}/bin/ansible-galaxy" collection list \
        --collections-path "${COLLECTION_DIR}" |
        awk '$1 == "kubernetes.core" {print $2}'
)"

ACTUAL_MARIADB_COLLECTION="$(
    "${VENV_DIR}/bin/ansible-galaxy" collection list \
        --collections-path "${COLLECTION_DIR}" |
        awk '$1 == "ansible.mariadb" {print $2}'
)"

if [[ -z "${ACTUAL_KUBERNETES_CORE}" ]]; then
    echo "ERROR: kubernetes.core Collection을 찾을 수 없습니다."
    exit 1
fi

if [[ -z "${ACTUAL_MARIADB_COLLECTION}" ]]; then
    echo "ERROR: ansible.mariadb Collection을 찾을 수 없습니다."
    exit 1
fi

echo "ansible-core: ${ACTUAL_ANSIBLE_CORE}"
echo "kubernetes client: ${ACTUAL_KUBERNETES_CLIENT}"
echo "kubernetes.core: ${ACTUAL_KUBERNETES_CORE}"
echo "ansible.mariadb: ${ACTUAL_MARIADB_COLLECTION}"
echo

if [[ "${ACTUAL_ANSIBLE_CORE}" != "${REQUIRED_ANSIBLE_CORE}" ]]; then
    echo "ERROR: ansible-core 버전 불일치"
    echo "필요: ${REQUIRED_ANSIBLE_CORE}"
    echo "실제: ${ACTUAL_ANSIBLE_CORE}"
    exit 1
fi

if [[ "${ACTUAL_KUBERNETES_CLIENT}" != "${REQUIRED_KUBERNETES_CLIENT}" ]]; then
    echo "ERROR: Python kubernetes client 버전 불일치"
    echo "필요: ${REQUIRED_KUBERNETES_CLIENT}"
    echo "실제: ${ACTUAL_KUBERNETES_CLIENT}"
    exit 1
fi

if [[ "${ACTUAL_KUBERNETES_CORE}" != "${REQUIRED_KUBERNETES_CORE}" ]]; then
    echo "ERROR: kubernetes.core 버전 불일치"
    echo "필요: ${REQUIRED_KUBERNETES_CORE}"
    echo "실제: ${ACTUAL_KUBERNETES_CORE}"
    exit 1
fi

if [[ "${ACTUAL_MARIADB_COLLECTION}" != "${REQUIRED_MARIADB_COLLECTION}" ]]; then
    echo "ERROR: ansible.mariadb 버전 불일치"
    echo "필요: ${REQUIRED_MARIADB_COLLECTION}"
    echo "실제: ${ACTUAL_MARIADB_COLLECTION}"
    exit 1
fi

echo "============================================================"
echo " Bootstrap 완료"
echo "============================================================"
echo
echo "Project 환경 사용:"
echo "  cd \"${PROJECT_ROOT}\""
echo "  source .venv/bin/activate"
echo "  export ANSIBLE_COLLECTIONS_PATH=\"${COLLECTION_DIR}\""
echo
echo "System 환경으로 복귀:"
echo "  deactivate"
