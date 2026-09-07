# seokpan-infra

석판팀 1차 프로젝트의 **On-premise 인프라 구성과 Ansible 자동화 자산**을 관리하는 Repository입니다.

Infrastructure 환경의 구성 요소와 Ansible 자동화 흐름을 한 곳에서 확인할 수 있도록 관리하며, 세부적인 설계·구성·검증 내용은 프로젝트 문서와 각 Repository에서 관리합니다.

---

## Architecture

### Logical Architecture

프로젝트 전체 서비스와 인프라 구성 요소 간의 관계를 나타낸 논리 아키텍처입니다.

![SeokPan 전체 논리 아키텍처](../seokpan-docs/logical-architecture/01_SeokPan_전체%20논리%20아키텍처.png)

> 전체 서비스 구조와 구성 요소 간 관계는 [seokpan-docs](https://github.com/seokpan/seokpan-docs)의 Logical Architecture 문서를 참고합니다.

### Physical Architecture

Physical Server와 VM을 기반으로 구성된 실제 인프라 배치 구조입니다.

![SeokPan 전체 물리 아키텍처](../seokpan-docs/physical-architecture/01_SeokPan_전체%20물리%20아키텍처.png)

> Physical Server, VM, Network, HA 구성에 대한 상세 내용은 [seokpan-docs](https://github.com/seokpan/seokpan-docs)의 Physical Architecture 문서를 참고합니다.

---

## Infrastructure Scope

`seokpan-infra`는 다음과 같은 Infrastructure 영역을 담당합니다.

| 영역                 | 주요 구성                                           |
| ------------------ | ----------------------------------------------- |
| Network            | VRouter, Static Routing, Network Configuration  |
| Firewall           | Firewalld / Network Security                    |
| Load Balancing     | HAProxy, Common VIP                             |
| Kubernetes         | Cluster Bootstrap, Node Configuration, Calico   |
| Database           | MariaDB, MaxScale                               |
| Storage / Backup   | NFS, MariaDB Backup / Transfer                  |
| Container Runtime  | containerd                                      |
| Common             | Hostname, Hosts, Time Synchronization, CA Trust |
| Platform Bootstrap | Harbor, Jenkins, Argo CD 등 초기 구성                |

---

## Infrastructure Flow

전체적인 Infrastructure 구성 흐름은 다음과 같습니다.

```text
Physical Server
      │
      ▼
   Virtual Machine
      │
      ▼
VRouter / Network / Firewall
      │
      ▼
Load Balancer / Common VIP
      │
      ▼
Kubernetes Cluster
      │
      ├── Control Plane
      └── Worker
            │
            ├── Application
            ├── Redis
            └── Platform / Observability
                  
Database
  ├── MariaDB
  └── MaxScale

Storage / Backup
  └── NFS / MariaDB Backup
```

`seokpan-infra`는 위 Infrastructure 환경을 **Ansible을 통해 구성하고 반복 가능한 형태로 자동화**하는 것을 주요 목적으로 합니다.

---

## Ansible Automation Flow

Ansible 작업은 `ansible/` 디렉터리를 기준으로 수행합니다.

```text
Inventory
   │
   ▼
Playbook
   │
   ▼
Role
   │
   ▼
Target Host
   │
   ▼
Infrastructure Configuration
   │
   ▼
Validation
```

### 주요 구성

```text
ansible/
├── inventory/     # 대상 Host 및 변수 관리
├── playbooks/     # Infrastructure 작업 단위
├── roles/         # 실제 구성 및 자동화 로직
├── bootstrap/     # Ansible 실행 환경 초기화
├── ansible.cfg
└── requirements.*
```

Playbook은 작업 목적을 정의하고, 실제 Host 구성은 Role을 통해 수행합니다.

---

## Repository Structure

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
│   ├── ansible.cfg
│   └── requirements.*
│
├── .gitignore
└── README.md
```

### Directory Responsibility

| Directory           | Responsibility             |
| ------------------- | -------------------------- |
| `ansible/inventory` | Host 및 환경별 변수 관리           |
| `ansible/playbooks` | Infrastructure 작업 실행 단위    |
| `ansible/roles`     | 실제 서버 구성 및 자동화 로직          |
| `ansible/bootstrap` | Ansible 실행 환경 및 초기 설정      |
| `.github`           | Issue / Pull Request 협업 규칙 |

---

## Repository Boundary

프로젝트는 Repository별 책임을 분리하여 관리합니다.

```text
                    SeokPan Project
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
  seokpan-infra     seokpan-gitops     seokpan-app
        │                 │                 │
        │                 │                 │
 Infrastructure      Kubernetes        Application
 Automation          Desired State     Source Code
        │                 │                 │
        └────────────┬────┴─────────────────┘
                     │
                     ▼
                seokpan-docs
             Project Documentation
```

### Repository별 역할

* **seokpan-infra**

  * Host / VM / Network
  * Firewall / Load Balancer
  * Kubernetes Bootstrap
  * Database / Storage
  * Infrastructure Ansible Automation

* **seokpan-gitops**

  * Kubernetes Desired State
  * Argo CD Application
  * Application / Platform / CI/CD / Observability Manifest

* **seokpan-app**

  * Frontend
  * Backend
  * Application Logic
  * Application Runtime Source

* **seokpan-docs**

  * 프로젝트 요구사항
  * 논리 / 물리 아키텍처
  * 설계 및 자동화 문서
  * 프로젝트 변경 이력
  * Troubleshooting / Mentoring 자료

---

## Working Directory

Ansible 작업은 `ansible/` 디렉터리를 기준으로 수행합니다.

```bash
cd ansible
```

실행 예시:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/<playbook>.yml
```

실제 실행 방법과 각 Role의 상세 구성은 해당 Playbook 및 Role의 README를 참고합니다.

---

## Documentation

Infrastructure의 전체 설계와 세부 구현 내용은 별도의 문서 Repository에서 관리합니다.

### Architecture

* Logical Architecture

  * 전체 논리 아키텍처
  * 서비스 처리 흐름
  * Kubernetes Cluster 구조
  * 서비스 Traffic 흐름
  * Application Runtime 구조

* Physical Architecture

  * 전체 Physical Architecture
  * Physical Server / VM 배치
  * Network Architecture
  * HA / Failure Domain

### Automation

Ansible 자동화 설계와 테스트 기준은 `seokpan-docs`의 Ansible 자동화 문서를 참고합니다.

### Troubleshooting

구성 과정에서 발생한 문제와 해결 과정은 `seokpan-docs`의 Troubleshooting 문서를 참고합니다.

---

## Related Repositories

| Repository       | Description                         |
| ---------------- | ----------------------------------- |
| `seokpan-infra`  | Infrastructure / Ansible Automation |
| `seokpan-gitops` | Kubernetes / Argo CD Desired State  |
| `seokpan-app`    | Application Source                  |
| `seokpan-docs`   | Project Documentation               |

---

## Collaboration Workflow

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
Squash Merge
  │
  ▼
main
```

작업은 Issue 단위로 관리하며, 변경 사항은 Pull Request를 통해 검토 후 `main`에 반영합니다.

---

## Security

다음과 같은 민감정보는 Repository에 직접 저장하지 않습니다.

* Password
* Token
* Private Key
* kubeconfig Credential
* 기타 인증 정보

필요한 Secret 및 민감정보는 Ansible Vault 등의 별도 관리 방식을 사용합니다.
