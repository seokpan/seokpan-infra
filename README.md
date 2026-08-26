# seokpan-infra

석판팀 1차 프로젝트의 On-premise 인프라 구성과 Ansible 자동화 자산을 관리하는 Repository입니다.

## Repository Structure

```text
seokpan-infra/
├── ansible/
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
├── .gitignore
└── README.md
```

## Current Scope

현재 MVP 기반 인프라 구축과 Ansible 자동화를 진행하고 있습니다.

현재 실제 기반 인프라에서는 다음 영역까지 구성되어 있습니다.

* MVP 16VM 기반
* VRouter 및 Static Routing
* Kubernetes 기본 Cluster
* Calico
* Common VIP / HAProxy
* MariaDB / MaxScale

Ansible 자동화는 다음 영역을 중심으로 구현이 진행되어 있습니다.

* VRouter Network / Static Routing
* VRouter Firewall
* HAProxy / Common VIP
* Kubernetes prerequisite
* containerd
* Kubernetes validation
* 공통 hostname 관리
* Kubernetes bootstrap 자동화 일부

실제 Runtime이 구축되어 있는 것과 Ansible만으로 처음부터 동일 환경을 재현할 수 있는 것은 구분합니다. 전체 인프라의 재현 가능한 자동화는 현재 진행 중입니다.

## Working Directory

Ansible 작업은 Repository의 `ansible/` 디렉터리를 기준으로 수행합니다.

```bash
cd ansible
```

## Security

Password, Token, Private Key, kubeconfig credential 등 민감정보는 Repository에 저장하지 않습니다.

