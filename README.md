# seokpan-infra

**SeokPan 프로젝트의 서버, 네트워크, 데이터베이스 및 Kubernetes 기반 인프라를 자동으로 구성하고 관리하는 저장소입니다.**

이 저장소에서는 서버에 필요한 기본 설정부터 Kubernetes, 데이터베이스, 네트워크, 백업 등의 인프라를 **Ansible 코드로 관리하고 자동화**합니다.

> 쉽게 말하면, 사람이 서버에 하나씩 접속해서 설정하는 작업을 코드로 만들어
> **같은 환경을 반복해서 만들고, 수정하고, 다시 확인할 수 있도록 관리하는 저장소**입니다.

---

## 📑 목차

1. [프로젝트 소개](#-프로젝트-소개)
2. [전체 인프라 구성](#-전체-인프라-구성)
3. [인프라 구성 요소](#-인프라-구성-요소)
4. [Ansible 자동화](#-ansible-자동화)
5. [저장소 구성](#-저장소-구성)
6. [관련 문서](#-관련-문서)
7. [보안 관리](#-보안-관리)
8. [작업 방법](#-작업-방법)

---

## 📌 프로젝트 소개

SeokPan 프로젝트는 **실시간 투표형 웹게임 오목 서비스**를 컨테이너 환경에서 운영하기 위한 인프라를 구축하는 프로젝트입니다.

`seokpan-infra`는 이 서비스가 실행될 수 있도록 필요한 **서버와 인프라 환경을 구성하고 관리**합니다.

주요 관리 대상은 다음과 같습니다.

| 구분                | 관리 내용                           |
| ----------------- | ------------------------------- |
| 서버                | Linux 서버 기본 설정 및 공통 환경          |
| 네트워크              | 서버 간 통신 및 네트워크 환경               |
| Load Balancer     | HAProxy, Keepalived 기반 이중화      |
| Kubernetes        | Control Plane, Worker 및 클러스터 구성 |
| Container Runtime | containerd 기반 컨테이너 실행 환경        |
| 데이터베이스            | MariaDB Primary / Replica 구성    |
| DB Proxy          | MaxScale 구성 및 관리                |
| 저장소               | NFS 기반 저장 공간                    |
| 백업                | 데이터베이스 및 시스템 백업                 |
| 보안                | 인증서, 계정, 권한 및 보안 설정             |
| 자동화               | Ansible을 이용한 반복 작업 자동화          |

### 이 저장소의 목적

이 저장소의 가장 중요한 목적은 다음과 같습니다.

* 서버를 같은 방법으로 구성할 수 있도록 만들기
* 반복해서 해야 하는 작업을 자동화하기
* 설정 변경 내용을 코드로 남기기
* 서버 장애나 재구축 상황에서도 빠르게 환경을 다시 만들 수 있도록 하기
* 사람이 직접 작업하면서 발생할 수 있는 실수를 줄이기

---

## 🏗️ 전체 인프라 구성

SeokPan 프로젝트의 전체 인프라는 여러 서버와 가상머신으로 구성되어 있습니다.

먼저 전체적인 구조를 이미지로 확인할 수 있습니다.

### 논리적인 전체 구성

![SeokPan 논리 아키텍처](https://raw.githubusercontent.com/seokpan/seokpan-docs/main/logical-architecture/01_SeokPan_전체%20논리%20아키텍처.png)

논리 아키텍처에서는 **사용자의 요청이 네트워크와 Kubernetes를 거쳐 애플리케이션과 데이터베이스로 전달되는 전체 흐름**을 확인할 수 있습니다.

### 실제 서버 구성

![SeokPan 물리 아키텍처](https://raw.githubusercontent.com/seokpan/seokpan-docs/main/physical-architecture/01_SeokPan_전체%20물리%20아키텍처.png)

물리 아키텍처에서는 실제 환경에서 **어떤 서버와 가상머신에 각 기능이 배치되어 있는지** 확인할 수 있습니다.

현재 설계는 4대의 물리 서버와 여러 가상머신을 사용하는 구조입니다.

---

## 🧩 인프라 구성 요소

전체 인프라는 크게 다음과 같이 나누어져 있습니다.

### 네트워크

서버와 Kubernetes 노드가 서로 통신할 수 있도록 네트워크를 구성합니다.

* VRouter
* 내부 네트워크
* 외부 네트워크
* 공통 VIP
* 서버 간 통신 환경

### Load Balancer

외부에서 들어오는 요청을 Kubernetes 환경으로 전달합니다.

* HAProxy
* Keepalived
* VIP 기반 이중화

한 대의 Load Balancer에 문제가 발생하더라도 다른 Load Balancer를 사용할 수 있도록 구성합니다.

### Kubernetes

애플리케이션을 실행하는 컨테이너 환경입니다.

* Control Plane 3대
* Worker 2대
* containerd
* Calico

Kubernetes 관련 상세 구성은 GitOps 저장소와 함께 관리합니다.

### 데이터베이스

서비스에서 사용하는 데이터를 저장합니다.

* MariaDB Primary
* MariaDB Replica
* MaxScale

Primary 데이터베이스에 문제가 발생했을 때 Replica를 활용할 수 있도록 구성하고 있습니다.

### 저장소 및 백업

데이터와 백업 파일을 별도의 저장 공간에 보관합니다.

* NFS
* MariaDB 백업
* etcd Snapshot
* 백업 파일 보관 및 복구

### CI/CD 및 서비스 운영

애플리케이션을 빌드하고 Kubernetes에 배포하기 위한 환경도 함께 구성합니다.

* Jenkins
* Harbor
* Argo CD
* Prometheus
* Grafana
* Loki
* Alloy
* Alertmanager

Jenkins와 Argo CD의 Kubernetes 배포 내용은 `seokpan-gitops`에서 관리하고, 컨테이너 이미지는 외부 Harbor에서 관리합니다.

---

## ⚙️ Ansible 자동화

이 저장소의 핵심은 **Ansible을 이용한 인프라 자동화**입니다.

서버에 직접 접속해서 명령어를 하나씩 입력하는 대신, Ansible Playbook을 실행하여 필요한 설정을 자동으로 적용합니다.

기본적인 작업 흐름은 다음과 같습니다.

```text
Inventory
   ↓
Playbook
   ↓
Role
   ↓
서버 설정
   ↓
구성 결과 확인
```

### Inventory

어떤 서버에 작업할 것인지 관리합니다.

```text
ansible/inventory/
├── hosts.yml
├── group_vars/
└── host_vars/
```

서버의 역할과 필요한 변수 등을 이곳에서 관리합니다.

### Playbook

실제로 어떤 작업을 할 것인지 정의합니다.

```text
ansible/playbooks/
```

예를 들어 다음과 같은 작업을 Playbook으로 관리합니다.

* 서버 기본 설정
* 시간 동기화
* Container Runtime 설치
* Kubernetes 구성
* 인증서 배포
* 데이터베이스 구성
* 백업 구성
* MaxScale 구성
* Harbor 구성
* Argo CD 초기 구성

### Role

여러 서버에서 반복해서 사용하는 작업을 기능별로 나누어 관리합니다.

```text
ansible/roles/
```

Role을 사용하면 같은 작업을 여러 서버에서 다시 사용할 수 있습니다.

### 자동화 작업의 기본 원칙

Ansible 작업은 다음 순서로 진행하는 것을 기본으로 합니다.

```text
작업 실행
   ↓
구성 변경
   ↓
상태 확인
   ↓
정상 동작 확인
```

단순히 명령어가 성공하는 것만 확인하지 않고, **실제로 원하는 상태가 되었는지 확인하는 것**을 중요하게 생각합니다.

---

## 📁 저장소 구성

주요 디렉터리는 다음과 같습니다.

```text
seokpan-infra/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
│
├── ansible/
│   ├── bootstrap/
│   ├── inventory/
│   ├── playbooks/
│   ├── roles/
│   └── ansible.cfg
│
├── .gitignore
└── README.md
```

### 디렉터리 역할

| 경로                   | 설명                         |
| -------------------- | -------------------------- |
| `.github/`           | Issue 및 Pull Request 작성 규칙 |
| `ansible/inventory/` | 서버 목록과 서버별 설정              |
| `ansible/playbooks/` | 실제 자동화 작업                  |
| `ansible/roles/`     | 기능별 Ansible 작업             |
| `ansible/bootstrap/` | Ansible 작업을 시작하기 위한 초기 설정  |
| `README.md`          | 저장소 전체 설명                  |

---

## 🔗 저장소별 역할

SeokPan 프로젝트는 하나의 저장소에서 모든 것을 관리하지 않습니다.

각 저장소가 담당하는 역할을 나누어 관리합니다.

| 저장소              | 담당 내용                          |
| ---------------- | ------------------------------ |
| `seokpan-infra`  | 서버와 인프라 구성 및 Ansible 자동화       |
| `seokpan-gitops` | Kubernetes에 배포할 상태와 Argo CD 설정 |
| `seokpan-app`    | 실제 웹게임 애플리케이션                  |
| `seokpan-docs`   | 프로젝트 설계, 구조, 테스트 및 검증 문서       |

간단하게 보면 다음과 같습니다.

```text
seokpan-app
    │
    │ 애플리케이션 코드
    ↓
seokpan-gitops
    │
    │ Kubernetes 배포 상태
    ↓
Kubernetes

seokpan-infra
    │
    │ 서버 / 네트워크 / DB / Kubernetes 기반 환경
    ↓
Infrastructure

seokpan-docs
    │
    └── 설계 / 테스트 / 검증 / 변경 기록
```

---

## 📚 관련 문서

인프라의 자세한 설계와 테스트 방법은 `seokpan-docs`에서 관리합니다.

README에서는 전체 내용을 설명하지 않고, 필요한 경우 상세 문서로 이동할 수 있도록 연결합니다.

### 🏗️ 아키텍처

* 전체 논리 아키텍처
* 전체 물리 아키텍처
* 기술 선택 및 구성 이유

### ⚙️ Ansible

* Ansible 자동화 설계
* 자동화 테스트 방법
* 서버 구성 기준

### 🧪 검증 및 운영

* MVP 구현 기준
* 프로젝트 변경 기록
* 백업 및 복구
* 장애 대응 및 검증 자료

> 인프라의 **실제 코드와 자동화 작업은 `seokpan-infra`**,
> 인프라를 **왜 이렇게 구성했는지에 대한 설명과 검증 내용은 `seokpan-docs`**에서 확인할 수 있습니다.

---

## 🔐 보안 관리

서버 구성에 필요한 비밀번호, 인증서, 개인키 등의 민감한 정보는 Git 저장소에 그대로 저장하지 않습니다.

특히 다음과 같은 정보는 주의해서 관리합니다.

* 서버 계정 비밀번호
* 데이터베이스 비밀번호
* API Token
* TLS Private Key
* Kubernetes 인증 정보
* 기타 개인 인증 정보

Ansible에서 필요한 민감한 정보는 가능한 경우 **Ansible Vault를 사용하여 암호화된 상태로 관리**합니다.

또한 `.gitignore`를 사용하여 작업 중 생성되는 민감한 파일이나 로컬 전용 파일이 저장소에 올라가지 않도록 관리합니다.

---

## 🔄 작업 방법

인프라 변경 작업은 다음과 같은 흐름으로 진행합니다.

```text
Issue 등록
   ↓
작업 브랜치 생성
   ↓
Ansible 코드 수정
   ↓
서버에서 테스트
   ↓
결과 확인
   ↓
Commit
   ↓
Pull Request
   ↓
코드 리뷰
   ↓
Merge
   ↓
main 반영
```

### 작업할 때 중요하게 보는 것

**1. 먼저 작업 내용을 정합니다.**

무엇을 변경하고 왜 변경하는지 Issue에 남깁니다.

**2. 작업 브랜치에서 수정합니다.**

`main`에서 바로 수정하지 않고 별도의 작업 브랜치를 사용합니다.

**3. 실제 서버에서 테스트합니다.**

Ansible 코드가 정상적으로 실행되는지 확인합니다.

**4. 결과를 확인합니다.**

명령어가 성공했다는 것뿐만 아니라 실제 서버 상태가 원하는 결과인지 확인합니다.

**5. Pull Request로 검토합니다.**

변경 내용을 다른 팀원이 확인할 수 있도록 PR을 생성합니다.

**6. 검토가 끝난 후 main에 반영합니다.**

검증이 완료된 코드만 `main`에 반영합니다.

---

## 🎯 정리

`seokpan-infra`는 SeokPan 프로젝트에서 사용하는 **서버와 인프라를 코드로 관리하는 저장소**입니다.

단순히 서버를 만드는 것에 그치지 않고,

```text
서버 구성
  ↓
자동화
  ↓
반복 실행
  ↓
상태 확인
  ↓
변경 기록
```

이 가능한 환경을 만드는 것을 목표로 합니다.

이를 통해 새로운 서버를 구성하거나 기존 서버를 다시 구성해야 할 때도 **같은 코드를 사용하여 동일한 환경을 만들 수 있도록 관리**합니다.
