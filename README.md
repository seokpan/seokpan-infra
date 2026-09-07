# seokpan-infra

석판팀 「石나가는 판단」 1차 프로젝트의 **On-premise Infrastructure 구성과 Ansible 기반 자동화 자산**을 관리하는 Repository입니다.

본 Repository에서는 서비스가 실행되기 위한 Host, Network, Load Balancer, Kubernetes Cluster, Database 및 Infrastructure 구성요소를 관리하고, 이를 Ansible을 통해 자동화합니다.

---

## 1. Project Overview

본 프로젝트는 On-premise 환경에서 **실시간 투표형 웹게임 서비스를 안정적으로 운영할 수 있는 Container Platform과 Infrastructure Automation 환경**을 구축하는 것을 목표로 합니다.

전체 프로젝트는 역할에 따라 다음 Repository로 분리하여 관리합니다.

```text
┌─────────────────────────────────────────────────────────┐
│                    seokpan-docs                         │
│          Project Design / Architecture / Baseline       │
└──────────────────────────┬──────────────────────────────┘
                           │
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ seokpan-app   │  │seokpan-gitops │  │ seokpan-infra │
│               │  │               │  │               │
│ Application   │  │ Kubernetes    │  │ Infrastructure│
│ Source        │  │ Desired State │  │ & Ansible    │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                   │                  │
        │                   │                  │
        ▼                   ▼                  ▼
    Application          Argo CD          On-premise
      Build             Deployment       Infrastructure
```

---

## 2. Infrastructure Overview

`seokpan-infra`에서는 Application이 실행될 수 있도록 다음과 같은 Infrastructure 영역을 구성합니다.

```text
                         Client
                           │
                           ▼
                    Load Balancer / VIP
                           │
                           ▼
                  Kubernetes / OKD Cluster
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
          Application     Redis       Platform
              │
              │
              ▼
           MaxScale
              │
        ┌─────┴─────┐
        ▼           ▼
     MariaDB     MariaDB
        │
        ▼
      Backup
        │
        ▼
   Backup Storage


Network
   │
   ▼
VRouter / Static Routing / Firewall


Container Image
   │
   ▼
Harbor
   │
   ▼
Kubernetes
```

Infrastructure의 상세 Architecture와 실제 구성 기준은 아래 문서를 참고합니다.

* [논리 Architecture](https://github.com/seokpan/seokpan-docs/blob/main/04_SeokPan_%EA%B8%B0%EC%88%A0_%EB%B9%84%EA%B5%90_%EB%B0%8F_%EB%85%BC%EB%A6%AC_%EC%95%84%ED%82%A4%ED%85%8D%EC%B2%98.pdf)
* [물리 Architecture](https://github.com/seokpan/seokpan-docs/blob/main/05_SeokPan_%EB%AC%BC%EB%A6%AC_%EC%95%84%ED%82%A4%ED%85%8D%EC%B2%98.pdf)
* [현재 MVP 구현 기준](https://github.com/seokpan/seokpan-docs/blob/main/MVP_IMPLEMENTATION_BASELINE.md)

---

## 3. Infrastructure Responsibilities

`seokpan-infra`의 주요 책임 영역은 다음과 같습니다.

| 영역                | 주요 역할                                 |
| ----------------- | ------------------------------------- |
| Host / VM         | Infrastructure Host 및 VM 기본 구성        |
| Network           | Network Configuration 및 Host 통신 기반 구성 |
| VRouter           | Static Routing 및 Network 간 연결         |
| Firewall          | Host 및 Infrastructure Network 접근 제어   |
| Load Balancer     | HAProxy / Common VIP 기반 Traffic 전달    |
| Kubernetes        | Cluster Bootstrap 및 기반 구성             |
| Container Runtime | Kubernetes 실행 기반 구성                   |
| Database          | MariaDB / MaxScale Infrastructure 구성  |
| Storage / Backup  | NFS 및 Database Backup 기반 구성           |
| Registry          | Harbor Infrastructure 구성              |
| Automation        | Ansible Playbook / Role 기반 자동화        |
| Validation        | Infrastructure 구성 및 상태 검증             |

> Application의 소스코드와 Kubernetes Workload의 Desired State는 이 Repository에서 관리하지 않습니다.

---

## 4. Repository Boundary

프로젝트의 각 Repository는 다음과 같이 책임을 분리합니다.

| Repository                                                          | 책임                                                                        |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [seokpan-infra](https://github.com/seokpan/seokpan-infra/tree/main) | Host / VM / Network / Infrastructure / Kubernetes Bootstrap / Ansible     |
| [seokpan-gitops](https://github.com/seokpan/seokpan-gitops)         | Kubernetes Desired State / Argo CD / Platform / Application Deployment    |
| [seokpan-app](https://github.com/seokpan/seokpan-app)               | Frontend / Backend Application Source 및 Test                              |
| [seokpan-docs](https://github.com/seokpan/seokpan-docs)             | Project Design / Architecture / Implementation Baseline / Troubleshooting |

### Repository 간 흐름

```text
seokpan-app
     │
     │ Application Source
     ▼
Container Build
     │
     ▼
Harbor
     │
     ▼
seokpan-gitops
     │
     │ Kubernetes Desired State
     ▼
Argo CD
     │
     ▼
Kubernetes / OKD
     ▲
     │
     │ Cluster / Host / Network
     │
seokpan-infra


seokpan-docs
     │
     └── Project-wide Design / Architecture / Baseline
```

각 Repository의 상세 책임 범위는 각 Repository의 README를 참고합니다.

* [seokpan-gitops README](https://github.com/seokpan/seokpan-gitops/blob/main/README.md)
* [seokpan-app README](https://github.com/seokpan/seokpan-app/blob/main/README.md)
* [seokpan-docs README](https://github.com/seokpan/seokpan-docs/blob/main/README.md)

---

## 5. Ansible Automation

Infrastructure 구성은 Ansible을 기반으로 자동화합니다.

기본적인 자동화 구조는 다음과 같습니다.

```text
Inventory
    │
    ▼
Playbook
    │
    ▼
Role
    │
    ├── Tasks
    ├── Templates
    ├── Handlers
    ├── Files
    └── Variables
    │
    ▼
Target Host
```

Infrastructure 변경은 가능한 한 **재현 가능한 Ansible 코드**로 관리하는 것을 기본 방향으로 합니다.

현재 자동화 대상에는 다음 영역이 포함됩니다.

```text
Common Configuration
        │
        ▼
Network / VRouter / Routing
        │
        ▼
Firewall
        │
        ▼
Load Balancer / VIP
        │
        ▼
Container Runtime
        │
        ▼
Kubernetes Bootstrap
        │
        ▼
Infrastructure Services
        │
        ▼
Validation
```

Ansible 자동화 및 테스트 설계에 대한 프로젝트 기준은 다음 문서를 참고합니다.

* [Ansible 자동화·테스트 설계](https://github.com/seokpan/seokpan-docs/blob/main/06_SeokPan_Ansible_%EC%9E%90%EB%8F%99%ED%99%94_%ED%85%8C%EC%8A%A4%ED%8A%B8_%EC%84%A4%EA%B3%84.pdf)
* [Ansible Inventory](https://github.com/seokpan/seokpan-infra/tree/main/ansible/inventory)
* [Ansible Playbooks](https://github.com/seokpan/seokpan-infra/tree/main/ansible/playbooks)
* [Ansible Roles](https://github.com/seokpan/seokpan-infra/tree/main/ansible/roles)

---

## 6. Repository Structure

현재 Infrastructure 자동화 자산은 `ansible/` 아래에서 관리합니다.

```text
seokpan-infra/
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
│
├── ansible/
│   ├── bootstrap/
│   │
│   ├── inventory/
│   │
│   ├── playbooks/
│   │
│   ├── roles/
│   │
│   ├── ansible.cfg
│   ├── requirements.txt
│   └── requirements.yml
│
├── .gitignore
└── README.md
```

각 영역의 역할은 다음과 같습니다.

| 경로                       | 역할                            |
| ------------------------ | ----------------------------- |
| `ansible/bootstrap/`     | Ansible 실행 환경 초기 구성           |
| `ansible/inventory/`     | 대상 Host 및 환경별 변수              |
| `ansible/playbooks/`     | Infrastructure 작업 실행 단위       |
| `ansible/roles/`         | 기능별 자동화 구현                    |
| `ansible/ansible.cfg`    | Ansible 실행 설정                 |
| `ansible/requirements.*` | Ansible Dependency 관리         |
| `.github/`               | Issue / Pull Request Workflow |

---

## 7. Infrastructure Deployment Flow

Infrastructure 구성은 구성요소 간 의존관계를 고려하여 단계적으로 진행합니다.

```text
Bootstrap
   │
   ▼
Common Host Configuration
   │
   ▼
Network / VRouter / Routing
   │
   ▼
Firewall
   │
   ▼
Load Balancer / VIP
   │
   ▼
Container Runtime
   │
   ▼
Kubernetes Bootstrap
   │
   ▼
Infrastructure Services
   │
   ├── Database
   ├── Registry
   ├── Storage
   └── 기타 Infrastructure
   │
   ▼
Validation
```

실제 프로젝트의 구현 순서 및 현재 적용 기준은 다음 문서를 우선하여 확인합니다.

* [MVP Implementation Baseline](https://github.com/seokpan/seokpan-docs/blob/main/MVP_IMPLEMENTATION_BASELINE.md)
* [Project Changes](https://github.com/seokpan/seokpan-docs/blob/main/PROJECT_CHANGES.md)

---

## 8. Working Directory

Ansible 작업은 `ansible/` 디렉터리를 기준으로 수행합니다.

```bash
cd ansible
```

기본적인 Playbook 실행 형태는 다음과 같습니다.

```bash
ansible-playbook -i inventory/hosts.yml playbooks/<playbook>.yml
```

구체적인 실행 방법은 각 Playbook 또는 Role의 README와 작업 문서를 참고합니다.

* [Playbooks](https://github.com/seokpan/seokpan-infra/tree/main/ansible/playbooks)
* [Roles](https://github.com/seokpan/seokpan-infra/tree/main/ansible/roles)

---

## 9. Validation

Infrastructure 자동화는 Ansible 실행 결과만으로 완료 여부를 판단하지 않습니다.

```text
Automation
    │
    ▼
Configuration Applied
    │
    ▼
Service / Network Validation
    │
    ▼
Integration Validation
    │
    ▼
Operational Validation
```

즉,

> **Ansible이 성공했다 = Infrastructure가 정상이다**

로 판단하지 않고 실제 Host, Network, Service 및 구성요소 간 연결 상태를 함께 확인합니다.

세부 검증 기준과 테스트 결과는 프로젝트 Documentation 및 각 Issue / Pull Request에서 확인합니다.

* [Ansible 자동화·테스트 설계](https://github.com/seokpan/seokpan-docs/blob/main/06_SeokPan_Ansible_%EC%9E%90%EB%8F%99%ED%99%94_%ED%85%8C%EC%8A%A4%ED%8A%B8_%EC%84%A4%EA%B3%84.pdf)
* [Troubleshooting](https://github.com/seokpan/seokpan-docs/tree/main/troubleshooting)

---

## 10. Runtime과 Automation의 구분

현재 프로젝트에서는 **실제 Runtime Infrastructure 구성과 Ansible Automation을 병행하여 개발**하고 있습니다.

따라서 다음 두 가지 상태를 구분합니다.

```text
Runtime Status
    │
    └── 실제 Infrastructure가 구성되어 있는가?

Automation Status
    │
    └── Ansible을 통해 재현 가능한가?
```

특정 Infrastructure가 실제 환경에 구성되어 있다고 해서 해당 환경 전체가 Ansible만으로 재현 가능하다는 의미는 아닙니다.

반대로 특정 Role이나 Playbook이 존재한다고 해서 해당 기능의 자동화가 검증 완료되었다는 의미도 아닙니다.

현재 자동화 상태는 실제 코드와 Issue / Pull Request의 검증 결과를 기준으로 판단합니다.

---

## 11. Security

Infrastructure Repository에는 민감정보를 평문으로 저장하지 않습니다.

주요 대상:

* Password
* Token
* Private Key
* Database Credential
* kubeconfig Credential
* Kubernetes Secret 값

Ansible에서 사용하는 민감정보는 Ansible Vault 등의 방식을 사용하여 관리합니다.

* [Ansible Inventory](https://github.com/seokpan/seokpan-infra/tree/main/ansible/inventory)
* [Ansible Vault 관련 구현](https://github.com/seokpan/seokpan-infra/search?q=vault&type=code)

---

## 12. Documentation

프로젝트 전체의 상세 설계와 구현 기준은 `seokpan-docs`에서 관리합니다.

README에서는 Infrastructure의 전체 흐름만 설명하고, 세부 설계·구현·검증 내용은 해당 Documentation으로 연결합니다.

### 주요 참고 문서

#### Architecture

* [논리 Architecture](https://github.com/seokpan/seokpan-docs/blob/main/04_SeokPan_%EA%B8%B0%EC%88%A0_%EB%B9%84%EA%B5%90_%EB%B0%8F_%EB%85%BC%EB%A6%AC_%EC%95%84%ED%82%A4%ED%85%8D%EC%B2%98.pdf)
* [물리 Architecture](https://github.com/seokpan/seokpan-docs/blob/main/05_SeokPan_%EB%AC%BC%EB%A6%AC_%EC%95%84%ED%82%A4%ED%83%9D%EC%B2%98.pdf)
* [Architecture 디렉터리](https://github.com/seokpan/seokpan-docs/tree/main/logical-architecture)

#### Implementation

* [MVP Implementation Baseline](https://github.com/seokpan/seokpan-docs/blob/main/MVP_IMPLEMENTATION_BASELINE.md)
* [Project Changes](https://github.com/seokpan/seokpan-docs/blob/main/PROJECT_CHANGES.md)

#### Ansible

* [Ansible 자동화·테스트 설계](https://github.com/seokpan/seokpan-docs/blob/main/06_SeokPan_Ansible_%EC%9E%90%EB%8F%99%ED%99%94_%ED%85%8C%EC%8A%A4%ED%8A%B8_%EC%84%A4%EA%B3%84.pdf)
* [Infrastructure Inventory](https://github.com/seokpan/seokpan-infra/tree/main/ansible/inventory)
* [Infrastructure Playbooks](https://github.com/seokpan/seokpan-infra/tree/main/ansible/playbooks)
* [Infrastructure Roles](https://github.com/seokpan/seokpan-infra/tree/main/ansible/roles)

#### Troubleshooting

* [Troubleshooting 문서](https://github.com/seokpan/seokpan-docs/tree/main/troubleshooting)

---

## 13. Related Repositories

프로젝트 관련 Repository는 다음과 같습니다.

### Infrastructure

[seokpan-infra](https://github.com/seokpan/seokpan-infra/tree/main)

Host, VM, Network, Infrastructure 및 Ansible Automation을 관리합니다.

### GitOps

[seokpan-gitops](https://github.com/seokpan/seokpan-gitops)

Kubernetes에서 관리되는 Application 및 Platform의 Desired State와 Argo CD 구성을 관리합니다.

### Application

[seokpan-app](https://github.com/seokpan/seokpan-app)

Frontend / Backend Application Source와 Application Test를 관리합니다.

### Documentation

[seokpan-docs](https://github.com/seokpan/seokpan-docs)

프로젝트 기획, Architecture, Implementation Baseline, 변경 이력 및 Troubleshooting 등 프로젝트 전반의 공용 문서를 관리합니다.

---

## 14. Collaboration Workflow

Infrastructure 변경은 다음 Workflow를 기본으로 합니다.

```text
Issue
  │
  ▼
Branch
  │
  ▼
Implementation
  │
  ▼
Commit
  │
  ▼
Pull Request
  │
  ▼
Review
  │
  ▼
Validation
  │
  ▼
Squash Merge
  │
  ▼
main
```

변경사항에 대한 상세 내용과 검증 결과는 해당 Issue / Pull Request에서 확인할 수 있습니다.

---

## 15. Project Status

현재 프로젝트는 **실제 Infrastructure Runtime 구성과 Ansible 자동화를 병행하여 구축하는 단계**입니다.

따라서 기능별 현재 상태는 다음 두 가지를 기준으로 판단합니다.

* 실제 Runtime 구성 여부
* Ansible 자동화 및 검증 여부

전체 프로젝트의 현재 구현 기준은 다음 문서를 참고합니다.

* [MVP Implementation Baseline](https://github.com/seokpan/seokpan-docs/blob/main/MVP_IMPLEMENTATION_BASELINE.md)
* [Project Changes](https://github.com/seokpan/seokpan-docs/blob/main/PROJECT_CHANGES.md)

---

## Reference

프로젝트 전체 흐름을 처음 확인하는 경우 다음 순서로 확인하는 것을 권장합니다.

```text
① seokpan-infra README
        │
        ▼
② seokpan-docs
   Architecture / Implementation Baseline
        │
        ▼
③ seokpan-infra
   Inventory / Playbook / Role
        │
        ▼
④ seokpan-gitops
   Kubernetes Desired State
        │
        ▼
⑤ seokpan-app
   Application Source
```

### Quick Links

* [Infrastructure Repository](https://github.com/seokpan/seokpan-infra/tree/main)
* [Infrastructure Inventory](https://github.com/seokpan/seokpan-infra/tree/main/ansible/inventory)
* [Infrastructure Playbooks](https://github.com/seokpan/seokpan-infra/tree/main/ansible/playbooks)
* [Infrastructure Roles](https://github.com/seokpan/seokpan-infra/tree/main/ansible/roles)
* [Project Documentation](https://github.com/seokpan/seokpan-docs)
* [Logical Architecture](https://github.com/seokpan/seokpan-docs/tree/main/logical-architecture)
* [Physical Architecture](https://github.com/seokpan/seokpan-docs/tree/main/physical-architecture)
* [MVP Implementation Baseline](https://github.com/seokpan/seokpan-docs/blob/main/MVP_IMPLEMENTATION_BASELINE.md)
* [Project Changes](https://github.com/seokpan/seokpan-docs/blob/main/PROJECT_CHANGES.md)
* [GitOps Repository](https://github.com/seokpan/seokpan-gitops)
* [Application Repository](https://github.com/seokpan/seokpan-app)
