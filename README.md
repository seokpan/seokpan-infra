# seokpan-infra

**「石나가는 판단(Seokpan)」 프로젝트의 서버·네트워크·데이터베이스·Kubernetes 기반 인프라를 Ansible로 자동화하는 저장소입니다.** 온프레미스 VMware/CentOS Stream 9 환경(4 PC, 다수 VM) 위에 라우팅/방화벽부터 K8s 클러스터, MariaDB/MaxScale, NFS, 백업·DR, Observability Exporter까지 코드로 관리합니다.

실제 애플리케이션 배포 상태는 [`seokpan-gitops`](https://github.com/seokpan/seokpan-gitops), 애플리케이션 소스는 [`seokpan-app`](https://github.com/seokpan/seokpan-app), 설계·검증 문서는 [`seokpan-docs`](https://github.com/seokpan/seokpan-docs)에서 관리합니다.

## 인프라 구성

![Ansible 관리 대상인 16개 VM의 역할별 구성](docs/images/infrastructure-scope.svg)

[Inventory](ansible/inventory/hosts.yml)에 정의된 16개 VM을 역할별로 묶은 그림입니다. Control Plane 3대·Worker 2대로 Kubernetes를 구성하고, MariaDB·MaxScale·Harbor·NFS는 별도 VM에서 운영합니다. 1차 MVP의 LB와 MaxScale은 각각 1대입니다.

Ansible은 서버와 클러스터 기반을 구성하고, 클러스터에 배포할 애플리케이션·플랫폼 리소스는 `seokpan-gitops`가 관리합니다. 그림은 관리 대상의 구분이며 패킷 경로나 물리 호스트별 배치를 나타내지는 않습니다.

## 담당과 역할

| 담당자 | 영역 | 주요 작업 |
|---|---|---|
| **정태훈** (팀장) | Kubernetes, 코드 리뷰 | `kubeadm_*`, `container_runtime`, `calico`, `k8s_addons` |
| **이유빈** | Network / Ansible 실행환경 | `vrouter_network`, `vrouter_firewall`, `lb_network`, `lb_haproxy`, `common_hosts` |
| **최유준** | Harbor / Argo CD / CI/CD / Observability, `internal_ca`·`tls_deploy` 소유 | `harbor`, `argocd_bootstrap`, `internal_ca`, `tls_deploy`, VRouter·Controller Exporter 적용·관측 연동 |
| **김상희** | Data, Storage & Recovery | `mariadb*`, `maxscale*`, `nfs_server`, `backup_transfer`, `etcd_dr`, DB·NFS Exporter Role |

Exporter Role 구현과 대상 VM 적용·관측 연동은 구분합니다. `node_exporter_linux`·`mysqld_exporter`의 Role Owner와 [VRouter·Controller 적용 Playbook](ansible/playbooks/install_node_exporter_external.yml)의 작성·적용 범위가 다르므로, Exporter 전체를 한 담당자의 단독 작업으로 묶지 않습니다. 구체적인 구현·실행·리뷰 근거는 해당 Role과 Issue/PR을 따릅니다.

## 저장소 구조

```text
seokpan-infra/
├── .github/                  # Issue/PR 템플릿
├── docs/images/              # 인프라 구성도
└── ansible/
    ├── ansible.cfg
    ├── ansible-safe-run       # 안전 실행 래퍼 스크립트
    ├── bootstrap/             # 최초 실행 준비(컬렉션/버전 락 등)
    ├── inventory/             # hosts.yml, group_vars/, host_vars/
    ├── playbooks/             # 역할별 실행 진입점
    ├── roles/                 # 기능 단위 자동화 코드
    ├── tools/
    ├── requirements.txt
    └── requirements.yml
```

## 핵심 기술과 구현 영역

VMware·CentOS Stream 9 VM을 Ansible로 구성하고, HAProxy·kubeadm·containerd·Calico·MariaDB·MaxScale·NFS를 영역별 Role로 관리합니다. 전체 목록 대신 대표 코드 위치만 안내합니다. 각 Role의 세부 태스크는 링크된 디렉터리에서 확인할 수 있습니다.

| 영역 | 대표 Role / Playbook | 코드 |
|---|---|---|
| 네트워크 · LB | `vrouter_network`, `vrouter_firewall`, `lb_haproxy`, `resolver_policy`, `coredns_records` | [roles/](ansible/roles) |
| Kubernetes 부트스트랩 | `kubernetes_prereq`, `container_runtime`, `calico`, `kubeadm_control_plane(_join)`, `kubeadm_worker`, `k8s_addons` | [roles/](ansible/roles) |
| 인증서 · TLS | `internal_ca`, `tls_deploy`, `ca_trust`, `certbot_client`, `gateway_tls` | [roles/](ansible/roles) |
| 데이터베이스 (김상희) | `mariadb`, `mariadb_account`, `mariadb_database`, `mariadb_user`, `maxscale` | [roles/mariadb](ansible/roles/mariadb), [roles/maxscale](ansible/roles/maxscale) |
| 백업 · DR (김상희) | `backup_transfer`, `etcd_dr`, `etcd_tools` | [playbooks/mariadb_dr_recovery.yml](ansible/playbooks/mariadb_dr_recovery.yml), [playbooks/mariadb_restore_chain.yml](ansible/playbooks/mariadb_restore_chain.yml), [playbooks/etcd_dr_recovery.yml](ansible/playbooks/etcd_dr_recovery.yml) |
| 저장소 (김상희) | `nfs_server` | [roles/nfs_server](ansible/roles/nfs_server) |
| CI/CD 연동 시크릿 | `harbor`, `jenkins_secrets`, `argocd_bootstrap`, `argocd_webhook_secret`, `application_registry_secret`, `backend_db_secrets` | [roles/](ansible/roles) |
| Observability | `node_exporter_linux`, `mysqld_exporter`, `maxscale_exporter`, `alertmanager_secret` | [roles/](ansible/roles) |

> DB Primary/Replica처럼 실행 중 바뀔 수 있는 상태는 기록 시점과 실제 작업 시점을 구분합니다. [1차 종료 시점 상태](https://github.com/seokpan/seokpan-docs/blob/main/CURRENT_STATE.md)와 관련 실행 근거를 먼저 읽고, 변경 작업 전에는 대상 서버의 현재 역할을 다시 확인합니다. 과거 스냅샷을 현재 Runtime 조회로 대신하지 않습니다.

## 실행 방법

작업 디렉터리는 저장소 루트 아래의 `ansible/`입니다. Controller에 고정 버전 Python이 준비되어 있어야 하며, 실행환경만 구성·검증하는 방법은 [Bootstrap 안내](ansible/bootstrap/README.md)를 따릅니다.

허용 사용자 `ansible`·`jth`·`ksh`·`cyj`가 자신의 checkout을 처음 준비할 때는 다음 진입점을 사용합니다. `ars-setup`은 `root` 또는 `sudo` 실행을 거부하며, Project 환경 준비·Kernel Keyring Credential 등록·`ars` alias 등록을 수행합니다.

```bash
cd ansible
./tools/ars-setup
```

이미 준비된 사용자 환경에서 Credential만 다시 등록해야 할 때는 [`./tools/credential-init`](ansible/tools/credential-init)을 사용합니다. 두 스크립트는 `source`로 실행하지 않고, Credential을 명령행 인자로 전달하지 않습니다.

일반 Playbook 실행의 진입점은 [`ansible-safe-run`](ansible/ansible-safe-run)입니다. 다음은 선택한 Playbook을 Ansible로 해석하는 예시이며 `<playbook>`은 검토한 실제 파일명으로 바꿉니다.

```bash
./ansible-safe-run playbooks/<playbook>.yml --inspect-only
```

`--inspect-only`는 대상 접속·Check Mode·실제 적용 성공을 의미하지 않습니다. 실제 적용은 대상·옵션·변경 영향·복구 경로를 검토하고 Runner의 사전 검사와 승인 절차를 통과한 뒤 진행합니다. 현재 Revision에서 정책상 차단되는 실행은 직접 `ansible-playbook`으로 우회하지 않습니다.

`db_operator_login.yml`의 전용 수동 경로와 일부 비지원 테스트는 Runner의 `MANUAL_ONLY`·`UNSUPPORTED_SPECIAL_TESTS` 및 역할별 Runbook을 확인합니다. 모든 Playbook을 같은 실행 예시로 일괄 치환하지 않습니다. 또한 `--check --diff`를 무해한 공통 검사로 취급하지 않습니다. `check_mode: false` 태스크는 Check Mode에서도 실행될 수 있고 Diff는 민감 정보를 노출할 수 있습니다([Ansible 공식 안내](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)).

Vault 입력 파일은 `ansible/inventory/group_vars/all/vault.yml`이며, `ansible/`에서의 상대 경로는 `inventory/group_vars/all/vault.yml`입니다. 실제 비밀번호·Token·Private Key는 Git과 로그에 평문으로 남기지 않습니다. CA 파일·Kubernetes Secret·실행 Credential의 공급 위치는 각 Role에 정의된 공급 경로를 따르며 모두 Vault 파일에만 저장된다고 가정하지 않습니다. `no_log`·`diff: false` 등 보호와 `.gitignore`는 적용 범위를 확인하고 사용합니다.

## 저장소 간 관계

| 저장소 | 역할 |
|---|---|
| `seokpan-infra` | 서버 / 네트워크 / DB / K8s 부트스트랩 자동화 (본 저장소) |
| `seokpan-gitops` | Kubernetes Desired State, Argo CD |
| `seokpan-app` | 애플리케이션 소스 (Frontend/Backend) |
| `seokpan-docs` | 아키텍처 설계, 트러블슈팅, 검증 기록 |

## 관련 문서 (`seokpan-docs`)

- [논리 아키텍처](https://github.com/seokpan/seokpan-docs/tree/main/logical-architecture) · [물리 아키텍처](https://github.com/seokpan/seokpan-docs/tree/main/physical-architecture)
- [MVP 구현 기준](https://github.com/seokpan/seokpan-docs/blob/main/MVP_IMPLEMENTATION_BASELINE.md)
- [프로젝트 변경 기록](https://github.com/seokpan/seokpan-docs/blob/main/PROJECT_CHANGES.md)
- [트러블슈팅 모음](https://github.com/seokpan/seokpan-docs/tree/main/troubleshooting)
- [GitHub 협업 및 Repository 운영](<https://github.com/seokpan/seokpan-docs/tree/main/10_GitHub_협업_및_Repository_운영>)

## 작업 방법

Issue 등록 → 작업 브랜치 → 변경 범위에 맞는 검증 → 작은 단위 PR → 리뷰 → `main` merge 순으로 진행합니다. 문서·주석 변경에는 Source·diff 대조를, 실제 인프라 변경에는 승인된 대상의 적용·회귀검증을 기록합니다. 브랜치 생성/커밋/push 등 Git 조작은 팀원이 직접 수행하고, PR/Issue 본문은 사전 확인 후 등록하는 것을 원칙으로 합니다.
