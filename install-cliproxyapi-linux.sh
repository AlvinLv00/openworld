#!/usr/bin/env bash
# CLIProxyAPI + official Management Center + Caddy. UTF-8, LF, Bash >= 4.
# Pinned to the versions used by the accompanying installation guide.
set -Eeuo pipefail
umask 077

action=install
app=/opt/cliproxyapi
domain=
project=cpa-t
port=8317
caddy_mode=auto
caddyfile=/etc/caddy/Caddyfile
origin_http=0
install_docker=0
open_firewall=0
image=eceasy/cli-proxy-api:v8.0.48
ui_version=v1.27.0
ui_sha=2ca7a226f8d2fa078fb52e12fd5b75762ded2dc585205d3da509ebfb17ea2adf
caddy_image=caddy:2.11.7-alpine
state_loaded=0

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: sudo bash install-cliproxyapi-linux.sh [ACTION] [OPTIONS]
Actions: install (default), verify, status, logs, restart, backup
Options (installation settings are retained on subsequent invocations):
  --domain NAME          CPA domain (prompted on first interactive install)
  --dir PATH             Default: /opt/cliproxyapi (absolute, no spaces)
  --project NAME         Default: cpa-t
  --port NUMBER          Local backend port, default: 8317
  --caddy MODE           auto | host | docker | none; default: auto
  --caddyfile PATH       Host systemd Caddyfile, default: /etc/caddy/Caddyfile
  --allow-origin-http    Serve origin HTTP + HTTPS for existing CF Flexible setups
  --install-docker       Install missing Docker CE/Compose from official repositories
  --open-firewall        Add HTTP/HTTPS to active firewalld or ufw; SSH is retained
  -h, --help             Show help

New hosts: Rocky/AlmaLinux/RHEL 8/9, Ubuntu 22.04/24.04/26.04, Debian 12/13.
CentOS 7: reuse an already working Docker + Compose only; no package bootstrap.
auto reuses an active systemd Caddy; otherwise starts Caddy in Docker.
Existing installations without this installer's marker are never overwritten.
No subscription login is performed; complete Claude/Codex OAuth in the Web UI.
HELP
}
trap 'printf "ERROR at line %s (exit %s). Persistent files have been retained.\n" "$LINENO" "$?" >&2' ERR
if [[ $# -eq 0 && -t 0 ]]; then
  printf '\n%s\n' '========== AlvinLv · CPA 管理 ==========' '1) 安装 / 继续安装' '2) 检查服务和访问' '3) 查看服务状态' '4) 查看服务日志' '5) 重启服务' '6) 备份配置和账号' '0) 退出'
  read -r -p '请选择 [1]: ' selection || die '输入结束'
  case ${selection:-1} in 1) action=install ;; 2) action=verify ;; 3) action=status ;; 4) action=logs ;; 5) action=restart ;; 6) action=backup ;; 0) exit 0 ;; *) die '无效选项' ;; esac
fi
if [[ $# -gt 0 && $1 != -* ]]; then action=$1; shift; fi
while (($#)); do
  case $1 in
    --domain|--dir|--project|--port|--caddy|--caddyfile)
      (($# >= 2)) && [[ -n $2 ]] || die "Missing value for $1"
      case $1 in
        --domain) domain=$2 ;; --dir) app=$2 ;; --project) project=$2 ;;
        --port) port=$2 ;; --caddy) caddy_mode=$2 ;; --caddyfile) caddyfile=$2 ;;
      esac
      shift 2 ;;
    --install-docker) install_docker=1; shift ;;
    --open-firewall) open_firewall=1; shift ;;
    --allow-origin-http) origin_http=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
case $action in install|verify|status|logs|restart|backup) ;; *) die "Unknown action: $action" ;; esac
[[ $EUID -eq 0 ]] || die 'Run with sudo or as root.'
[[ $app =~ ^/[a-zA-Z0-9/_-]+$ && $app != / && $app != *..* ]] || die 'Invalid --dir; use an absolute path without spaces or dot segments.'
[[ ! -L $app ]] || die 'The application directory must not be a symlink.'
state=$app/.installer.env
if [[ -e $app ]]; then
  [[ -f $state && ! -L $state && $(stat -c %u "$state") == 0 ]] || die "Existing directory is not owned by this installer: $app. Use the documented maintenance commands, or choose another --dir/project/port."
  # Only root may write the installation marker and its parent directory.
  [[ $(stat -c %a "$app") == 700 && $(stat -c %a "$state") == 600 ]] || die 'Unsafe installation marker permissions.'
  # shellcheck disable=SC1090
  . "$state"
  state_loaded=1
  say 'Existing installation settings loaded; credentials and account files will be retained.'
elif [[ $action != install ]]; then
  die "No managed installation found at $app"
fi
# WIZARD_BEGIN
prompt_install_options() {
  local answer
  printf '\n========== AlvinLv · CPA 安装向导 ==========\n'
  read -r -p 'CPA 管理域名（例如 cpa.example.com）: ' domain || die '输入结束'
  [[ -n $domain ]] || die '域名不能为空。'
  printf '\n%s\n' 'Cloudflare 回源模式：' '1) 直连 / Full (strict)（默认；回源 HTTPS）' '2) Flexible（回源 HTTP）'
  read -r -p '请选择 [1]: ' answer || die '输入结束'
  case ${answer:-1} in
    1) origin_http=0 ;;
    2) origin_http=1; printf '%s\n' '提示：Flexible 下 Cloudflare 到 VPS 的管理凭据和请求不受 TLS 保护。' ;;
    *) die '无效的回源模式。' ;;
  esac
  if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    printf '%s\n' '未检测到 Docker 或 Compose；安装将配置 Docker 官方软件源并启用服务。'
    read -r -p '现在安装 Docker 和依赖吗？[y/N]: ' answer || die '输入结束'
    case $answer in y|Y) install_docker=1 ;; *) die '请先安装 Docker 和 Compose，再重新运行。' ;; esac
  fi
  printf '%s\n' '使用现有系统 Caddy（如有），否则使用容器 Caddy；防火墙不自动修改。'
}
# WIZARD_END
if [[ $action == install && $state_loaded == 0 && -z $domain ]]; then
  [[ -t 0 ]] || die '首次安装请交互运行脚本，或通过 --domain 指定域名。'
  prompt_install_options
fi
python_bin=
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; assert sys.version_info >= (2,7)' 2>/dev/null; then
    python_bin=$candidate; break
  fi
done
[[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,63}$ && $domain != *..* && ${#domain} -le 253 ]] || die 'Invalid DNS domain.'
[[ $project =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die 'Invalid Compose project name.'
[[ $port =~ ^[0-9]{1,5}$ ]] || die 'Invalid port.'
port=$((10#$port))
((port > 1024 && port < 65536 && port != 1455 && port != 54545)) || die 'Use an unreserved port between 1025 and 65535, excluding OAuth ports.'
case $caddy_mode in auto|host|docker|none) ;; *) die 'Invalid --caddy mode.' ;; esac
[[ $caddyfile =~ ^/[a-zA-Z0-9/_.-]+$ && $caddyfile != *..* ]] || die 'Invalid --caddyfile.'

install_dependencies() {
  [[ -r /etc/os-release ]] || die 'Missing /etc/os-release.'
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ $ID == centos && ${VERSION_ID%%.*} == 7 ]]; then
    die 'CentOS 7 package bootstrap is unsupported. Reuse preinstalled Docker, curl, openssl and Python 3, or use a maintained OS.'
  fi
  case $ID in
    rocky|almalinux|rhel)
      [[ ${VERSION_ID%%.*} == 8 || ${VERSION_ID%%.*} == 9 ]] || die 'Automatic RPM bootstrap supports major version 8/9.'
      dnf -y install ca-certificates curl openssl python3 iproute dnf-plugins-core
      if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        # Rocky's Docker guide uses the RHEL Docker CE repository.
        dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
        dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      fi ;;
    ubuntu|debian)
      case "$ID:$VERSION_ID" in ubuntu:22.04|ubuntu:24.04|ubuntu:26.04|debian:12|debian:13) ;; *) die 'Unsupported automatic apt bootstrap version.' ;; esac
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y ca-certificates curl openssl python3 iproute2
      if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        install -d -m 755 /etc/apt/keyrings
        curl -fsSL --retry 3 "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
        chmod 644 /etc/apt/keyrings/docker.asc
        printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
          "$(dpkg --print-architecture)" "$ID" "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker-cpa.list
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      fi ;;
    *) die "Automatic Docker installation is unsupported for $ID; preinstall Docker CE and dependencies." ;;
  esac
  systemctl enable --now docker
  python_bin=python3
}
if [[ $action == install && $install_docker == 1 ]]; then install_dependencies; fi
for command_name in docker curl openssl sha256sum ss; do
  command -v "$command_name" >/dev/null 2>&1 || die "Missing $command_name. Install prerequisites, or use --install-docker on a supported OS."
done
[[ -n $python_bin ]] || die 'Install python3 (existing CentOS 7 Python 2.7 is also supported for JSON parsing only).'
docker compose version >/dev/null
[[ $(docker info --format '{{.OSType}}') == linux ]] || die 'A running Linux Docker Engine is required.'

dc() { docker compose --project-directory "$app" -p "$project" -f "$app/compose.yaml" "$@"; }
authcurl() {
  local key=$1; shift
  # Compatible with CentOS 7 curl 7.29. Secrets are supplied on stdin.
  printf 'header = "Authorization: Bearer %s"\n' "$key" | curl -sS --max-time 30 -K - "$@"
}
load_keys() {
  [[ -f $app/secrets.env ]] || die 'Missing secrets.env; restore from backup.'
  # shellcheck disable=SC1090,SC1091
  . "$app/secrets.env"
  [[ $CPA_MANAGEMENT_KEY =~ ^cpa-admin-[a-f0-9]{48}$ && $CPA_CLIENT_KEY =~ ^sk-[a-f0-9]{64}$ ]] || die 'Invalid generated credentials file.'
}
check_http() {
  local expected=$1 label=$2 actual=$3
  say "$label: HTTP $actual (expected $expected)"
  [[ $expected == "$actual" ]] || die "HTTP verification failed: $label"
}
verify_local() {
  load_keys
  local base=http://127.0.0.1:$port
  check_http 200 local_ui "$(curl --noproxy '*' -sS --max-time 15 -o /dev/null -w '%{http_code}' "$base/management.html")"
  check_http 401 unauthenticated_models "$(curl --noproxy '*' -sS --max-time 15 -o /dev/null -w '%{http_code}' "$base/v1/models")"
  check_http 401 unauthenticated_management "$(curl --noproxy '*' -sS --max-time 15 -o /dev/null -w '%{http_code}' "$base/v8/management/config")"
  check_http 200 authenticated_management "$(authcurl "$CPA_MANAGEMENT_KEY" --noproxy '*' -o /dev/null -w '%{http_code}' "$base/v8/management/config")"
  check_http 200 authenticated_models "$(authcurl "$CPA_CLIENT_KEY" --noproxy '*' -o "$app/backups/models.last-check.json" -w '%{http_code}' "$base/v1/models")"
  "$python_bin" -c 'import json,sys; print("Available models: %d (zero is normal before OAuth)" % len(json.load(open(sys.argv[1])).get("data", [])))' "$app/backups/models.last-check.json"
}
verify_public() {
  [[ $caddy_mode != none ]] || return 0
  local base=https://$domain
  check_http 200 public_ui "$(curl -sS --max-time 30 -o /dev/null -w '%{http_code}' "$base/management.html")"
  check_http 401 public_management_without_key "$(curl -sS --max-time 30 -o /dev/null -w '%{http_code}' "$base/v8/management/config")"
  check_http 200 public_management_with_key "$(authcurl "$CPA_MANAGEMENT_KEY" -o /dev/null -w '%{http_code}' "$base/v8/management/config")"
  check_http 200 public_models_with_key "$(authcurl "$CPA_CLIENT_KEY" -o /dev/null -w '%{http_code}' "$base/v1/models")"
}
summary() {
  say "Management: https://$domain/management.html"
  say "API base URL: https://$domain/v1"
  say "Credentials (root only): $app/secrets.env"
  say "Installer version pins: $image | Management Center $ui_version | Caddy mode: $caddy_mode"
  say 'Claude/Codex accounts must be connected through OAuth in the Web UI.'
  if [[ $caddy_mode == none ]]; then say "No public proxy was configured. Local entry: http://127.0.0.1:$port/management.html"; fi
}

if [[ $action != install ]]; then
  case $action in
    verify) verify_local; verify_public; summary ;;
    status) dc ps; summary ;;
    logs) dc logs --tail 100 ;;
    restart) dc restart; verify_local; summary ;;
    backup)
      mkdir -p /var/backups
      backup_file="/var/backups/${project}-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
      tar -czf "$backup_file" -C "$(dirname "$app")" "$(basename "$app")"
      chmod 600 "$backup_file"
      say "Backup: $backup_file (contains account tokens and credentials). Host Caddy main file must be backed up separately."
      ;;
  esac
  exit 0
fi

if [[ $caddy_mode == auto ]]; then
  if command -v caddy >/dev/null 2>&1 && systemctl is-active --quiet caddy; then caddy_mode=host
  else caddy_mode=docker; fi
fi
if [[ $caddy_mode == host ]]; then
  command -v caddy >/dev/null 2>&1 || die 'Host Caddy binary not found.'
  systemctl is-active --quiet caddy || die 'Host Caddy must be managed by an active caddy.service.'
  [[ -f $caddyfile && ! -L $caddyfile ]] || die 'Host Caddyfile not found, or is a symlink.'
  # Verify the service really uses this file; caddy-api/JSON/--resume setups need manual integration.
  systemctl show caddy --property=ExecStart --value | grep -F -- "$caddyfile" >/dev/null || die 'caddy.service does not use --caddyfile path. Specify the actual file, or integrate Caddy manually with --caddy none.'
  caddy validate --config "$caddyfile" --adapter caddyfile >/dev/null
fi
if ((!state_loaded)); then
  if [[ -n $(ss -H -ltn "sport = :$port") ]]; then die "Local port $port is already listening."; fi
  if [[ -n $(docker ps -q --filter "label=com.docker.compose.project=$project") ]]; then die 'Compose project name is already in use; choose --project.'; fi
  if [[ $caddy_mode == docker && -n $(ss -H -ltn '( sport = :80 or sport = :443 )') ]]; then
    die 'Ports 80/443 are already in use. Reuse host Caddy or choose --caddy none and integrate your existing proxy.'
  fi
  if [[ $caddy_mode == host ]]; then
    existing_json=$(caddy adapt --config "$caddyfile" --adapter caddyfile 2>/dev/null)
    if printf '%s' "$existing_json" | "$python_bin" -c 'import json,sys; obj=json.load(sys.stdin); domain=sys.argv[1];
def found(x):
    if isinstance(x,dict):
        if domain in x.get("host",[]): return True
        return any(found(v) for v in x.values())
    return isinstance(x,list) and any(found(v) for v in x)
sys.exit(0 if found(obj) else 1)' "$domain"; then die "Host Caddy already has a route for $domain; refusing duplicate site."; fi
  fi
  install -d -m 700 "$app"
  printf 'domain=%s\nproject=%s\nport=%s\ncaddy_mode=%s\ncaddyfile=%s\norigin_http=%s\n' \
    "$domain" "$project" "$port" "$caddy_mode" "$caddyfile" "$origin_http" > "$state"
  chmod 600 "$state"
fi
for directory in config auths logs static backups caddy caddy-data caddy-config; do install -d -m 700 "$app/$directory"; done
if [[ ! -f $app/secrets.env ]]; then
  [[ ! -e $app/config/config.yaml ]] || die 'Configuration exists without credentials; restore secrets.env.'
  # bcrypt limit is 72 bytes; generated admin key is 58 ASCII bytes.
  printf 'CPA_MANAGEMENT_KEY=cpa-admin-%s\nCPA_CLIENT_KEY=sk-%s\n' \
    "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > "$app/secrets.env"
fi
chmod 600 "$app/secrets.env"
load_keys
if [[ ! -e $app/config/config.yaml ]]; then
  cat > "$app/config/config.yaml" <<CONFIG
config-version: 8
server:
  host: "0.0.0.0"
  port: 8317
  max-request-body-bytes: 16777216
access:
  api-keys:
    - "$CPA_CLIENT_KEY"
oauth:
  auth-dir: "/root/.cli-proxy-api"
management:
  allow-remote: true
  secret-key: "$CPA_MANAGEMENT_KEY"
  disable-control-panel: false
  disable-auto-update-panel: true
  panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"
observability:
  logs:
    debug: false
    logging-to-file: true
    logs-max-total-size-mb: 100
    error-logs-max-files: 10
    request-log: false
  usage:
    usage-statistics-enabled: true
CONFIG
fi
chmod 600 "$app/config/config.yaml"
if [[ ! -f $app/static/management.html ]]; then
  curl -fSL --retry 3 --connect-timeout 20 --max-time 300 \
    "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/$ui_version/management.html" \
    -o "$app/static/management.html.download"
  printf '%s  %s\n' "$ui_sha" "$app/static/management.html.download" | sha256sum -c -
  mv "$app/static/management.html.download" "$app/static/management.html"
else
  printf '%s  %s\n' "$ui_sha" "$app/static/management.html" | sha256sum -c -
fi
if [[ ! -e $app/caddy/Caddyfile ]]; then
  site_address=$domain
  ((origin_http == 0)) || site_address="http://$domain, https://$domain"
  cat > "$app/caddy/Caddyfile" <<CADDY
$site_address {
    @root path /
    redir @root /management.html 302
    header {
        Cache-Control "no-store"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "same-origin"
    }
    reverse_proxy 127.0.0.1:$port {
        flush_interval -1
        transport http {
            dial_timeout 10s
            response_header_timeout 600s
            keepalive 2m
        }
    }
}
CADDY
fi
if [[ ! -e $app/compose.yaml ]]; then
  # :Z labels only this installer's dedicated directories, never system paths.
  cat > "$app/compose.yaml" <<COMPOSE
services:
  cliproxyapi:
    image: $image
    restart: unless-stopped
    command: ["/CLIProxyAPI/CLIProxyAPI", "--config", "/CLIProxyAPI/config/config.yaml"]
    environment:
      TZ: Asia/Shanghai
      MANAGEMENT_STATIC_PATH: /CLIProxyAPI/static
    ports:
      - "127.0.0.1:$port:8317"
    volumes:
      - ./config:/CLIProxyAPI/config:Z
      - ./auths:/root/.cli-proxy-api:Z
      - ./logs:/CLIProxyAPI/logs:Z
      - ./static:/CLIProxyAPI/static:Z
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
COMPOSE
  if [[ $caddy_mode == docker ]]; then
    cat >> "$app/compose.yaml" <<COMPOSE
  caddy:
    image: $caddy_image
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./caddy:/etc/caddy:ro,Z
      - ./caddy-data:/data:Z
      - ./caddy-config:/config:Z
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
COMPOSE
  fi
fi
printf 'backend=%s\nui=%s\nui_sha256=%s\ncaddy_image=%s\n' "$image" "$ui_version" "$ui_sha" "$caddy_image" > "$app/VERSIONS"
dc config --quiet
dc pull
if [[ $caddy_mode == docker ]]; then
  dc run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
fi
dc up -d
ready=0
for ((attempt=0; attempt<45; attempt++)); do
  if authcurl "$CPA_CLIENT_KEY" --noproxy '*' --max-time 3 -f -o /dev/null "http://127.0.0.1:$port/v1/models" 2>/dev/null; then ready=1; break; fi
  sleep 2
done
((ready)) || die 'Backend did not become ready. Use the logs action; persistent files are retained.'
verify_local
if [[ $caddy_mode == host ]]; then
  site=/etc/caddy/cliproxyapi-sites/$domain.caddy
  install -d -m 755 /etc/caddy/cliproxyapi-sites
  if [[ -e $site ]]; then
    cmp -s "$app/caddy/Caddyfile" "$site" || die 'Existing dedicated Caddy site differs; inspect it before changing.'
  else install -m 644 "$app/caddy/Caddyfile" "$site"; fi
  import_line="import $site"
  caddy_backup=$app/backups/Caddyfile.before-installer
  if ! grep -Fqx "$import_line" "$caddyfile"; then
    cp -a "$caddyfile" "$caddy_backup"
    printf '\n# CLIProxyAPI site: %s\n%s\n' "$domain" "$import_line" >> "$caddyfile"
    if ! caddy validate --config "$caddyfile" --adapter caddyfile; then
      cp -a "$caddy_backup" "$caddyfile"
      die 'Caddy validation failed; original main configuration restored.'
    fi
    if ! systemctl reload caddy; then
      cp -a "$caddy_backup" "$caddyfile"
      systemctl reload caddy || true
      die 'Caddy reload failed; original main configuration restored.'
    fi
  else
    caddy validate --config "$caddyfile" --adapter caddyfile
    systemctl reload caddy
  fi
fi
if ((open_firewall)) && [[ $caddy_mode != none ]]; then
  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --permanent --add-service=http --add-service=https
    firewall-cmd --add-service=http --add-service=https
  elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q '^Status: active'; then
    ufw allow 80/tcp
    ufw allow 443/tcp
  else say 'No active supported firewall found; allow TCP 80/443 in your provider firewall/security group if needed.'; fi
fi
dc ps
summary
if [[ $caddy_mode != none ]]; then
  say 'Local checks passed. DNS propagation and certificate issuance may take a few minutes.'
  say "After DNS/HTTPS is ready: sudo bash $0 verify --dir $app"
else say 'Local checks passed. Configure your external reverse proxy before public use.'; fi
say 'Generated keys were saved to secrets.env; they were not printed to this terminal.'
