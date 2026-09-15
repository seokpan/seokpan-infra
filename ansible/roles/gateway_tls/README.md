# Gateway TLS 운영 절차

Gateway TLS Secret Provider는 기본 `internal_ca`와 운영 Desired State인
`external_acme` Source를 구분한다. ACME 인증서 발급과 Secret 반영은
Ansible Controller에서만 수행한다.

## 1. Certbot 설치

Ansible Project 고정 환경에서 실행한다. 시스템 Python 3.9와 Project
Virtualenv를 변경하지 않고 `/usr/bin/python3.12`로 `/opt/certbot`을 만든다.

```bash
cd ~/work/seokpan-infra/ansible
.venv/bin/ansible-playbook playbooks/certbot_client.yml \
  --ask-vault-pass --ask-become-pass
```

## 2. Staging DNS-01

```bash
sudo /usr/local/sbin/gateway-certbot-manual staging 'ACME_EMAIL'
sudo /usr/local/sbin/gateway-certbot-verify staging
```

발급 도구가 제시하는 `_acme-challenge.game.seokpan.soldesk.store` TXT 값을
Gabia에 등록하고 공개 Resolver에서 같은 값이 확인된 뒤 Enter를 누른다.
Staging 결과는 `/etc/letsencrypt-staging`에만 저장하며 Live Kubernetes
Secret에는 적용하지 않는다. 완료 후 Staging TXT Record를 제거한다.

## 3. Production 발급과 적용

PR 병합 뒤 Production 인증서를 한 번 발급하고 검증한다.

```bash
sudo /usr/local/sbin/gateway-certbot-manual production 'ACME_EMAIL'
sudo /usr/local/sbin/gateway-certbot-verify production

cd ~/work/seokpan-infra/ansible
.venv/bin/ansible-playbook playbooks/gateway_tls.yml \
  --ask-vault-pass --ask-become-pass
```

Production TXT Record는 발급 완료 후 제거한다. `gateway_tls` Role은 SAN,
30일 이상 잔여 유효기간, Fullchain 정합성, Root 소유 0600 Private Key,
Certificate/Key Public Key 일치와 System Trust Chain을 확인한 뒤에만
`application/game-seokpan-tls`을 갱신한다.

## 4. 실패 시 Internal CA 복구

Production 적용 후 Gateway HTTPS 검증이 실패하면 기존 Internal CA 발급본으로
Secret을 되돌린다. Backend·Frontend Replica나 Route는 변경하지 않는다.

```bash
cd ~/work/seokpan-infra/ansible
.venv/bin/ansible-playbook playbooks/gateway_tls.yml \
  --ask-vault-pass --ask-become-pass \
  -e gateway_tls_source=internal_ca
```

복구 후 Gateway 인증서 Issuer가 `Seokpan Internal Root CA`인지 확인하고,
원인을 수정하기 전까지 External Source를 다시 적용하지 않는다. Desired State를
장기 복구해야 하면 `gateway_tls_source`를 되돌리는 별도 승인 PR을 만든다.

## 5. 갱신

Gabia DNS 자동화가 없으므로 자동 갱신 완료로 간주하지 않는다. 인증서 만료
30일 전에 Production 수동 DNS-01 발급·검증·Secret 적용과 Runtime Gate를
같은 순서로 반복한다. 인증서와 Private Key 내용은 Git·Issue·PR·일반 로그에
남기지 않는다.
