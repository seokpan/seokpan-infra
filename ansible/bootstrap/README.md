# Ansible Project Runtime Bootstrap Guide

## 목적

이 Bootstrap은 기존 System Python 및 System Ansible을 변경하지 않고,
프로젝트 전용 Python 3.12 기반 Ansible 실행 환경을 생성하기 위한 용도입니다.

기존 System 환경은 Rollback 용도로 유지합니다.

## Version Matrix

- Project Python: 3.12.13
- ansible-core: 2.20.8
- Python kubernetes client: 36.0.3
- kubernetes.core: 6.5.0

## 기존 System 환경

- System Python: 3.9.25
- System ansible-core: 2.14.18

System Python 및 System Ansible은 삭제하거나 교체하지 않습니다.

## 사전 조건

Controller에 Python 3.12가 설치되어 있어야 합니다.

확인:

```bash
python3.12 --version
```

다음과 같이 Python 3.12 버전이 출력되어야 합니다.

```text
Python 3.12.13
```

## 필수 파일

프로젝트 최상위 디렉터리에 다음 파일이 있어야 합니다.

```text
requirements.txt
requirements.yml
bootstrap/version_lock_bootstrap.sh
```

`requirements.txt`:

```text
ansible-core==2.20.8
kubernetes==36.0.3
```

`requirements.yml`:

```yaml
---
collections:
  - name: kubernetes.core
    version: "6.5.0"
```

## Bootstrap 실행

프로젝트 최상위 디렉터리에서 다음 명령을 실행합니다.

```bash
chmod +x bootstrap/version_lock_bootstrap.sh
./bootstrap/version_lock_bootstrap.sh
```

Bootstrap은 다음 작업을 수행합니다.

1. Python 3.12 설치 여부를 확인합니다.
2. 프로젝트 전용 `.venv`를 생성하거나 기존 환경을 재사용합니다.
3. `requirements.txt`의 Python 패키지를 설치합니다.
4. 프로젝트 전용 Ansible Collection을 설치합니다.
5. 설치된 패키지와 Collection 버전을 검증합니다.

버전이 지정된 값과 다르면 Bootstrap은 오류를 출력하고 중단됩니다.

## 프로젝트 환경 사용

Bootstrap이 정상적으로 완료되면 다음 명령을 실행합니다.

```bash
source .venv/bin/activate
export ANSIBLE_COLLECTIONS_PATH="$PWD/.ansible/collections"
```

가상환경이 활성화되면 일반적으로 터미널 앞에 `(.venv)`가 표시됩니다.

설치된 버전을 확인합니다.

```bash
python --version
ansible --version
python -c 'import kubernetes; print(kubernetes.__version__)'
ansible-galaxy collection list --collections-path "$PWD/.ansible/collections"
```

## 프로젝트 환경 종료

작업이 끝나면 다음 명령으로 가상환경을 종료합니다.

```bash
deactivate
```

`deactivate`는 가상환경 사용만 종료합니다. `.venv`와 설치된 파일은 삭제하지 않습니다.

## 기존 System 환경 확인

가상환경을 종료한 후 기존 System 환경을 확인할 수 있습니다.

```bash
python3 --version
ansible --version
```

프로젝트 가상환경은 System Python과 System Ansible을 삭제하거나 교체하지 않습니다.

## 주요 디렉터리

```text
.
├── .venv/                         # 프로젝트 전용 Python 가상환경
├── .ansible/
│   └── collections/               # 프로젝트 전용 Ansible Collections
├── bootstrap/
│   ├── README.md
│   └── version_lock_bootstrap.sh
├── requirements.txt
└── requirements.yml
```

## 주의 사항

- `.venv` 안에서 `sudo pip install`을 실행하지 않습니다.
- System Python 패키지를 삭제하거나 교체하지 않습니다.
- `requirements.txt`와 `requirements.yml`의 버전을 임의로 변경하지 않습니다.
- Bootstrap 스크립트의 요구 버전과 requirements 파일의 버전을 동일하게 유지합니다.
- `.venv`와 `.ansible/collections`는 프로젝트 전용 환경으로 사용합니다.
