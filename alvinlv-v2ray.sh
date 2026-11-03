#!/usr/bin/env bash
# AlvinLv V2Fly interactive manager. The v2ray command dispatches to the actual V2Fly core.
set -Eeuo pipefail
umask 077
CORE=/usr/local/libexec/alvinlv-v2fly/v2ray-core
STATE=/etc/alvinlv-v2fly
CONF=/usr/local/etc/v2ray/config.json
HELPER=$STATE/config.py
MARKER=/var/lib/alvinlv-v2fly/install.state
RESUME=/var/lib/alvinlv-v2fly/resume.json
INSTALLER_HASH=e82217ce0db9e68f41ca34521ecd4ac98018d22d9ddd83e1316c74fb805603ae
INSTALLER_URL=https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/cb39ee88249d47ed1c601dd5d3d94758d8835629/install-release.sh
V2FLY_CORE_VERSION=v5.53.0
export V2RAY_LOCATION_ASSET=/usr/local/share/v2ray

COLOR_RED='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_RESET=''
if [[ -t 1 && ${TERM:-} != dumb && ! ${NO_COLOR+x} ]]; then
    COLOR_RED=$'\033[31m'; COLOR_GREEN=$'\033[32m'; COLOR_YELLOW=$'\033[33m'; COLOR_RESET=$'\033[0m'
fi
die() { printf '\n%s[错误] %s%s\n' "$COLOR_RED" "$*" "$COLOR_RESET" >&2; exit 1; }
info() { printf '\n%s[AlvinLv] %s%s\n' "$COLOR_GREEN" "$*" "$COLOR_RESET"; }
warn() { printf '\n%s[提示] %s%s\n' "$COLOR_YELLOW" "$*" "$COLOR_RESET" >&2; }
error() { printf '\n%s[错误] %s%s\n' "$COLOR_RED" "$*" "$COLOR_RESET" >&2; }
menu_print() { printf '%s' "$COLOR_GREEN"; printf '%s\n' "$@"; printf '%s' "$COLOR_RESET"; }
root() { [[ $EUID == 0 ]] || die '请使用 root 或 sudo v2ray 打开管理菜单'; }
choice() { local answer; read -r -p "$1" answer || die '输入结束'; REPLY=${answer:-$2}; }
yesno() { local answer; read -r -p "$1 [y/N]: " answer || die '输入结束'; [[ $answer == y || $answer == Y ]]; }
core_forward() { [[ -x $CORE ]] || die '尚未安装 V2Fly 内核'; exec "$CORE" "$@"; }

show_help() {
    cat <<'HELP'
........... V2Ray 管理脚本帮助信息 · 作者 AlvinLv ...........
  v2ray menu        打开管理菜单（直接输入 v2ray 也可）
  v2ray info        查看节点信息和当前出口
  v2ray config      编辑并校验 V2Ray 配置
  v2ray link        显示客户端导入链接（url 为别名）
  v2ray textlink    在终端显示节点信息和链接
  v2ray qr          在终端生成节点二维码
  v2ray ss          交互配置或关闭 Shadowsocks
  v2ray ssinfo      查看 Shadowsocks 信息和链接
  v2ray ssqr        在终端生成 Shadowsocks 二维码
  v2ray status      查看服务状态
  v2ray start       启动服务
  v2ray stop        停止服务
  v2ray restart     重启服务
  v2ray log         查看服务日志
  v2ray update      交互更新 V2Fly 内核
  v2ray update.sh   用已下载的新脚本更新管理程序
  v2ray uninstall   卸载本脚本安装的服务
  v2ray exit-proxy  配置住宅出口
  v2ray exit-check  检测当前节点的实际出口 IP
  v2ray check       检查配置
  v2ray doctor      诊断服务、证书和 WebSocket 入口
  v2ray system      系统设置和 BBR 管理
  v2ray protocol    切换主节点协议（VMess / Trojan）
  v2ray core ...    运行 V2Fly 原生子命令，如 v2ray core help
节点链接和二维码包含密钥，不要公开。
HELP
}

ACTION=menu
if [[ $# -gt 0 ]]; then
    case $1 in menu|config|status|start|stop|restart|log|link|url|info|textlink|qr|ss|ssinfo|ssqr|update|update.sh|--help|-h|help|check|doctor|system|protocol|exit-proxy|exit-check|uninstall|update-menu) ACTION=$1; shift; [[ $# == 0 ]] || die '该管理命令不接受参数' ;; core) shift; core_forward "$@" ;; *) core_forward "$@" ;; esac
fi
if [[ $ACTION == --help || $ACTION == -h || $ACTION == help ]]; then show_help; exit 0; fi
root
[[ -d /run/systemd/system ]] || die '需要 Linux 和正在运行的 systemd'
command -v python3 >/dev/null || { echo '首次安装时需要 python3，请先用系统包管理器安装'; exit 1; }

write_helper() {
    cat <<'ALVINLV_CONFIG_BASE64' | base64 -d > "$1"
IiIiVjJGbHkgY29uZmlndXJhdGlvbiBidWlsZGVyLiBQeXRob24gMy42KzsgYXV0aG9yIEFsdmlu
THYuIiIiCmltcG9ydCBiYXNlNjQKaW1wb3J0IGNvcHkKaW1wb3J0IGpzb24KaW1wb3J0IGlwYWRk
cmVzcwppbXBvcnQgb3MKaW1wb3J0IHJlCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQg
dXVpZApmcm9tIHVybGxpYi5wYXJzZSBpbXBvcnQgcXVvdGUsIHVybGVuY29kZQoKCmRlZiBzZXJ2
ZXIocyk6CiAgICBwcm90byA9IHNbJ3Byb3RvY29sJ10KICAgIGlkZW50aXR5ID0geydwYXNzd29y
ZCc6IHNbJ3Bhc3N3b3JkJ119IGlmIHByb3RvID09ICd0cm9qYW4nIGVsc2UgeydpZCc6IHNbJ3V1
aWQnXX0KICAgIHNldHRpbmdzID0geydjbGllbnRzJzogW2lkZW50aXR5XX0KICAgIGlmIHByb3Rv
ID09ICd2bGVzcyc6CiAgICAgICAgc2V0dGluZ3NbJ2RlY3J5cHRpb24nXSA9ICdub25lJwogICAg
aW5ib3VuZCA9IHsnbGlzdGVuJzogJzEyNy4wLjAuMScsICdwb3J0JzogaW50KHNbJ3BvcnQnXSks
ICdwcm90b2NvbCc6IHByb3RvLAogICAgICAgICAgICAgICAnc2V0dGluZ3MnOiBzZXR0aW5ncywg
J3N0cmVhbVNldHRpbmdzJzogeyduZXR3b3JrJzogJ3dzJywgJ3dzU2V0dGluZ3MnOiB7J3BhdGgn
OiBzWydwYXRoJ119fX0KICAgIHJlc3VsdCA9IHsnbG9nJzogeydsb2dsZXZlbCc6ICd3YXJuaW5n
J30sICdpbmJvdW5kcyc6IFtpbmJvdW5kXX0KICAgIGFwcGx5X2V4aXQocmVzdWx0LCBzLmdldCgn
ZXhpdCcpKQogICAgcmV0dXJuIHJlc3VsdAoKCgpkZWYgc3dpdGNoX3Byb3RvY29sKGNvbmZpZywg
c3RhdGUsIHRhcmdldCk6CiAgICBpZiB0YXJnZXQgbm90IGluICgndm1lc3MnLCAndHJvamFuJyk6
CiAgICAgICAgcmFpc2UgVmFsdWVFcnJvcign5LuF5pSv5oyB5YiH5o2iIFZNZXNzIOaIliBUcm9q
YW4nKQogICAgZXhwZWN0ZWQgPSBzZXJ2ZXIoc3RhdGUpWydpbmJvdW5kcyddWzBdCiAgICBtYXRj
aGVzID0gW2kgZm9yIGkgaW4gY29uZmlnLmdldCgnaW5ib3VuZHMnLCBbXSkgaWYgaS5nZXQoJ3Bv
cnQnKSA9PSBleHBlY3RlZFsncG9ydCddIGFuZCBpLmdldCgnbGlzdGVuJykgPT0gZXhwZWN0ZWRb
J2xpc3RlbiddIGFuZCBpLmdldCgnc3RyZWFtU2V0dGluZ3MnLCB7fSkuZ2V0KCd3c1NldHRpbmdz
Jywge30pLmdldCgncGF0aCcpID09IHN0YXRlWydwYXRoJ11dCiAgICBpZiBsZW4obWF0Y2hlcykg
IT0gMSBvciBtYXRjaGVzWzBdLmdldCgncHJvdG9jb2wnKSAhPSBzdGF0ZVsncHJvdG9jb2wnXSBv
ciBtYXRjaGVzWzBdLmdldCgnc2V0dGluZ3MnKSAhPSBleHBlY3RlZFsnc2V0dGluZ3MnXToKICAg
ICAgICByYWlzZSBWYWx1ZUVycm9yKCfnjrDmnInkuLvoioLngrnkuI7lronoo4XorrDlvZXkuI3k
uIDoh7TvvIzor7flhYjmoLjlr7nphY3nva4nKQogICAgcmVzdWx0LCB1cGRhdGVkID0gY29weS5k
ZWVwY29weShjb25maWcpLCBjb3B5LmRlZXBjb3B5KHN0YXRlKQogICAgaWYgdGFyZ2V0ICE9IHN0
YXRlWydwcm90b2NvbCddOgogICAgICAgIGlmIHRhcmdldCA9PSAndm1lc3MnOiB1cGRhdGVkWyd1
dWlkJ10gPSBzdHIodXVpZC51dWlkNCgpKQogICAgICAgIGVsc2U6IHVwZGF0ZWRbJ3Bhc3N3b3Jk
J10gPSBvcy51cmFuZG9tKDI0KS5oZXgoKQogICAgdXBkYXRlZFsncHJvdG9jb2wnXSA9IHRhcmdl
dAogICAgbm9kZSA9IG5leHQoaSBmb3IgaSBpbiByZXN1bHRbJ2luYm91bmRzJ10gaWYgaS5nZXQo
J3BvcnQnKSA9PSBleHBlY3RlZFsncG9ydCddIGFuZCBpLmdldCgnbGlzdGVuJykgPT0gZXhwZWN0
ZWRbJ2xpc3RlbiddIGFuZCBpLmdldCgnc3RyZWFtU2V0dGluZ3MnLCB7fSkuZ2V0KCd3c1NldHRp
bmdzJywge30pLmdldCgncGF0aCcpID09IHN0YXRlWydwYXRoJ10pCiAgICBuZXdfbm9kZSA9IHNl
cnZlcih1cGRhdGVkKVsnaW5ib3VuZHMnXVswXQogICAgbm9kZVsncHJvdG9jb2wnXSwgbm9kZVsn
c2V0dGluZ3MnXSA9IG5ld19ub2RlWydwcm90b2NvbCddLCBuZXdfbm9kZVsnc2V0dGluZ3MnXQog
ICAgcmV0dXJuIHJlc3VsdCwgdXBkYXRlZCwgY2xpZW50KHVwZGF0ZWQpCgpkZWYgYXBwbHlfZXhp
dChjLCBwcm94eSk6CiAgICBibG9jayA9IHsncHJvdG9jb2wnOiAnYmxhY2tob2xlJywgJ3RhZyc6
ICdibG9ja2VkJywgJ3NldHRpbmdzJzoge319CiAgICBydWxlcyA9IFt7J3R5cGUnOiAnZmllbGQn
LCAnaXAnOiBbJ2dlb2lwOnByaXZhdGUnXSwgJ291dGJvdW5kVGFnJzogJ2Jsb2NrZWQnfV0KICAg
IGlmIHByb3h5OgogICAgICAgIHVwc3RyZWFtID0geydhZGRyZXNzJzogcHJveHlbJ2hvc3QnXSwg
J3BvcnQnOiBpbnQocHJveHlbJ3BvcnQnXSl9CiAgICAgICAgaWYgcHJveHkuZ2V0KCd1c2VybmFt
ZScpOgogICAgICAgICAgICB1cHN0cmVhbVsndXNlcnMnXSA9IFt7J3VzZXInOiBwcm94eVsndXNl
cm5hbWUnXSwgJ3Bhc3MnOiBwcm94eVsncGFzc3dvcmQnXX1dCiAgICAgICAgb3V0Ym91bmQgPSB7
J3Byb3RvY29sJzogcHJveHlbJ3R5cGUnXSwgJ3RhZyc6ICd1cHN0cmVhbScsICdzZXR0aW5ncyc6
IHsnc2VydmVycyc6IFt1cHN0cmVhbV19fQogICAgICAgIHJ1bGVzLmluc2VydCgwLCB7J3R5cGUn
OiAnZmllbGQnLCAnbmV0d29yayc6ICd1ZHAnLCAnb3V0Ym91bmRUYWcnOiAnYmxvY2tlZCd9KQog
ICAgZWxzZToKICAgICAgICBvdXRib3VuZCA9IHsncHJvdG9jb2wnOiAnZnJlZWRvbScsICd0YWcn
OiAnZGlyZWN0JywgJ3NldHRpbmdzJzoge319CiAgICBjWydvdXRib3VuZHMnXSA9IFtvdXRib3Vu
ZCwgYmxvY2tdCiAgICBjWydyb3V0aW5nJ10gPSB7J2RvbWFpblN0cmF0ZWd5JzogJ0lQSWZOb25N
YXRjaCcsICdydWxlcyc6IHJ1bGVzfQoKCmRlZiBjbGllbnQocyk6CiAgICBwcm90byA9IHNbJ3By
b3RvY29sJ10KICAgIGhvc3QgPSBzWydkb21haW4nXQogICAgaWYgcHJvdG8gPT0gJ3Ryb2phbic6
CiAgICAgICAgc2V0dGluZ3MgPSB7J3NlcnZlcnMnOiBbeydhZGRyZXNzJzogaG9zdCwgJ3BvcnQn
OiA0NDMsICdwYXNzd29yZCc6IHNbJ3Bhc3N3b3JkJ119XX0KICAgIGVsc2U6CiAgICAgICAgdXNl
ciA9IHsnaWQnOiBzWyd1dWlkJ119CiAgICAgICAgaWYgcHJvdG8gPT0gJ3ZtZXNzJzoKICAgICAg
ICAgICAgdXNlci51cGRhdGUoeydhbHRlcklkJzogMCwgJ3NlY3VyaXR5JzogJ2F1dG8nfSkKICAg
ICAgICBlbHNlOgogICAgICAgICAgICB1c2VyWydlbmNyeXB0aW9uJ10gPSAnbm9uZScKICAgICAg
ICBzZXR0aW5ncyA9IHsndm5leHQnOiBbeydhZGRyZXNzJzogaG9zdCwgJ3BvcnQnOiA0NDMsICd1
c2Vycyc6IFt1c2VyXX1dfQogICAgcmV0dXJuIHsnbG9nJzogeydsb2dsZXZlbCc6ICd3YXJuaW5n
J30sCiAgICAgICAgICAgICdpbmJvdW5kcyc6IFt7J2xpc3Rlbic6ICcxMjcuMC4wLjEnLCAncG9y
dCc6IDEwODA4LCAncHJvdG9jb2wnOiAnc29ja3MnLCAnc2V0dGluZ3MnOiB7J3VkcCc6IEZhbHNl
fX1dLAogICAgICAgICAgICAnb3V0Ym91bmRzJzogW3sncHJvdG9jb2wnOiBwcm90bywgJ3NldHRp
bmdzJzogc2V0dGluZ3MsICdzdHJlYW1TZXR0aW5ncyc6IHsKICAgICAgICAgICAgICAgICduZXR3
b3JrJzogJ3dzJywgJ3NlY3VyaXR5JzogJ3RscycsICd0bHNTZXR0aW5ncyc6IHsnc2VydmVyTmFt
ZSc6IGhvc3R9LAogICAgICAgICAgICAgICAgJ3dzU2V0dGluZ3MnOiB7J3BhdGgnOiBzWydwYXRo
J10sICdoZWFkZXJzJzogeydIb3N0JzogaG9zdH19fX1dfQoKCmRlZiBzaGFyZShzKToKICAgIHBy
b3RvID0gc1sncHJvdG9jb2wnXQogICAgaWYgcHJvdG8gPT0gJ3ZtZXNzJzoKICAgICAgICBpdGVt
ID0geyd2JzogJzInLCAncHMnOiBzWydkb21haW4nXSwgJ2FkZCc6IHNbJ2RvbWFpbiddLCAncG9y
dCc6ICc0NDMnLCAnaWQnOiBzWyd1dWlkJ10sCiAgICAgICAgICAgICAgICAnYWlkJzogJzAnLCAn
c2N5JzogJ2F1dG8nLCAnbmV0JzogJ3dzJywgJ3R5cGUnOiAnbm9uZScsICdob3N0Jzogc1snZG9t
YWluJ10sCiAgICAgICAgICAgICAgICAncGF0aCc6IHNbJ3BhdGgnXSwgJ3Rscyc6ICd0bHMnLCAn
c25pJzogc1snZG9tYWluJ119CiAgICAgICAgcmV0dXJuICd2bWVzczovLycgKyBiYXNlNjQuYjY0
ZW5jb2RlKGpzb24uZHVtcHMoaXRlbSwgc2VwYXJhdG9ycz0oJywnLCAnOicpKS5lbmNvZGUoKSku
ZGVjb2RlKCkKICAgIHNlY3JldCA9IHNbJ3Bhc3N3b3JkJ10gaWYgcHJvdG8gPT0gJ3Ryb2phbicg
ZWxzZSBzWyd1dWlkJ10KICAgIHBhcmFtcyA9IHsnc2VjdXJpdHknOiAndGxzJywgJ3R5cGUnOiAn
d3MnLCAnaG9zdCc6IHNbJ2RvbWFpbiddLCAncGF0aCc6IHNbJ3BhdGgnXSwgJ3NuaSc6IHNbJ2Rv
bWFpbiddfQogICAgaWYgcHJvdG8gPT0gJ3ZsZXNzJzoKICAgICAgICBwYXJhbXNbJ2VuY3J5cHRp
b24nXSA9ICdub25lJwogICAgcmV0dXJuIHByb3RvICsgJzovLycgKyBxdW90ZShzZWNyZXQsIHNh
ZmU9JycpICsgJ0AnICsgc1snZG9tYWluJ10gKyAnOjQ0Mz8nICsgdXJsZW5jb2RlKHBhcmFtcykg
KyAnIycgKyBxdW90ZShzWydkb21haW4nXSwgc2FmZT0nJykKCgpkZWYgcmVuZGVyX2NhZGR5KHMs
IG1vZGUsIGNlcnRtb2RlKToKICAgIGhvc3QsIHBhdGgsIHBvcnQgPSBzWydkb21haW4nXSwgc1sn
cGF0aCddLCBpbnQoc1sncG9ydCddKQogICAgaWYgbm90IHJlLmZ1bGxtYXRjaChyJ1tBLVphLXow
LTkuLV0rJywgaG9zdCkgb3Igbm90IHJlLmZ1bGxtYXRjaChyJy9bQS1aYS16MC05Xy8tXSsnLCBw
YXRoKToKICAgICAgICByYWlzZSBWYWx1ZUVycm9yKCdDYWRkeSDln5/lkI3miJYgV2ViU29ja2V0
IOi3r+W+hOaXoOaViCcpCiAgICBpZiBtb2RlIG5vdCBpbiAoJzEnLCAnMicsICczJykgb3IgY2Vy
dG1vZGUgbm90IGluICgnMScsICcyJykgb3Igbm90IDEgPD0gcG9ydCA8PSA2NTUzNToKICAgICAg
ICByYWlzZSBWYWx1ZUVycm9yKCdDYWRkeSDmqKHlvI/miJbnq6/lj6Pml6DmlYgnKQogICAgdGxz
ID0gJycKICAgIGlmIGNlcnRtb2RlID09ICcyJzogdGxzID0gJyAgICB0bHMgL2V0Yy9jYWRkeS9h
bHZpbmx2LXRscy9jZXJ0LnBlbSAvZXRjL2NhZGR5L2FsdmlubHYtdGxzL2tleS5wZW1cbicKICAg
IGVsaWYgbW9kZSBpbiAoJzInLCAnMycpOiB0bHMgPSAnICAgIHRscyB7XG4gICAgICAgIGlzc3Vl
ciBhY21lIHtcbiAgICAgICAgICAgIGRpc2FibGVfdGxzYWxwbl9jaGFsbGVuZ2VcbiAgICAgICAg
fVxuICAgIH1cbicKICAgIHdzID0gKCcgICAgQHByb3h5IHtcbiAgICAgICAgcGF0aCAnK3BhdGgr
J1xuICAgICAgICBoZWFkZXIgQ29ubmVjdGlvbiAqVXBncmFkZSpcbicKICAgICAgICAgICcgICAg
ICAgIGhlYWRlciBVcGdyYWRlIHdlYnNvY2tldFxuICAgIH1cbiAgICBoYW5kbGUgQHByb3h5IHtc
bicKICAgICAgICAgICcgICAgICAgIHJldmVyc2VfcHJveHkgMTI3LjAuMC4xOicrc3RyKHBvcnQp
KydcbiAgICB9XG4nKQogICAgaHR0cHMgPSBob3N0Kycge1xuJyt0bHMrd3MrJyAgICBoYW5kbGUg
e1xuICAgICAgICByZXNwb25kICJBbHZpbkx2IHNlcnZlciBvbmxpbmUiIDIwMFxuICAgIH1cbn1c
bicKICAgIGlmIG1vZGUgIT0gJzMnOiByZXR1cm4gaHR0cHMKICAgIGh0dHAgPSAnaHR0cDovLycr
aG9zdCsnIHtcbicrd3MrJyAgICBoYW5kbGUge1xuICAgICAgICByZXNwb25kICJGb3JiaWRkZW4i
IDQwM1xuICAgIH1cbn1cbicKICAgIHJldHVybiBodHRwKydcbicraHR0cHMKCgpkZWYgbm9kZV9p
bmZvKHMsIGxpdmUpOgogICAgcHJvdG8gPSBzWydwcm90b2NvbCddCiAgICBpZGVudGl0eV9uYW1l
ID0gJ+WvhueggScgaWYgcHJvdG8gPT0gJ3Ryb2phbicgZWxzZSAnVVVJRCcKICAgIGlkZW50aXR5
ID0gc1sncGFzc3dvcmQnXSBpZiBwcm90byA9PSAndHJvamFuJyBlbHNlIHNbJ3V1aWQnXQogICAg
b3V0Ym91bmQgPSAobGl2ZS5nZXQoJ291dGJvdW5kcycpIG9yIFt7fV0pWzBdLmdldCgncHJvdG9j
b2wnLCAn5pyq55+lJykKICAgIGVncmVzcyA9IHsnZnJlZWRvbSc6ICdWUFMg55u06L+eJywgJ3Nv
Y2tzJzogJ+S9j+WuheS7o+eQhiBTT0NLUycsICdodHRwJzogJ+S9j+WuheS7o+eQhiBIVFRQJ30u
Z2V0KG91dGJvdW5kLCBvdXRib3VuZCkKICAgIHJldHVybiAnXG4nLmpvaW4oWyfln5/lkI3vvJon
ICsgc1snZG9tYWluJ10sICfnq6/lj6PvvJo0NDMnLCAn5Y2P6K6u77yaJyArIHByb3RvLAogICAg
ICAgICAgICAgICAgICAgICAgJ+S8oOi+k++8mldlYlNvY2tldCArIFRMUycsICfot6/lvoTvvJon
ICsgc1sncGF0aCddLAogICAgICAgICAgICAgICAgICAgICAgaWRlbnRpdHlfbmFtZSArICfvvJon
ICsgaWRlbnRpdHksICflvZPliY3pppbpgInlh7rlj6PvvJonICsgZWdyZXNzLAogICAgICAgICAg
ICAgICAgICAgICAgJ+WvvOWFpemTvuaOpe+8micgKyBzaGFyZShzKV0pCgoKZGVmIHByb2JlX2Ns
aWVudChjLCBwb3J0KToKICAgIHByb2JlID0gY29weS5kZWVwY29weShjKQogICAgcHJvYmVbJ2lu
Ym91bmRzJ10gPSBbeydsaXN0ZW4nOiAnMTI3LjAuMC4xJywgJ3BvcnQnOiBwb3J0LCAncHJvdG9j
b2wnOiAnc29ja3MnLCAnc2V0dGluZ3MnOiB7J3VkcCc6IEZhbHNlfX1dCiAgICBwcm9iZVsnbG9n
J10gPSB7J2xvZ2xldmVsJzogJ3dhcm5pbmcnfQogICAgcmV0dXJuIHByb2JlCgoKZGVmIHZhbGlk
YXRlX25vZGVfb3B0aW9ucyhvcHRpb25zKToKICAgIHBhdGggPSBvcHRpb25zLmdldCgncGF0aCcs
ICcnKQogICAgcG9ydCA9IG9wdGlvbnMuZ2V0KCdwb3J0JykKICAgIHByb3RvY29sID0gb3B0aW9u
cy5nZXQoJ3Byb3RvY29sJykKICAgIGlmIG5vdCBpc2luc3RhbmNlKHBhdGgsIHN0cikgb3IgcGF0
aCA9PSAnLycgb3IgbGVuKHBhdGgpID4gMjU2IG9yIG5vdCByZS5mdWxsbWF0Y2gocicvW0EtWmEt
ejAtOV8vLV0rJywgcGF0aCk6CiAgICAgICAgcmFpc2UgVmFsdWVFcnJvcignV2ViU29ja2V0IOi3
r+W+hOmcgOS7pSAvIOW8gOWktO+8jOS9v+eUqOWtl+avjeOAgeaVsOWtl+OAgeS4i+WIkue6v+OA
geaoque6v+aIluaWnOadoO+8jOS4lOS4jeiDveS4uuaguei3r+W+hCcpCiAgICBpZiBpc2luc3Rh
bmNlKHBvcnQsIGJvb2wpIG9yIG5vdCBpc2luc3RhbmNlKHBvcnQsIGludCkgb3Igbm90IDEwMjQg
PD0gcG9ydCA8PSA2NTUzNSBvciBwb3J0ID09IDIwMTk6CiAgICAgICAgcmFpc2UgVmFsdWVFcnJv
cign5ZCO56uv56uv5Y+j6ZyA5Li6IDEwMjTvvZ42NTUzNSDkuJTkuI3og73kvb/nlKggMjAxOScp
CiAgICBpZiBwcm90b2NvbCBub3QgaW4gKCd0cm9qYW4nLCAndm1lc3MnLCAndmxlc3MnKTogcmFp
c2UgVmFsdWVFcnJvcign5Y2P6K6u5peg5pWIJykKICAgIGlmIHByb3RvY29sID09ICd0cm9qYW4n
OgogICAgICAgIHBhc3N3b3JkID0gb3B0aW9ucy5nZXQoJ3Bhc3N3b3JkJywgJycpCiAgICAgICAg
aWYgbm90IGlzaW5zdGFuY2UocGFzc3dvcmQsIHN0cikgb3Igbm90IDE2IDw9IGxlbihwYXNzd29y
ZCkgPD0gMTAyNCBvciBhbnkob3JkKGMpIDwgMzIgb3Igb3JkKGMpID09IDEyNyBmb3IgYyBpbiBw
YXNzd29yZCk6CiAgICAgICAgICAgIHJhaXNlIFZhbHVlRXJyb3IoJ1Ryb2phbiDlr4bnoIHpnIDk
uLogMTbvvZ4xMDI0IOS4qumdnuaOp+WItuWtl+espicpCiAgICBlbHNlOgogICAgICAgIHRyeToK
ICAgICAgICAgICAgdmFsdWUgPSBvcHRpb25zLmdldCgndXVpZCcsICcnKQogICAgICAgICAgICBp
ZiBzdHIodXVpZC5VVUlEKHZhbHVlKSkgIT0gdmFsdWUubG93ZXIoKTogcmFpc2UgVmFsdWVFcnJv
cigpCiAgICAgICAgZXhjZXB0IChWYWx1ZUVycm9yLCBBdHRyaWJ1dGVFcnJvciwgVHlwZUVycm9y
KToKICAgICAgICAgICAgcmFpc2UgVmFsdWVFcnJvcignVVVJRCDmoLzlvI/ml6DmlYgnKQoKCmRl
ZiBkaWFnbm9zdGljX2NhdGVnb3J5KG9yaWdpbiwgZWRnZSk6CiAgICBpZiBlZGdlID09ICcxMDEn
OiByZXR1cm4gJ29rJyBpZiBvcmlnaW4gPT0gJzEwMScgZWxzZSAnZWRnZV9va19vcmlnaW5fdW52
ZXJpZmllZCcKICAgIGlmIGVkZ2UgaW4gKCczMDEnLCAnMzAyJywgJzMwNycsICczMDgnKTogcmV0
dXJuICdyZWRpcmVjdCcKICAgIGlmIGVkZ2UgPT0gJzQwMyc6IHJldHVybiAnYmxvY2tlZCcKICAg
IGlmIGVkZ2UgaW4gKCc1MjUnLCAnNTI2Jyk6IHJldHVybiAnb3JpZ2luX3RscycKICAgIGlmIGVk
Z2UgPT0gJzAwMCc6IHJldHVybiAndW5yZWFjaGFibGUnCiAgICByZXR1cm4gJ2h0dHBfZXJyb3In
CgoKZGVmIGV4cGVjdGVkX2lwX21hdGNoZXMocHJvZmlsZSwgYWN0dWFsKToKICAgIGV4cGVjdGVk
ID0gKHByb2ZpbGUgb3Ige30pLmdldCgnZXhwZWN0ZWRfaXAnLCAnJykKICAgIGlmIG5vdCBleHBl
Y3RlZDogcmV0dXJuIE5vbmUKICAgIHJldHVybiBpcGFkZHJlc3MuaXBfYWRkcmVzcyhleHBlY3Rl
ZCkgPT0gaXBhZGRyZXNzLmlwX2FkZHJlc3MoYWN0dWFsKQoKCmRlZiBzc19pbmJvdW5kKGMpOgog
ICAgZW50cmllcyA9IFtpIGZvciBpIGluIGMuZ2V0KCdpbmJvdW5kcycsIFtdKSBpZiBpLmdldCgn
dGFnJykgPT0gJ2FsdmlubHYtc3MnXQogICAgaWYgbGVuKGVudHJpZXMpID4gMTogcmFpc2UgVmFs
dWVFcnJvcign5Y+R546w5aSa5Liq5pys6ISa5pysIFNoYWRvd3NvY2tzIOWFpeerme+8jOivt+aJ
i+WKqOajgOafpScpCiAgICByZXR1cm4gZW50cmllc1swXSBpZiBlbnRyaWVzIGVsc2UgTm9uZQoK
CmRlZiBzZXRfc3MoYywgcHJvZmlsZSk6CiAgICBleGlzdGluZyA9IHNzX2luYm91bmQoYykKICAg
IGlmIHByb2ZpbGU6CiAgICAgICAgaXBhZGRyZXNzLklQdjRBZGRyZXNzKHByb2ZpbGVbJ2hvc3Qn
XSkKICAgICAgICBwb3J0ID0gaW50KHByb2ZpbGVbJ3BvcnQnXSkKICAgICAgICBpZiBub3QgMTAy
NCA8PSBwb3J0IDw9IDY1NTM1OiByYWlzZSBWYWx1ZUVycm9yKCfnq6/lj6Plv4XpobvkuLogMTAy
NO+9njY1NTM1JykKICAgICAgICBpZiBwcm9maWxlWydtZXRob2QnXSBub3QgaW4gKCdhZXMtMjU2
LWdjbScsICdhZXMtMTI4LWdjbScsICdjaGFjaGEyMC1wb2x5MTMwNScpOiByYWlzZSBWYWx1ZUVy
cm9yKCfliqDlr4bmlrnlvI/ml6DmlYgnKQogICAgICAgIGlmIGxlbihwcm9maWxlWydwYXNzd29y
ZCddKSA8IDE2OiByYWlzZSBWYWx1ZUVycm9yKCflr4bnoIHoh7PlsJEgMTYg5Liq5a2X56ymJykK
ICAgICAgICBpZiBhbnkoc3RyKGkuZ2V0KCdwb3J0JykpID09IHN0cihwb3J0KSBmb3IgaSBpbiBj
LmdldCgnaW5ib3VuZHMnLCBbXSkgaWYgaSBpcyBub3QgZXhpc3RpbmcpOgogICAgICAgICAgICBy
YWlzZSBWYWx1ZUVycm9yKCfnq6/lj6PkuI7lt7LmnInlhaXnq5nlhrLnqoEnKQogICAgICAgIGlu
Ym91bmQgPSB7J3RhZyc6ICdhbHZpbmx2LXNzJywgJ2xpc3Rlbic6ICcwLjAuMC4wJywgJ3BvcnQn
OiBwb3J0LCAncHJvdG9jb2wnOiAnc2hhZG93c29ja3MnLAogICAgICAgICAgICAgICAgICAgJ3Nl
dHRpbmdzJzogeydtZXRob2QnOiBwcm9maWxlWydtZXRob2QnXSwgJ3Bhc3N3b3JkJzogcHJvZmls
ZVsncGFzc3dvcmQnXSwgJ25ldHdvcmsnOiAndGNwJ319CiAgICBjWydpbmJvdW5kcyddID0gW2kg
Zm9yIGkgaW4gYy5nZXQoJ2luYm91bmRzJywgW10pIGlmIGkgaXMgbm90IGV4aXN0aW5nXQogICAg
aWYgcHJvZmlsZTogY1snaW5ib3VuZHMnXS5hcHBlbmQoaW5ib3VuZCkKCgpkZWYgc3Nfc2hhcmUo
YywgaG9zdCwgYWxpYXM9Tm9uZSk6CiAgICBpcGFkZHJlc3MuSVB2NEFkZHJlc3MoaG9zdCkKICAg
IGluYm91bmQgPSBzc19pbmJvdW5kKGMpCiAgICBpZiBub3QgaW5ib3VuZDogcmFpc2UgVmFsdWVF
cnJvcign5bCa5pyq6YWN572uIFNoYWRvd3NvY2tzJykKICAgIHNldHRpbmdzID0gaW5ib3VuZFsn
c2V0dGluZ3MnXQogICAgdG9rZW4gPSBiYXNlNjQudXJsc2FmZV9iNjRlbmNvZGUoKHNldHRpbmdz
WydtZXRob2QnXSArICc6JyArIHNldHRpbmdzWydwYXNzd29yZCddKS5lbmNvZGUoKSkuZGVjb2Rl
KCkucnN0cmlwKCc9JykKICAgIHJldHVybiAnc3M6Ly8nICsgdG9rZW4gKyAnQCcgKyBob3N0ICsg
JzonICsgc3RyKGluYm91bmRbJ3BvcnQnXSkgKyAnIycgKyBxdW90ZShhbGlhcyBvciBob3N0LCBz
YWZlPScnKQoKCmRlZiBzYXZlKHBhdGgsIG9iaik6CiAgICB3aXRoIG9wZW4ocGF0aCwgJ3cnLCBl
bmNvZGluZz0ndXRmLTgnKSBhcyBmOgogICAgICAgIGpzb24uZHVtcChvYmosIGYsIGVuc3VyZV9h
c2NpaT1GYWxzZSwgaW5kZW50PTIpCiAgICAgICAgZi53cml0ZSgnXG4nKQoKCmRlZiBtYWluKCk6
CiAgICBhY3Rpb24gPSBzeXMuYXJndlsxXQogICAgaWYgYWN0aW9uID09ICdyZW5kZXInOgogICAg
ICAgIHN0YXRlID0ganNvbi5sb2FkKHN5cy5zdGRpbikKICAgICAgICBzYXZlKHN5cy5hcmd2WzJd
LCBzZXJ2ZXIoc3RhdGUpKTsgc2F2ZShzeXMuYXJndlszXSwgY2xpZW50KHN0YXRlKSk7IHNhdmUo
c3lzLmFyZ3ZbNF0sIHN0YXRlKQogICAgZWxpZiBhY3Rpb24gPT0gJ3N3aXRjaC1wcm90b2NvbCc6
CiAgICAgICAgY29uZmlnID0ganNvbi5sb2FkKG9wZW4oc3lzLmFyZ3ZbMl0sIGVuY29kaW5nPSd1
dGYtOCcpKQogICAgICAgIHN0YXRlID0ganNvbi5sb2FkKG9wZW4oc3lzLmFyZ3ZbM10sIGVuY29k
aW5nPSd1dGYtOCcpKQogICAgICAgIG5ld19jb25maWcsIG5ld19zdGF0ZSwgbmV3X2NsaWVudCA9
IHN3aXRjaF9wcm90b2NvbChjb25maWcsIHN0YXRlLCBzeXMuYXJndls0XSkKICAgICAgICBzYXZl
KHN5cy5hcmd2WzVdLCBuZXdfY29uZmlnKTsgc2F2ZShzeXMuYXJndls2XSwgbmV3X3N0YXRlKTsg
c2F2ZShzeXMuYXJndls3XSwgbmV3X2NsaWVudCkKICAgIGVsaWYgYWN0aW9uID09ICdleGl0JzoK
ICAgICAgICBjb25maWcgPSBqc29uLmxvYWQob3BlbihzeXMuYXJndlsyXSwgZW5jb2Rpbmc9J3V0
Zi04JykpCiAgICAgICAgcHJveHkgPSBqc29uLmxvYWQoc3lzLnN0ZGluKQogICAgICAgIGFwcGx5
X2V4aXQoY29uZmlnLCBwcm94eSkKICAgICAgICBzYXZlKHN5cy5hcmd2WzNdLCBjb25maWcpCiAg
ICBlbGlmIGFjdGlvbiA9PSAnc2hhcmUnOgogICAgICAgIHByaW50KHNoYXJlKGpzb24ubG9hZChv
cGVuKHN5cy5hcmd2WzJdLCBlbmNvZGluZz0ndXRmLTgnKSkpKQogICAgZWxpZiBhY3Rpb24gPT0g
J2NhZGR5JzoKICAgICAgICBzdGF0ZSA9IGpzb24ubG9hZChvcGVuKHN5cy5hcmd2WzJdLCBlbmNv
ZGluZz0ndXRmLTgnKSkKICAgICAgICBwcmludChyZW5kZXJfY2FkZHkoc3RhdGUsIHN5cy5hcmd2
WzNdLCBzeXMuYXJndls0XSksIGVuZD0nJykKICAgIGVsaWYgYWN0aW9uID09ICdpbmZvJzoKICAg
ICAgICBzdGF0ZSA9IGpzb24ubG9hZChvcGVuKHN5cy5hcmd2WzJdLCBlbmNvZGluZz0ndXRmLTgn
KSkKICAgICAgICBsaXZlID0ganNvbi5sb2FkKG9wZW4oc3lzLmFyZ3ZbM10sIGVuY29kaW5nPSd1
dGYtOCcpKQogICAgICAgIHByaW50KG5vZGVfaW5mbyhzdGF0ZSwgbGl2ZSkpCiAgICBlbGlmIGFj
dGlvbiA9PSAncHJvYmUnOgogICAgICAgIGMgPSBqc29uLmxvYWQob3BlbihzeXMuYXJndlsyXSwg
ZW5jb2Rpbmc9J3V0Zi04JykpCiAgICAgICAgd2l0aCBzb2NrZXQuc29ja2V0KCkgYXMgc29jazoK
ICAgICAgICAgICAgc29jay5iaW5kKCgnMTI3LjAuMC4xJywgMCkpCiAgICAgICAgICAgIHBvcnQg
PSBzb2NrLmdldHNvY2tuYW1lKClbMV0KICAgICAgICBzYXZlKHN5cy5hcmd2WzNdLCBwcm9iZV9j
bGllbnQoYywgcG9ydCkpCiAgICAgICAgcHJpbnQocG9ydCkKICAgIGVsaWYgYWN0aW9uID09ICd2
ZXJpZnktaXAnOgogICAgICAgIHN0YXRlID0ganNvbi5sb2FkKG9wZW4oc3lzLmFyZ3ZbMl0sIGVu
Y29kaW5nPSd1dGYtOCcpKQogICAgICAgIGV4cGVjdGVkID0gKHN0YXRlLmdldCgnZXhpdCcpIG9y
IHt9KS5nZXQoJ2V4cGVjdGVkX2lwJywgJycpCiAgICAgICAgcmVzdWx0ID0gZXhwZWN0ZWRfaXBf
bWF0Y2hlcyhzdGF0ZS5nZXQoJ2V4aXQnKSwgc3lzLmFyZ3ZbM10pCiAgICAgICAgaWYgcmVzdWx0
IGlzIEZhbHNlOgogICAgICAgICAgICBwcmludCgn5a6e6ZmF5Ye65Y+jIElQIOS4jumihOacn+S4
jeS4gOiHtO+8iOmihOacn++8micgKyBleHBlY3RlZCArICfvvInjgIInKQogICAgICAgICAgICBy
YWlzZSBTeXN0ZW1FeGl0KDEpCiAgICAgICAgaWYgcmVzdWx0OiBwcmludCgn5Ye65Y+jIElQIOS4
jumihOacn+S4gOiHtOOAgicpCiAgICBlbGlmIGFjdGlvbiA9PSAndmFsaWRhdGUtbm9kZSc6CiAg
ICAgICAgdmFsaWRhdGVfbm9kZV9vcHRpb25zKGpzb24ubG9hZChzeXMuc3RkaW4pKQogICAgZWxp
ZiBhY3Rpb24gPT0gJ2RpYWdub3N0aWMtc3RhdHVzJzoKICAgICAgICBtZXNzYWdlcyA9IHsKICAg
ICAgICAgICAgJ29rJzogJ+a6kOermeWSjOWFrOe9keWFpeWPo+Wdh+WujOaIkCBXZWJTb2NrZXQg
5o+h5omL77yb5LuN6ZyA5qOA5rWL5a6e6ZmF5Luj55CG5ZKM5Ye65Y+j44CCJywKICAgICAgICAg
ICAgJ2VkZ2Vfb2tfb3JpZ2luX3VudmVyaWZpZWQnOiAn5YWs572R5YWl5Y+j5o+h5omL5oiQ5Yqf
77yb5rqQ56uZ55u06L+e6aqM6K+B5pyq6YCa6L+H77yM5qOA5p+l5rqQ56uZ6K+B5Lmm5Y+K572R
57uc44CCJywKICAgICAgICAgICAgJ3JlZGlyZWN0JzogJ+WFrOe9keWFpeWPo+i/lOWbnumHjeWu
muWQke+8m+ajgOafpSBDbG91ZGZsYXJlIFNTTC9UTFMg5qih5byP44CBQ2FkZHkgSFRUUCDot6/n
lLHlj4rph43lrprlkJHop4TliJnjgIInLAogICAgICAgICAgICAnYmxvY2tlZCc6ICflhaznvZHl
haXlj6Pov5Tlm54gNDAz77yb5qOA5p+lIENsb3VkZmxhcmUgV0FG44CB5oyR5oiY6aG15Y+KIENh
ZGR5IOi3r+W+hOWMuemFjeOAgicsCiAgICAgICAgICAgICdvcmlnaW5fdGxzJzogJ+WFrOe9keWF
peWPo+i/lOWbniA1MjUvNTI277yb5qOA5p+lIENsb3VkZmxhcmUg5Zue5rqQIFRMUyDlkozmupDn
q5nor4HkuabjgIInLAogICAgICAgICAgICAndW5yZWFjaGFibGUnOiAn5YWs572R5YWl5Y+j5pyq
5a6M5oiQIEhUVFBTIOivt+axgu+8m+ajgOafpSBETlPjgIHnvZHnu5zjgIHnq6/lj6Plkozor4Hk
uabjgIInLAogICAgICAgICAgICAnaHR0cF9lcnJvcic6ICflhaznvZHlhaXlj6Pov5Tlm57pnZ4g
MTAxIOeKtuaAge+8m+ajgOafpSBXZWJTb2NrZXQg6Lev5b6E44CBQ2xvdWRmbGFyZSDlkowgQ2Fk
ZHnjgIInCiAgICAgICAgfQogICAgICAgIHByaW50KG1lc3NhZ2VzW2RpYWdub3N0aWNfY2F0ZWdv
cnkoc3lzLmFyZ3ZbMl0sIHN5cy5hcmd2WzNdKV0pCiAgICBlbGlmIGFjdGlvbiA9PSAnc3Mtc2V0
JzoKICAgICAgICBjID0ganNvbi5sb2FkKG9wZW4oc3lzLmFyZ3ZbMl0sIGVuY29kaW5nPSd1dGYt
OCcpKQogICAgICAgIHNldF9zcyhjLCBqc29uLmxvYWQoc3lzLnN0ZGluKSkKICAgICAgICBzYXZl
KHN5cy5hcmd2WzNdLCBjKQogICAgZWxpZiBhY3Rpb24gPT0gJ3NzLXBvcnQnOgogICAgICAgIGMg
PSBqc29uLmxvYWQob3BlbihzeXMuYXJndlsyXSwgZW5jb2Rpbmc9J3V0Zi04JykpCiAgICAgICAg
aW5ib3VuZCA9IHNzX2luYm91bmQoYykKICAgICAgICBwcmludChpbmJvdW5kWydwb3J0J10gaWYg
aW5ib3VuZCBlbHNlIDApCiAgICBlbGlmIGFjdGlvbiBpbiAoJ3NzLXNoYXJlJywgJ3NzLWluZm8n
KToKICAgICAgICBjID0ganNvbi5sb2FkKG9wZW4oc3lzLmFyZ3ZbMl0sIGVuY29kaW5nPSd1dGYt
OCcpKQogICAgICAgIGhvc3QgPSBqc29uLmxvYWQob3BlbihzeXMuYXJndlszXSwgZW5jb2Rpbmc9
J3V0Zi04JykpWydob3N0J10KICAgICAgICBpbmJvdW5kID0gc3NfaW5ib3VuZChjKQogICAgICAg
IHN0YXRlX2ZpbGUgPSBvcy5wYXRoLmpvaW4ob3MucGF0aC5kaXJuYW1lKHN5cy5hcmd2WzNdKSwg
J3N0YXRlLmpzb24nKQogICAgICAgIGFsaWFzID0ganNvbi5sb2FkKG9wZW4oc3RhdGVfZmlsZSwg
ZW5jb2Rpbmc9J3V0Zi04JykpLmdldCgnZG9tYWluJywgaG9zdCkgaWYgb3MucGF0aC5pc2ZpbGUo
c3RhdGVfZmlsZSkgZWxzZSBob3N0CiAgICAgICAgbGluayA9IHNzX3NoYXJlKGMsIGhvc3QsIGFs
aWFzKQogICAgICAgIGlmIGFjdGlvbiA9PSAnc3MtaW5mbyc6CiAgICAgICAgICAgIHByaW50KCfm
nI3liqHlmajvvJp7fVxu56uv5Y+j77yae31cbuWKoOWvhu+8mnt9XG7lr4bnoIHvvJp7fVxu5Lyg
6L6T77yaVENQXG7pk77mjqXvvJp7fScuZm9ybWF0KAogICAgICAgICAgICAgICAgaG9zdCwgaW5i
b3VuZFsncG9ydCddLCBpbmJvdW5kWydzZXR0aW5ncyddWydtZXRob2QnXSwgaW5ib3VuZFsnc2V0
dGluZ3MnXVsncGFzc3dvcmQnXSwgbGluaykpCiAgICAgICAgZWxzZTogcHJpbnQobGluaykKICAg
IGVsc2U6CiAgICAgICAgcmFpc2UgVmFsdWVFcnJvcigndW5rbm93biBhY3Rpb24nKQoKCmlmIF9f
bmFtZV9fID09ICdfX21haW5fXyc6CiAgICBtYWluKCkK
ALVINLV_CONFIG_BASE64
}

write_cleanup() {
    cat <<'ALVINLV_CLEANUP_BASE64' | base64 -d > "$1"
IiIiT3duZXJzaGlwLWF3YXJlIGZpeGVkLXBhdGggY2xlYW51cCBmb3IgdGhlIEFsdmluTHYgVjJG
bHkgaW5zdGFsbGVyLiIiIgpmcm9tIHBhdGhsaWIgaW1wb3J0IFBhdGgKaW1wb3J0IGpzb24KaW1w
b3J0IHNodXRpbAppbXBvcnQgc3lzCgpNQVJLRVIgPSAnL3Zhci9saWIvYWx2aW5sdi12MmZseS9p
bnN0YWxsLnN0YXRlJwpTSUdOQVRVUkUgPSAnYWx2aW5sdi12MmZseS12MScKRklMRVMgPSAoCiAg
ICAnL3Vzci9sb2NhbC9iaW4vdjJyYXknLCAnL3Vzci9sb2NhbC9iaW4vdjJjdGwnLAogICAgJy91
c3IvbG9jYWwvbGliZXhlYy9hbHZpbmx2LXYyZmx5L3YycmF5LWNvcmUnLAogICAgJy91c3IvbG9j
YWwvc2hhcmUvdjJyYXkvZ2VvaXAuZGF0JywgJy91c3IvbG9jYWwvc2hhcmUvdjJyYXkvZ2Vvc2l0
ZS5kYXQnLAogICAgJy91c3IvbG9jYWwvZXRjL3YycmF5L2NvbmZpZy5qc29uJywKICAgICcvZXRj
L3N5c3RlbWQvc3lzdGVtL3YycmF5LnNlcnZpY2UnLCAnL2V0Yy9zeXN0ZW1kL3N5c3RlbS92MnJh
eUAuc2VydmljZScsCiAgICAnL2V0Yy9zeXN0ZW1kL3N5c3RlbS92MnJheS5zZXJ2aWNlLmQvMTAt
ZG9ub3RfdG91Y2hfc2luZ2xlX2NvbmYuY29uZicsCiAgICAnL2V0Yy9zeXN0ZW1kL3N5c3RlbS92
MnJheS5zZXJ2aWNlLmQvMjAtYWx2aW5sdi5jb25mJywKICAgICcvZXRjL3N5c3RlbWQvc3lzdGVt
L3YycmF5QC5zZXJ2aWNlLmQvMTAtZG9ub3RfdG91Y2hfc2luZ2xlX2NvbmYuY29uZicsCiAgICAn
L3Zhci9sb2cvdjJyYXkvYWNjZXNzLmxvZycsICcvdmFyL2xvZy92MnJheS9lcnJvci5sb2cnLAog
ICAgJy9ldGMvYWx2aW5sdi12MmZseS9jbGllbnQuanNvbicsICcvZXRjL2FsdmlubHYtdjJmbHkv
c3RhdGUuanNvbicsCiAgICAnL2V0Yy9hbHZpbmx2LXYyZmx5L2NvbmZpZy5weScsICcvZXRjL2Fs
dmlubHYtdjJmbHkvc3MuanNvbicsCikKQ0FERFlfRklMRVMgPSAoJy9ldGMvY2FkZHkvQ2FkZHlm
aWxlJywgJy9ldGMvY2FkZHkvYWx2aW5sdi10bHMvY2VydC5wZW0nLCAnL2V0Yy9jYWRkeS9hbHZp
bmx2LXRscy9rZXkucGVtJykKRElSUyA9ICgnL3Vzci9sb2NhbC9saWJleGVjL2FsdmlubHYtdjJm
bHknLCAnL3Vzci9sb2NhbC9zaGFyZS92MnJheScsICcvdXNyL2xvY2FsL2V0Yy92MnJheScsCiAg
ICAgICAgJy9ldGMvc3lzdGVtZC9zeXN0ZW0vdjJyYXkuc2VydmljZS5kJywgJy9ldGMvc3lzdGVt
ZC9zeXN0ZW0vdjJyYXlALnNlcnZpY2UuZCcsCiAgICAgICAgJy92YXIvbG9nL3YycmF5JywgJy9l
dGMvYWx2aW5sdi12MmZseScsICcvZXRjL2NhZGR5L2FsdmlubHYtdGxzJywgJy9ldGMvY2FkZHkn
LCAnL3Zhci9saWIvYWx2aW5sdi12MmZseScpCk9MRF9TVEFURSA9ICcvdmFyL2xpYi9hbHZpbmx2
LXYycmF5JwpPTERfRklMRVMgPSAoJy91c3IvbG9jYWwvYmluL3hyYXknLCAnL3Vzci9sb2NhbC9i
aW4vYWx2aW5sdi12MnJheScsICcvdXNyL2xvY2FsL2V0Yy94cmF5L2NvbmZpZy5qc29uJywKICAg
ICAgICAgICAgICcvZXRjL3N5c3RlbWQvc3lzdGVtL3hyYXkuc2VydmljZScsICcvZXRjL3N5c3Rl
bWQvc3lzdGVtL3hyYXlALnNlcnZpY2UnLAogICAgICAgICAgICAgJy9ldGMvc3lzdGVtZC9zeXN0
ZW0veHJheS5zZXJ2aWNlLmQvMTAtZG9ub3RfdG91Y2hfc2luZ2xlX2NvbmYuY29uZicsCiAgICAg
ICAgICAgICAnL2V0Yy9zeXN0ZW1kL3N5c3RlbS94cmF5QC5zZXJ2aWNlLmQvMTAtZG9ub3RfdG91
Y2hfc2luZ2xlX2NvbmYuY29uZicsCiAgICAgICAgICAgICAnL3Zhci93d3cvYWx2aW5sdi12MnJh
eS9pbmRleC5odG1sJywgJy9ldGMvc3lzdGVtZC9zeXN0ZW0veHJheS5zZXJ2aWNlLmQvOTAtYWx2
aW5sdi5jb25mJykKT0xEX0NBRERZID0gKCcvZXRjL2NhZGR5L0NhZGR5ZmlsZScsICcvZXRjL2Nh
ZGR5L2FsdmlubHYtdGxzL2Z1bGxjaGFpbi5wZW0nLAogICAgICAgICAgICAgJy9ldGMvY2FkZHkv
YWx2aW5sdi10bHMvcHJpdmtleS5wZW0nLCAnL2V0Yy9jYWRkeS9hbHZpbmx2LXRscy9jbG91ZGZs
YXJlLW9yaWdpbi1yb290cy5wZW0nKQpPTERfRElSUyA9ICgnL3Vzci9sb2NhbC9ldGMveHJheScs
ICcvZXRjL3N5c3RlbWQvc3lzdGVtL3hyYXkuc2VydmljZS5kJywKICAgICAgICAgICAgJy9ldGMv
c3lzdGVtZC9zeXN0ZW0veHJheUAuc2VydmljZS5kJywgJy92YXIvd3d3L2FsdmlubHYtdjJyYXkn
KQpDT05GTElDVFMgPSAoTUFSS0VSLCAnL3Zhci9saWIvYWx2aW5sdi12MmZseScsICcvZXRjL2Fs
dmlubHYtdjJmbHknLCAnL3Vzci9sb2NhbC9saWJleGVjL2FsdmlubHYtdjJmbHknLAogICAgICAg
ICAgICAgJy91c3IvbG9jYWwvZXRjL3YycmF5JywgJy91c3IvbG9jYWwvc2hhcmUvdjJyYXknLCAn
L3Zhci9sb2cvdjJyYXknLCAnL3Vzci9sb2NhbC9iaW4vdjJyYXknLAogICAgICAgICAgICAgJy91
c3IvbG9jYWwvYmluL3YyY3RsJywgJy91c3IvbG9jYWwvZXRjL3hyYXknLCAnL2V0Yy92MnJheScs
ICcvZXRjL3hyYXknLCAnL2V0Yy9jYWRkeScsCiAgICAgICAgICAgICAnL2V0Yy9zeXN0ZW1kL3N5
c3RlbS92MnJheS5zZXJ2aWNlJywgJy9ldGMvc3lzdGVtZC9zeXN0ZW0vdjJyYXlALnNlcnZpY2Un
LAogICAgICAgICAgICAgJy9ldGMvc3lzdGVtZC9zeXN0ZW0vdjJyYXkuc2VydmljZS5kJywgJy9l
dGMvc3lzdGVtZC9zeXN0ZW0vdjJyYXlALnNlcnZpY2UuZCcsCiAgICAgICAgICAgICAnL2V0Yy9z
eXN0ZW1kL3N5c3RlbS94cmF5LnNlcnZpY2UnLCAnL3Vzci9sb2NhbC9iaW4veHJheScpCgoKZGVm
IHRhcmdldChyb290LCBuYW1lKToKICAgIHJvb3QgPSBQYXRoKHJvb3QpCiAgICBjdXJyZW50ID0g
cm9vdAogICAgcGFydHMgPSBuYW1lLmxzdHJpcCgnLycpLnNwbGl0KCcvJykKICAgIGZvciBwYXJ0
IGluIHBhcnRzWzotMV06CiAgICAgICAgY3VycmVudCA9IGN1cnJlbnQgLyBwYXJ0CiAgICAgICAg
aWYgY3VycmVudC5pc19zeW1saW5rKCk6CiAgICAgICAgICAgIHJhaXNlIFZhbHVlRXJyb3IoJ+aL
kue7nee7j+i/h+espuWPt+mTvuaOpeebruW9le+8micgKyBzdHIoY3VycmVudCkpCiAgICByZXR1
cm4gY3VycmVudCAvIHBhcnRzWy0xXQoKCmRlZiBwaGFzZShyb290KToKICAgIG1hcmtlciA9IHRh
cmdldChyb290LCBNQVJLRVIpCiAgICBpZiBtYXJrZXIuaXNfZmlsZSgpIGFuZCBub3QgbWFya2Vy
LmlzX3N5bWxpbmsoKToKICAgICAgICBsaW5lcyA9IG1hcmtlci5yZWFkX3RleHQoZW5jb2Rpbmc9
J3V0Zi04Jykuc3BsaXRsaW5lcygpCiAgICAgICAgaWYgbGVuKGxpbmVzKSA9PSAyIGFuZCBsaW5l
c1swXSA9PSBTSUdOQVRVUkUgYW5kIGxpbmVzWzFdIGluICgnYmVnaW4nLCAnY29yZScsICdjYWRk
eScsICdjb21wbGV0ZScpOgogICAgICAgICAgICByZXR1cm4gbGluZXNbMV0KICAgIHN0YXRlID0g
dGFyZ2V0KHJvb3QsICcvZXRjL2FsdmlubHYtdjJmbHkvc3RhdGUuanNvbicpCiAgICBjb3JlID0g
dGFyZ2V0KHJvb3QsICcvdXNyL2xvY2FsL2xpYmV4ZWMvYWx2aW5sdi12MmZseS92MnJheS1jb3Jl
JykKICAgIGRyb3BpbiA9IHRhcmdldChyb290LCAnL2V0Yy9zeXN0ZW1kL3N5c3RlbS92MnJheS5z
ZXJ2aWNlLmQvMjAtYWx2aW5sdi5jb25mJykKICAgIGlmIGFsbChwLmlzX2ZpbGUoKSBhbmQgbm90
IHAuaXNfc3ltbGluaygpIGZvciBwIGluIChzdGF0ZSwgY29yZSwgZHJvcGluKSk6CiAgICAgICAg
aWYgJy91c3IvbG9jYWwvbGliZXhlYy9hbHZpbmx2LXYyZmx5L3YycmF5LWNvcmUnIGluIGRyb3Bp
bi5yZWFkX3RleHQoZW5jb2Rpbmc9J3V0Zi04Jyk6CiAgICAgICAgICAgIHJldHVybiAnbGVnYWN5
JwogICAgcmV0dXJuICcnCgoKZGVmIG93bmVkKHJvb3QpOgogICAgcmV0dXJuIGJvb2wocGhhc2Uo
cm9vdCkpCgoKZGVmIGNvbmZsaWN0cyhyb290KToKICAgIHJldHVybiBbbmFtZSBmb3IgbmFtZSBp
biBDT05GTElDVFMgaWYgdGFyZ2V0KHJvb3QsIG5hbWUpLmV4aXN0cygpIG9yIHRhcmdldChyb290
LCBuYW1lKS5pc19zeW1saW5rKCldCgoKZGVmIG9sZF94cmF5X293bmVkKHJvb3QpOgogICAgZHJv
cGluID0gdGFyZ2V0KHJvb3QsICcvZXRjL3N5c3RlbWQvc3lzdGVtL3hyYXkuc2VydmljZS5kLzkw
LWFsdmlubHYuY29uZicpCiAgICBhdHRlbXB0ID0gdGFyZ2V0KHJvb3QsIE9MRF9TVEFURSArICcv
YXR0ZW1wdC5qc29uJykKICAgIGlmIG5vdCAoZHJvcGluLmlzX2ZpbGUoKSBhbmQgYXR0ZW1wdC5p
c19maWxlKCkpIG9yIGRyb3Bpbi5pc19zeW1saW5rKCkgb3IgYXR0ZW1wdC5pc19zeW1saW5rKCk6
IHJldHVybiBGYWxzZQogICAgdHJ5OgogICAgICAgIHRleHQgPSBkcm9waW4ucmVhZF90ZXh0KGVu
Y29kaW5nPSd1dGYtOCcpCiAgICAgICAgZGF0YSA9IGpzb24ubG9hZHMoYXR0ZW1wdC5yZWFkX3Rl
eHQoZW5jb2Rpbmc9J3V0Zi04JykpCiAgICAgICAgcmV0dXJuICdNYW5hZ2VkIGJ5IEFsdmluTHYn
IGluIHRleHQgYW5kICdVc2VyPWFsdmlubHYtdjJyYXknIGluIHRleHQgYW5kIGRhdGEuZ2V0KCdw
cm90b2NvbCcpIGluICgncmVhbGl0eScsICd2bGVzcy13cycsICd0cm9qYW4td3MnLCAneGh0dHAn
KQogICAgZXhjZXB0IChWYWx1ZUVycm9yLCBPU0Vycm9yLCBBdHRyaWJ1dGVFcnJvcik6CiAgICAg
ICAgcmV0dXJuIEZhbHNlCgoKZGVmIG9sZF94cmF5X3BhdGhzKHJvb3QsIGNhZGR5PUZhbHNlKToK
ICAgIGlmIG5vdCBvbGRfeHJheV9vd25lZChyb290KTogcmFpc2UgVmFsdWVFcnJvcign5pyq5Y+R
546w5Y+v5qC45a6e55qE5pen54mIIEFsdmluTHYgWHJheSDlronoo4UnKQogICAgbmFtZXMgPSBb
T0xEX1NUQVRFXSArIGxpc3QoT0xEX0ZJTEVTKSArIChsaXN0KE9MRF9DQUREWSkgaWYgY2FkZHkg
ZWxzZSBbXSkKICAgIHJldHVybiBbbmFtZSBmb3IgbmFtZSBpbiBuYW1lcyBpZiB0YXJnZXQocm9v
dCwgbmFtZSkuZXhpc3RzKCkgb3IgdGFyZ2V0KHJvb3QsIG5hbWUpLmlzX3N5bWxpbmsoKV0KCgpk
ZWYgcmVtb3ZlX29sZF94cmF5KHJvb3QsIGNhZGR5PUZhbHNlKToKICAgIGlmIG5vdCBvbGRfeHJh
eV9vd25lZChyb290KTogcmFpc2UgVmFsdWVFcnJvcign5pyq5Y+R546w5Y+v5qC45a6e55qE5pen
54mIIEFsdmluTHYgWHJheSDlronoo4UnKQogICAgZm9yIG5hbWUgaW4gbGlzdChPTERfRklMRVMp
ICsgKGxpc3QoT0xEX0NBRERZKSBpZiBjYWRkeSBlbHNlIFtdKToKICAgICAgICBwYXRoID0gdGFy
Z2V0KHJvb3QsIG5hbWUpCiAgICAgICAgaWYgcGF0aC5pc19zeW1saW5rKCkgb3IgcGF0aC5pc19m
aWxlKCk6IHBhdGgudW5saW5rKCkKICAgIGRpcnMgPSBsaXN0KE9MRF9ESVJTKSArIChbJy9ldGMv
Y2FkZHkvYWx2aW5sdi10bHMnLCAnL2V0Yy9jYWRkeSddIGlmIGNhZGR5IGVsc2UgW10pCiAgICBm
b3IgbmFtZSBpbiBkaXJzOgogICAgICAgIHBhdGggPSB0YXJnZXQocm9vdCwgbmFtZSkKICAgICAg
ICBpZiBwYXRoLmlzX2RpcigpIGFuZCBub3QgcGF0aC5pc19zeW1saW5rKCk6CiAgICAgICAgICAg
IHRyeTogcGF0aC5ybWRpcigpCiAgICAgICAgICAgIGV4Y2VwdCBPU0Vycm9yOiBwYXNzCiAgICBz
dGF0ZSA9IHRhcmdldChyb290LCBPTERfU1RBVEUpCiAgICBpZiBzdGF0ZS5pc19zeW1saW5rKCk6
IHJhaXNlIFZhbHVlRXJyb3IoJ+aXp+eJiOeKtuaAgeebruW9leaYr+espuWPt+mTvuaOpe+8jOaL
kue7nemAkuW9kua4heeQhicpCiAgICBpZiBzdGF0ZS5pc19kaXIoKTogc2h1dGlsLnJtdHJlZShz
dHIoc3RhdGUpKQoKCmRlZiByZW1vdmVfb3duZWQocm9vdCwgY2FkZHk9RmFsc2UpOgogICAgaWYg
bm90IG93bmVkKHJvb3QpOgogICAgICAgIHJhaXNlIFZhbHVlRXJyb3IoJ+ayoeacieWPr+mqjOiv
geeahOacrOiEmuacrOWuieijheagh+iusCcpCiAgICBzdGFnZSA9IHBoYXNlKHJvb3QpCiAgICBm
aWxlcyA9IGxpc3QoRklMRVMgaWYgc3RhZ2UgIT0gJ2JlZ2luJyBlbHNlICgpKQogICAgZmlsZXMu
ZXh0ZW5kKCgnL3Zhci9saWIvYWx2aW5sdi12MmZseS9yZXN1bWUuanNvbicsICcvdmFyL2xpYi9h
bHZpbmx2LXYyZmx5L3Jlc3VtZS5qc29uLnRtcCcsICcvdmFyL2xpYi9hbHZpbmx2LXYyZmx5L2Nh
ZGR5LXBhY2thZ2Uuc2hhMjU2JykpCiAgICBpZiBjYWRkeSBhbmQgc3RhZ2UgaW4gKCdjYWRkeScs
ICdjb21wbGV0ZScsICdsZWdhY3knKToKICAgICAgICBmaWxlcy5leHRlbmQoQ0FERFlfRklMRVMp
CiAgICBmb3IgbmFtZSBpbiBmaWxlczoKICAgICAgICBwYXRoID0gdGFyZ2V0KHJvb3QsIG5hbWUp
CiAgICAgICAgaWYgcGF0aC5pc19zeW1saW5rKCkgb3IgcGF0aC5pc19maWxlKCk6CiAgICAgICAg
ICAgIHBhdGgudW5saW5rKCkKICAgIGRpcnMgPSBsaXN0KERJUlMgaWYgc3RhZ2UgIT0gJ2JlZ2lu
JyBlbHNlICgnL3Zhci9saWIvYWx2aW5sdi12MmZseScsKSkKICAgIGlmIG5vdCBjYWRkeSBvciBz
dGFnZSBub3QgaW4gKCdjYWRkeScsICdjb21wbGV0ZScsICdsZWdhY3knKToKICAgICAgICBkaXJz
ID0gW25hbWUgZm9yIG5hbWUgaW4gZGlycyBpZiBub3QgbmFtZS5zdGFydHN3aXRoKCcvZXRjL2Nh
ZGR5JyldCiAgICBmb3IgbmFtZSBpbiBkaXJzOgogICAgICAgIHBhdGggPSB0YXJnZXQocm9vdCwg
bmFtZSkKICAgICAgICBpZiBwYXRoLmlzX2RpcigpIGFuZCBub3QgcGF0aC5pc19zeW1saW5rKCk6
CiAgICAgICAgICAgIHRyeTogcGF0aC5ybWRpcigpCiAgICAgICAgICAgIGV4Y2VwdCBPU0Vycm9y
OiBwYXNzICAjIFByZXNlcnZlIGZpbGVzIHRoYXQgYXJlIG5vdCBleHBsaWNpdGx5IG93bmVkLgog
ICAgbWFya2VyID0gdGFyZ2V0KHJvb3QsIE1BUktFUikKICAgIGlmIG1hcmtlci5pc19maWxlKCkg
YW5kIG5vdCBtYXJrZXIuaXNfc3ltbGluaygpOiBtYXJrZXIudW5saW5rKCkKICAgIHRyeTogdGFy
Z2V0KHJvb3QsICcvdmFyL2xpYi9hbHZpbmx2LXYyZmx5Jykucm1kaXIoKQogICAgZXhjZXB0IE9T
RXJyb3I6IHBhc3MKCgpkZWYgbWFpbigpOgogICAgaWYgbGVuKHN5cy5hcmd2KSA9PSAyIGFuZCBz
eXMuYXJndlsxXSA9PSAncGhhc2UnOgogICAgICAgIHByaW50KHBoYXNlKCcvJykpCiAgICBlbGlm
IGxlbihzeXMuYXJndikgPT0gMiBhbmQgc3lzLmFyZ3ZbMV0gPT0gJ2NvbmZsaWN0cyc6CiAgICAg
ICAgZm9yIG5hbWUgaW4gY29uZmxpY3RzKCcvJyk6IHByaW50KG5hbWUpCiAgICBlbGlmIGxlbihz
eXMuYXJndikgPT0gMiBhbmQgc3lzLmFyZ3ZbMV0gPT0gJ29sZC14cmF5JzoKICAgICAgICBwcmlu
dCgneWVzJyBpZiBvbGRfeHJheV9vd25lZCgnLycpIGVsc2UgJycpCiAgICBlbGlmIGxlbihzeXMu
YXJndikgPT0gMyBhbmQgc3lzLmFyZ3ZbMV0gPT0gJ29sZC1wbGFuJyBhbmQgc3lzLmFyZ3ZbMl0g
aW4gKCdjYWRkeScsICduby1jYWRkeScpOgogICAgICAgIGZvciBuYW1lIGluIG9sZF94cmF5X3Bh
dGhzKCcvJywgc3lzLmFyZ3ZbMl0gPT0gJ2NhZGR5Jyk6IHByaW50KG5hbWUpCiAgICBlbGlmIGxl
bihzeXMuYXJndikgPT0gMyBhbmQgc3lzLmFyZ3ZbMV0gPT0gJ29sZC1yZW1vdmUnIGFuZCBzeXMu
YXJndlsyXSBpbiAoJ2NhZGR5JywgJ25vLWNhZGR5Jyk6CiAgICAgICAgcmVtb3ZlX29sZF94cmF5
KCcvJywgc3lzLmFyZ3ZbMl0gPT0gJ2NhZGR5JykKICAgIGVsaWYgbGVuKHN5cy5hcmd2KSA9PSAz
IGFuZCBzeXMuYXJndlsxXSA9PSAncGxhbicgYW5kIHN5cy5hcmd2WzJdIGluICgnY2FkZHknLCAn
bm8tY2FkZHknKToKICAgICAgICBzdGFnZSA9IHBoYXNlKCcvJykKICAgICAgICBpZiBub3Qgc3Rh
Z2U6IHJhaXNlIFZhbHVlRXJyb3IoJ+ayoeacieWPr+mqjOivgeeahOacrOiEmuacrOWuieijheag
h+iusCcpCiAgICAgICAgZmlsZXMgPSBsaXN0KEZJTEVTIGlmIHN0YWdlICE9ICdiZWdpbicgZWxz
ZSAoKSkKICAgICAgICBmaWxlcy5leHRlbmQoKCcvdmFyL2xpYi9hbHZpbmx2LXYyZmx5L3Jlc3Vt
ZS5qc29uJywgJy92YXIvbGliL2FsdmlubHYtdjJmbHkvcmVzdW1lLmpzb24udG1wJywgJy92YXIv
bGliL2FsdmlubHYtdjJmbHkvY2FkZHktcGFja2FnZS5zaGEyNTYnKSkKICAgICAgICBpZiBzeXMu
YXJndlsyXSA9PSAnY2FkZHknIGFuZCBzdGFnZSBpbiAoJ2NhZGR5JywgJ2NvbXBsZXRlJywgJ2xl
Z2FjeScpOiBmaWxlcy5leHRlbmQoQ0FERFlfRklMRVMpCiAgICAgICAgZm9yIG5hbWUgaW4gZmls
ZXMgKyBbTUFSS0VSXToKICAgICAgICAgICAgaWYgdGFyZ2V0KCcvJywgbmFtZSkuZXhpc3RzKCkg
b3IgdGFyZ2V0KCcvJywgbmFtZSkuaXNfc3ltbGluaygpOiBwcmludChuYW1lKQogICAgZWxpZiBs
ZW4oc3lzLmFyZ3YpID09IDMgYW5kIHN5cy5hcmd2WzFdID09ICdyZW1vdmUnIGFuZCBzeXMuYXJn
dlsyXSBpbiAoJ2NhZGR5JywgJ25vLWNhZGR5Jyk6CiAgICAgICAgcmVtb3ZlX293bmVkKCcvJywg
c3lzLmFyZ3ZbMl0gPT0gJ2NhZGR5JykKICAgIGVsc2U6CiAgICAgICAgcmFpc2UgU3lzdGVtRXhp
dCgnaW52YWxpZCBjbGVhbnVwIGFjdGlvbicpCgoKaWYgX19uYW1lX18gPT0gJ19fbWFpbl9fJzog
bWFpbigpCg==
ALVINLV_CLEANUP_BASE64
}

mark_phase() { printf 'alvinlv-v2fly-v1\n%s\n' "$1" > "$MARKER"; chmod 600 "$MARKER"; }

collect_exit() {
    local kind host port user pass expected
    printf '\n'; menu_print '1) SOCKS5' '2) HTTP CONNECT' '0) 取消'
    choice '上游类型 [1]: ' 1; kind=$REPLY
    case $kind in 1) kind=socks ;; 2) kind=http ;; 0) return 1 ;; *) echo '选项无效'; return 1 ;; esac
    read -r -p '住宅代理主机名或 IP: ' host || return 1
    read -r -p '住宅代理端口: ' port || return 1
    read -r -p '用户名（IP 白名单认证直接回车）: ' user || return 1
    pass=''; if [[ -n $user ]]; then read -rs -p '密码（隐藏输入）: ' pass || return 1; echo; fi
    [[ $host =~ ^[a-zA-Z0-9.:-]+$ && $port =~ ^[0-9]{1,5}$ ]] || { echo '主机或端口格式错误'; return 1; }
    (( 10#$port >= 1 && 10#$port <= 65535 )) || { echo '端口范围错误'; return 1; }
    [[ -z $user || -n $pass ]] || { echo '密码不能为空'; return 1; }
    read -r -p '预期固定出口 IP（可选；动态住宅池直接回车）: ' expected || return 1
    if [[ -n $expected ]]; then python3 -c 'import ipaddress,sys; ipaddress.ip_address(sys.argv[1])' "$expected" >/dev/null 2>&1 || { echo '预期 IP 格式不正确'; return 1; }; fi
    printf '%s\0' "$kind" "$host" "$port" "$user" "$pass" "$expected" | python3 -c 'import json,sys; a=sys.stdin.buffer.read().decode().split("\0"); json.dump(dict(type=a[0],host=a[1],port=int(a[2]),username=a[3],password=a[4],expected_ip=a[5]),sys.stdout)' > "$WORK/exit.json"
    unset pass
}

collect_optional_exit() {
    printf 'null' > "$WORK/exit.json"
    if yesno '是否配置住宅代理出口'; then
        collect_exit || die '住宅出口未完成，已停止安装；不会自动改用 VPS 直连'
    fi
}

customize_node() {
    local input
    BACKEND_PORT=18080
    if yesno '是否自定义 WebSocket 路径、本机端口或节点身份'; then
        read -r -p 'WebSocket 路径（回车自动生成）: ' input || die '输入结束'
        [[ -z $input ]] || path=$input
        read -r -p '本机后端端口（回车使用 18080）: ' input || die '输入结束'
        [[ -z $input ]] || BACKEND_PORT=$input
        if [[ $PROTO == trojan ]]; then
            read -rs -p 'Trojan 密码（回车自动生成，至少 16 字符）: ' input || die '输入结束'; echo
            [[ -z $input ]] || password=$input
        else
            read -r -p 'UUID（回车自动生成）: ' input || die '输入结束'
            [[ -z $input ]] || uuid=$input
        fi
    fi
    write_helper "$WORK/wizard-config.py"
    printf '%s\0' "$path" "$BACKEND_PORT" "$PROTO" "$password" "$uuid" | python3 -c 'import json,sys; a=sys.stdin.buffer.read().decode().split("\0"); json.dump(dict(path=a[0],port=int(a[1]),protocol=a[2],password=a[3],uuid=a[4]),sys.stdout)' | python3 "$WORK/wizard-config.py" validate-node || die '高级选项无效，已停止安装'
}

check_platform() {
    [[ -r /etc/os-release ]] || die '无法识别系统'
    FAMILY=$(
        unset ID VERSION_ID NAME
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}:${VERSION_ID:-}" in
            debian:12|debian:13|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04) printf '%s' apt ;;
            rocky:8|rocky:8.*|rocky:9|rocky:9.*|rocky:10|rocky:10.*) printf '%s' dnf ;;
            centos:9|centos:10) [[ ${NAME:-} == *Stream* ]] || die 'CentOS 仅支持 Stream 9/10'; printf '%s' dnf ;;
            *) die '系统不在支持范围：Debian 12/13、Ubuntu 22.04/24.04/26.04、Rocky 8/9/10、CentOS Stream 9/10' ;;
        esac
    ) || return 1
    case $(uname -m) in x86_64|aarch64) ;; *) die '仅支持 x86_64/ARM64' ;; esac
}

guard_fresh() {
    local scan found
    scan=$(mktemp); write_cleanup "$scan"
    found=$(python3 "$scan" conflicts); rm -f "$scan"
    if [[ -n $found ]]; then printf '\n%s\n%s\n' '检测到以下冲突路径（不显示配置内容）：' "$found"; fi
    local program
    for program in v2ray xray caddy; do
        if command -v "$program" >/dev/null; then printf '检测到程序：%s\n' "$(command -v "$program")"; fi
    done
    [[ ! -e $STATE && ! -e /var/lib/alvinlv-v2fly && ! -e /usr/local/libexec/alvinlv-v2fly && ! -e /usr/local/etc/v2ray && ! -e /usr/local/share/v2ray && ! -e /var/log/v2ray && ! -e /usr/local/bin/v2ctl && ! -e /usr/local/etc/xray && ! -e /etc/v2ray && ! -e /etc/xray && ! -e /etc/caddy && ! -e /etc/systemd/system/v2ray.service && ! -e /etc/systemd/system/v2ray@.service && ! -e /etc/systemd/system/v2ray.service.d && ! -e /etc/systemd/system/v2ray@.service.d && ! -e /etc/systemd/system/xray.service ]] || die '发现现有 V2Ray、Xray、Caddy 或历史配置。可选择卸载菜单检查本脚本的残留，不会自动覆盖'
    if command -v v2ray >/dev/null || command -v xray >/dev/null || command -v caddy >/dev/null; then die '发现已有 V2Ray/Xray/Caddy 程序，不会覆盖'; fi
    if command -v dpkg-query >/dev/null && dpkg-query -W -f='${Status}' caddy 2>/dev/null | grep -q 'install ok installed'; then die '检测到已安装的 Caddy 软件包，不会覆盖'; fi
    if command -v rpm >/dev/null && rpm -q caddy >/dev/null 2>&1; then die '检测到已安装的 Caddy 软件包，不会覆盖'; fi
    if getent passwd alvinlv-v2fly >/dev/null || getent group alvinlv-v2fly >/dev/null; then die '专用账户已存在，停止安装'; fi
    local port
    for port in 80 443 2019; do
        [[ -z $(ss -H -ltn "sport = :$port") ]] || die "端口 $port 已被占用；不会停止已有进程"
    done
}

old_xray_migration() {
    local plan=no-caddy answer backup item remove_caddy=0
    local -a paths=() archive_paths=()
    printf '\n%s\n' '识别到旧版 AlvinLv Xray。迁移将停止旧 Xray 并清理其专属安装文件。' '原来的节点将断开；住宅代理凭据、配置和密钥将先备份到 root 目录。'
    if yesno '同时卸载旧部署使用的 Caddy 软件包及配置（会影响复用 Caddy 的其他网站）'; then
        remove_caddy=1; plan=caddy
    fi
    mapfile -t paths < <(python3 "$WORK/cleanup.py" old-plan "$plan")
    printf '%s\n' '准备备份并清理以下路径：'; printf '  %s\n' "${paths[@]}"
    if [[ $remove_caddy == 1 ]]; then
        printf '%s\n' 'Caddy 软件包操作预览：'
        if command -v dpkg-query >/dev/null && dpkg-query -W -f='${Status}' caddy 2>/dev/null | grep -q 'install ok installed'; then
            apt-get -s purge caddy || die '无法预览 Caddy 软件包操作'
        elif command -v rpm >/dev/null && rpm -q caddy >/dev/null 2>&1; then
            dnf remove --assumeno caddy || true
        fi
    fi
    read -r -p '输入 MIGRATE 确认备份并卸载旧版；其他内容取消: ' answer || return 0
    [[ $answer == MIGRATE ]] || { echo '已取消'; return 0; }
    command -v tar >/dev/null || die '需要 tar 创建备份，未开始清理'
    backup=$(mktemp /root/alvinlv-xray-backup-XXXXXXXX.tar.gz)
    for item in "${paths[@]}"; do archive_paths+=("${item#/}"); done
    if ! tar -C / -czf "$backup" -- "${archive_paths[@]}" || ! tar -tzf "$backup" >/dev/null; then
        rm -f "$backup"; die '备份失败，旧服务和文件未删除'
    fi
    chmod 600 "$backup"
    printf '备份已创建：%s（含敏感信息，请妥善保管）\n' "$backup"
    if systemctl is-active --quiet xray; then systemctl stop xray || die '无法停止 Xray，保留原文件'; fi
    systemctl disable xray 2>/dev/null || true
    if [[ $remove_caddy == 1 ]]; then
        if systemctl is-active --quiet caddy; then systemctl stop caddy || die '无法停止 Caddy，保留原文件'; fi
        systemctl disable caddy 2>/dev/null || true
        if command -v dpkg-query >/dev/null && dpkg-query -W -f='${Status}' caddy 2>/dev/null | grep -q 'install ok installed'; then
            DEBIAN_FRONTEND=noninteractive apt-get purge -y caddy || die 'Caddy 卸载失败，旧配置已备份'
        elif command -v rpm >/dev/null && rpm -q caddy >/dev/null 2>&1; then
            dnf remove -y caddy || die 'Caddy 卸载失败，旧配置已备份'
        fi
    fi
    if getent passwd alvinlv-v2ray >/dev/null; then userdel alvinlv-v2ray || die '旧版专用用户删除失败，旧配置已备份'; fi
    if getent group alvinlv-v2ray >/dev/null; then groupdel alvinlv-v2ray || die '旧版专用组删除失败，旧配置已备份'; fi
    python3 "$WORK/cleanup.py" old-remove "$plan"
    systemctl daemon-reload
    echo '旧版清理完成。请重新运行脚本选择安装；若仍有冲突，按新显示的具体路径检查。'
    [[ $remove_caddy == 1 ]] || echo '已保留 Caddy；它可能仍阻止安装。'
}

deps() {
    if [[ $FAMILY == apt ]]; then
        apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl python3 unzip gnupg openssl iproute2
    else
        local packages=(ca-certificates python3 unzip gnupg2 openssl iproute dnf-plugins-core)
        command -v curl >/dev/null || packages+=(curl)
        dnf install -y "${packages[@]}"
    fi
}
download() { curl --http1.1 --proto '=https' --tlsv1.2 -fsSL --retry 3 --connect-timeout 15 --max-time 180 "$1" -o "$2"; }
install_core() {
    local real_curl
    real_curl=$(command -v curl)
    mkdir -p "$WORK/curl-wrapper"
    cat > "$WORK/curl-wrapper/curl" <<'EOF'
#!/usr/bin/env bash
exec "$ALVINLV_REAL_CURL" --http1.1 "$@"
EOF
    chmod 700 "$WORK/curl-wrapper/curl"
    env -u JSONS_PATH -u JSON_PATH -u DAT_PATH PATH="$WORK/curl-wrapper:$PATH" ALVINLV_REAL_CURL="$real_curl" bash "$WORK/install.sh" --version "$V2FLY_CORE_VERSION"
}
install_caddy() {
    if [[ $FAMILY == apt ]]; then
        download https://dl.cloudsmith.io/public/caddy/stable/gpg.key "$WORK/caddy.key"
        gpg --batch --yes --dearmor --output "$WORK/caddy.gpg" "$WORK/caddy.key"
        install -m 644 "$WORK/caddy.gpg" /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        download https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt "$WORK/caddy.list"
        install -m 644 "$WORK/caddy.list" /etc/apt/sources.list.d/caddy-stable.list
        apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y caddy
    else
        dnf -y copr enable @caddy/caddy; dnf install -y caddy
    fi
    systemctl stop caddy
}

deps_ready() {
    local executable
    for executable in curl python3 unzip openssl ss; do command -v "$executable" >/dev/null || return 1; done
    if [[ $FAMILY == apt ]]; then command -v gpg >/dev/null || return 1
    else rpm -q dnf-plugins-core >/dev/null 2>&1 || return 1; fi
}

core_ready() {
    local executable=/usr/local/bin/v2ray version
    [[ -x $CORE ]] && executable=$CORE
    [[ -x $executable && -f /etc/systemd/system/v2ray.service && -f /usr/local/share/v2ray/geoip.dat && -f /usr/local/share/v2ray/geosite.dat ]] || return 1
    version=$($executable version 2>/dev/null | head -n 1) || return 1
    [[ $version == "V2Ray ${V2FLY_CORE_VERSION#v} "* ]]
}

caddy_ready() {
    command -v caddy >/dev/null && getent group caddy >/dev/null && systemctl cat caddy >/dev/null 2>&1
}

verify_installer() {
    printf '%s  %s\n' "$INSTALLER_HASH" "$WORK/install.sh" | sha256sum -c --status || die '官方安装器校验失败'
}

run_install_steps() {
    if deps_ready; then info '系统依赖已就绪，跳过'; else info '安装缺失的依赖'; deps; fi
    if core_ready; then
        info "V2Fly $V2FLY_CORE_VERSION 和服务文件已就绪，跳过下载"
    else
        if [[ -x $CORE ]]; then die '检测到现有专用内核但其版本或服务文件不完整；为保护已有安装，请先检查状态'; fi
        if [[ -e /usr/local/bin/v2ray ]]; then
            [[ -x /usr/local/bin/v2ray ]] || die '已有 V2Ray 文件不可执行，未覆盖'
            local detected_version
            detected_version=$(/usr/local/bin/v2ray version 2>/dev/null | head -n 1) || die '已有 V2Ray 程序无法识别，未覆盖'
            [[ $detected_version == "V2Ray ${V2FLY_CORE_VERSION#v} "* ]] || die '已有 V2Ray 程序版本与续装记录不匹配，未覆盖'
        fi
        info "安装 V2Fly $V2FLY_CORE_VERSION"
        download "$INSTALLER_URL" "$WORK/install.sh"
        verify_installer
        mark_phase core
        install_core
        core_ready || die 'V2Fly 内核或服务文件不完整，请查看日志后重试'
    fi
    if caddy_ready; then info 'Caddy 已就绪，跳过安装'; else mark_phase caddy; install_caddy; caddy_ready || die 'Caddy 安装不完整'; fi
    mark_phase caddy
}

install_wizard() {
    local stage scan uuid password path
    check_platform; command -v ss >/dev/null || die '请先安装 iproute/iproute2'
    scan=$(mktemp); write_cleanup "$scan"; stage=$(python3 "$scan" phase); rm -f "$scan"
    if [[ $stage == complete || $stage == legacy ]]; then info '本脚本已经安装；请使用菜单查看状态或修改配置。'; return; fi
    if [[ -z $stage ]]; then
        guard_fresh
    else
        info "检测到未完成的安装（阶段：$stage），将检查已完成的步骤并继续。"
        if command -v xray >/dev/null || [[ -e /usr/local/etc/xray || -e /etc/xray || -e /etc/systemd/system/xray.service ]]; then die '续装时发现其他 Xray 部署，已停止以免覆盖'; fi
        if [[ $stage == begin || $stage == core ]]; then
            if command -v caddy >/dev/null || [[ -e /etc/caddy ]]; then die '续装前发现非本阶段安装的 Caddy，请检查归属'; fi
        fi
    fi
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    if [[ -f $RESUME ]]; then
        info '恢复上次填写的安装选项；节点身份和住宅出口保持不变。'
        python3 - "$RESUME" "$WORK/fields" "$WORK/exit.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1], encoding='utf-8'))
s.setdefault('backend_port','18080')
keys=('domain','path','uuid','password','protocol','mode','certmode','cert','key','backend_port')
assert all(isinstance(s[k],str) for k in keys)
with open(sys.argv[2], 'wb') as f: f.write(b'\0'.join(s[k].encode() for k in keys)+b'\0')
with open(sys.argv[3], 'w', encoding='utf-8') as f: json.dump(s['exit'],f)
PY
        local -a fields
        mapfile -d '' -t fields < "$WORK/fields"
        DOMAIN=${fields[0]}; path=${fields[1]}; uuid=${fields[2]}; password=${fields[3]}; PROTO=${fields[4]}; MODE=${fields[5]}; CERTMODE=${fields[6]}; CERT=${fields[7]}; KEY=${fields[8]}; BACKEND_PORT=${fields[9]}
        unset fields
        if [[ $CERTMODE == 2 ]]; then [[ -r $CERT && -r $KEY ]] || die '上次填写的证书或私钥路径已不可读，请恢复文件后重试'; fi
    else
    if [[ -f $STATE/state.json ]]; then die '旧版未保存续装信息且已有节点配置；请先备份，避免生成新的节点身份'; fi
    [[ -z $stage ]] || info '旧版安装未保存交互信息，请重新填写；已完成的依赖和内核仍会复用。'
    printf '\n'; menu_print '入站协议：' '1) VMess + WS + TLS（默认）' '2) Trojan + WS + TLS' '3) VLESS + WS + TLS（V2Fly 已弃用，仅兼容）'
    choice '选择协议 [1]: ' 1
    case $REPLY in 1) PROTO=vmess ;; 2) PROTO=trojan ;; 3) PROTO=vless ;; *) die '选项无效' ;; esac
    printf '\n'; menu_print '入口方式：' '1) 直连 / Cloudflare 灰云' '2) Cloudflare 橙云（Full strict 回源，推荐）' '3) Cloudflare 橙云（Flexible HTTP 回源）'
    choice '选择入口 [1]: ' 1; MODE=$REPLY; [[ $MODE == 1 || $MODE == 2 || $MODE == 3 ]] || die '选项无效'
    if [[ $MODE == 3 ]]; then echo '提示：Flexible 模式的 Cloudflare → VPS 为明文 HTTP，HTTP 节点入口无来源 IP 白名单。'; fi
    read -r -p '节点域名（不含 https:// 和端口）: ' DOMAIN || die '输入结束'
    python3 - "$DOMAIN" <<'PY' || die '域名格式无效'
import re,sys
s=sys.argv[1]
assert len(s)<=253 and '.' in s and all(re.fullmatch(r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?',p) for p in s.split('.'))
PY
    menu_print '证书：' '1) Caddy 自动申请公网证书' '2) 使用已有证书和无口令私钥（橙云可用 Origin CA）'
    choice '选择证书 [1]: ' 1; CERTMODE=$REPLY; [[ $CERTMODE == 1 || $CERTMODE == 2 ]] || die '选项无效'
    if [[ $CERTMODE == 2 ]]; then
        read -r -p '证书完整链 PEM 文件路径: ' CERT || die '输入结束'
        read -r -p '私钥 PEM 文件路径: ' KEY || die '输入结束'
        [[ -r $CERT && -r $KEY ]] || die '证书或私钥不可读'
        openssl x509 -in "$CERT" -noout -checkhost "$DOMAIN" | grep -q 'does match' || die '证书域名不匹配'
        [[ $(openssl x509 -in "$CERT" -pubkey -noout | openssl pkey -pubin -outform der | sha256sum | cut -d ' ' -f1) == $(openssl pkey -in "$KEY" -pubout -outform der 2>/dev/null | sha256sum | cut -d ' ' -f1) ]] || die '证书和私钥不匹配，或私钥需要口令'
        openssl x509 -in "$CERT" -noout -checkend 0 >/dev/null || die '证书已过期'
    fi
    uuid=$(cat /proc/sys/kernel/random/uuid); password=$(python3 -c 'import secrets; print(secrets.token_hex(24))'); path="/$(python3 -c 'import secrets; print(secrets.token_hex(12))')"
    customize_node
    collect_optional_exit
    install -d -m 700 /var/lib/alvinlv-v2fly
    [[ -n $stage ]] || mark_phase begin
    printf '%s\0' "$DOMAIN" "$path" "$uuid" "$password" "$PROTO" "$MODE" "$CERTMODE" "${CERT:-}" "${KEY:-}" "$BACKEND_PORT" "$WORK/exit.json" | python3 -c 'import json,sys; a=sys.stdin.buffer.read().decode().split("\0"); keys=("domain","path","uuid","password","protocol","mode","certmode","cert","key","backend_port"); d=dict(zip(keys,a)); d["exit"]=json.load(open(a[10])); json.dump(d,sys.stdout)' > "$RESUME.tmp"
    chmod 600 "$RESUME.tmp"; mv -f "$RESUME.tmp" "$RESUME"
    fi
    if [[ -z $stage ]] || ! systemctl is-active --quiet v2ray; then
        [[ -z $(ss -H -ltn "sport = :$BACKEND_PORT") ]] || die "本机后端端口 $BACKEND_PORT 已被占用"
    fi
    if [[ $MODE == 3 ]]; then
        info '请确认 DNS 指向本 VPS，Cloudflare 为 Flexible 并开启 WebSocket，放行 80/443。'
    elif [[ $MODE == 2 ]]; then
        info '请确认 DNS 指向本 VPS，Cloudflare 为 Full (strict) 并开启 WebSocket，放行 80/443。'
    else info '请确认域名解析指向 VPS，放行 80/443。'; fi
    run_install_steps
    if [[ ! -f /var/lib/alvinlv-v2fly/caddy-package.sha256 ]]; then
        [[ ! -f $STATE/state.json ]] || die '已有节点配置但缺少 Caddy 续装记录，请先检查配置'
        if [[ -f /etc/caddy/Caddyfile ]]; then sha256sum /etc/caddy/Caddyfile | cut -d ' ' -f1 > /var/lib/alvinlv-v2fly/caddy-package.sha256
        else printf 'absent\n' > /var/lib/alvinlv-v2fly/caddy-package.sha256; fi
    fi
    getent group alvinlv-v2fly >/dev/null || groupadd --system alvinlv-v2fly
    getent passwd alvinlv-v2fly >/dev/null || useradd --system --gid alvinlv-v2fly --no-create-home --shell /sbin/nologin alvinlv-v2fly
    [[ $(id -gn alvinlv-v2fly) == alvinlv-v2fly ]] || die '现有服务用户所属组不匹配，停止续装'
    install -d -m 700 "$STATE"
    install -d -m 755 /usr/local/libexec/alvinlv-v2fly
    [[ -x $CORE ]] || install -m 755 /usr/local/bin/v2ray "$CORE"
    write_helper "$HELPER"; chmod 600 "$HELPER"
    printf '%s\0' "$DOMAIN" "$path" "$uuid" "$password" "$PROTO" "$WORK/exit.json" "$BACKEND_PORT" | python3 -c 'import json,sys; a=sys.stdin.buffer.read().decode().split("\0"); p=json.load(open(a[5])); json.dump(dict(domain=a[0],path=a[1],uuid=a[2],password=a[3],protocol=a[4],port=int(a[6]),exit=p),sys.stdout)' | python3 "$HELPER" render "$WORK/server.json" "$WORK/client.json" "$WORK/state.json"
    "$CORE" test -c "$WORK/server.json"; "$CORE" test -c "$WORK/client.json"
    if [[ -f $STATE/state.json ]]; then
        python3 - "$STATE/state.json" "$WORK/state.json" <<'PY' || die '现有节点身份与续装记录不匹配，未覆盖配置'
import json,sys
a,b=(json.load(open(p,encoding='utf-8')) for p in sys.argv[1:])
assert all(a.get(k)==b.get(k) for k in ('domain','path','uuid','password','protocol','port'))
PY
        [[ -f $CONF && -f $STATE/client.json ]] || die '现有服务端或客户端配置缺失，请检查后重试'
        "$CORE" test -c "$CONF"
        info '现有服务端和客户端配置已保留'
    else
        if [[ -f $CONF ]]; then
            python3 - "$CONF" "$WORK/server.json" <<'PY' || die '现有服务端配置与本次安装不一致，未覆盖'
import json,sys
a,b=(json.load(open(p,encoding='utf-8')) for p in sys.argv[1:])
assert a=={} or a==b
PY
        fi
        install -o root -g alvinlv-v2fly -m 640 "$WORK/server.json" "$CONF"
        install -m 600 "$WORK/client.json" "$STATE/client.json"; install -m 600 "$WORK/state.json" "$STATE/state.json"
    fi
    mkdir -p /etc/systemd/system/v2ray.service.d
    cat > "$WORK/v2ray.service.conf" <<EOF
[Service]
User=alvinlv-v2fly
Group=alvinlv-v2fly
Environment=V2RAY_LOCATION_ASSET=/usr/local/share/v2ray
ExecStart=
ExecStart=$CORE run -config $CONF
EOF
    if [[ -f /etc/systemd/system/v2ray.service.d/20-alvinlv.conf ]]; then
        cmp -s "$WORK/v2ray.service.conf" /etc/systemd/system/v2ray.service.d/20-alvinlv.conf || die '已有服务配置被修改，未覆盖'
    else install -m 644 "$WORK/v2ray.service.conf" /etc/systemd/system/v2ray.service.d/20-alvinlv.conf; fi
    if [[ $CERTMODE == 2 ]]; then
        install -d -o root -g caddy -m 750 /etc/caddy/alvinlv-tls
        [[ $CERT -ef /etc/caddy/alvinlv-tls/cert.pem ]] || install -o root -g caddy -m 640 "$CERT" /etc/caddy/alvinlv-tls/cert.pem
        [[ $KEY -ef /etc/caddy/alvinlv-tls/key.pem ]] || install -o root -g caddy -m 640 "$KEY" /etc/caddy/alvinlv-tls/key.pem
    fi
    python3 "$HELPER" caddy "$WORK/state.json" "$MODE" "$CERTMODE" > "$WORK/Caddyfile"
    local preserve_caddy=0
    if [[ -f /etc/caddy/Caddyfile ]] && ! cmp -s "$WORK/Caddyfile" /etc/caddy/Caddyfile; then
        [[ -f /var/lib/alvinlv-v2fly/caddy-package.sha256 ]] || die '缺少 Caddy 配置指纹，未覆盖'
        if [[ $(sha256sum /etc/caddy/Caddyfile | cut -d ' ' -f1) != "$(cat /var/lib/alvinlv-v2fly/caddy-package.sha256)" ]]; then
            caddy adapt --config /etc/caddy/Caddyfile --adapter caddyfile > "$WORK/caddy-existing.json" 2>/dev/null || die '现有 Caddy 配置无法解析，未覆盖'
            caddy adapt --config "$WORK/Caddyfile" --adapter caddyfile > "$WORK/caddy-proposed.json" 2>/dev/null || die '拟应用的 Caddy 配置无法解析'
            python3 - "$WORK/caddy-existing.json" "$WORK/caddy-proposed.json" <<'PY' || die 'Caddy 配置已被修改，未覆盖'
import json,sys
assert json.load(open(sys.argv[1],encoding='utf-8')) == json.load(open(sys.argv[2],encoding='utf-8'))
PY
            preserve_caddy=1
        fi
    fi
    if [[ $preserve_caddy == 0 ]] && { [[ ! -f /etc/caddy/Caddyfile ]] || ! cmp -s "$WORK/Caddyfile" /etc/caddy/Caddyfile; }; then install -m 644 "$WORK/Caddyfile" /etc/caddy/Caddyfile; fi
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    [[ $0 -ef /usr/local/bin/v2ray ]] || install -m 755 "$0" /usr/local/bin/v2ray
    systemctl daemon-reload; systemctl enable v2ray caddy; systemctl restart v2ray caddy
    mark_phase complete
    rm -f "$RESUME" /var/lib/alvinlv-v2fly/caddy-package.sha256
    info '服务已启动。请确认安全组和系统防火墙允许 TCP 80/443；自动证书申请需正确 DNS。'
    info '服务状态：'; systemctl --no-pager --full status v2ray caddy || true
    info '导入链接（包含密钥，请勿公开）：'; python3 "$HELPER" share "$STATE/state.json"
    echo '以后输入 sudo v2ray 打开管理菜单；输入 v2ray version 查看真实内核版本。'
    if python3 - "$STATE/state.json" <<'PY'
import json,sys
sys.exit(0 if json.load(open(sys.argv[1],encoding='utf-8')).get('exit') else 1)
PY
    then
        info '检测住宅出口的实际连接'
        verify_exit || echo '住宅出口检测未通过；请检查节点入口及住宅代理，脚本不会自动切回 VPS 直连。'
    fi
}

apply_config() {
    local candidate=$1 backup
    "$CORE" test -c "$candidate" || { echo '配置校验失败，未替换'; return 1; }
    backup=$(mktemp); cp "$CONF" "$backup"
    install -o root -g alvinlv-v2fly -m 640 "$candidate" "$CONF"
    if ! systemctl restart v2ray || ! { sleep 2; systemctl is-active --quiet v2ray; }; then
        install -o root -g alvinlv-v2fly -m 640 "$backup" "$CONF"; systemctl restart v2ray || true
        rm -f "$backup"; echo '启动失败，已恢复原配置'; return 1
    fi
    rm -f "$backup"; echo '配置已校验并应用。'
}

verify_exit() (
    set -Eeuo pipefail
    local probe_dir probe_pid='' port ip direct
    [[ -x $CORE && -f $STATE/client.json ]] || { echo '缺少已安装的内核或客户端配置'; return 1; }
    probe_dir=$(mktemp -d)
    trap 'if [[ -n $probe_pid ]]; then kill "$probe_pid" 2>/dev/null || true; fi; rm -rf -- "$probe_dir"' EXIT
    port=$(python3 "$HELPER" probe "$STATE/client.json" "$probe_dir/client.json")
    "$CORE" test -c "$probe_dir/client.json" >/dev/null
    "$CORE" run -c "$probe_dir/client.json" > "$probe_dir/core.log" 2>&1 & probe_pid=$!
    sleep 2
    if ! ip=$(curl --noproxy '' --socks5-hostname "127.0.0.1:$port" -fsS --connect-timeout 10 --max-time 25 https://api.ipify.org 2>/dev/null); then
        echo '完整节点链路检测失败：请检查节点入口、住宅代理服务器和认证。本脚本生成的住宅出站不会自动回退到 VPS 直连。'
        return 1
    fi
    python3 - "$ip" <<'PY' || return 1
import ipaddress,sys
print('实际代理出口 IP：'+str(ipaddress.ip_address(sys.argv[1].strip())))
PY
    [[ ! -f $STATE/state.json ]] || python3 "$HELPER" verify-ip "$STATE/state.json" "$ip" || return 1
    direct=$(curl -4 --noproxy '*' -fsS --connect-timeout 5 --max-time 8 https://api.ipify.org 2>/dev/null || true)
    if [[ -n $direct && $ip == "$direct" ]]; then echo '提示：代理出口与 VPS 直连 IP 相同；若期望住宅 IP，请检查住宅代理配置。'; fi
)

diagnose() (
    set -Eeuo pipefail
    local work domain path origin edge
    [[ -x $CORE && -f $CONF && -f $STATE/state.json ]] || { echo '缺少 V2Ray 内核或节点配置'; return 1; }
    work=$(mktemp -d); trap 'rm -rf -- "$work"' EXIT
    printf '%s\n' '服务状态：'
    for service in v2ray caddy; do
        if systemctl is-active --quiet "$service"; then printf '  %s：运行中\n' "$service"; else printf '  %s：未运行\n' "$service"; fi
    done
    if "$CORE" test -c "$CONF" >/dev/null 2>&1; then echo 'V2Ray 配置：通过'; else echo 'V2Ray 配置：未通过，可运行 v2ray check 查看详情'; fi
    if caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then echo 'Caddy 配置：通过'; else echo 'Caddy 配置：未通过，可运行 v2ray check 查看详情'; fi
    python3 - "$STATE/state.json" "$CONF" "$work/values" <<'PY'
import json,re,sys
s=json.load(open(sys.argv[1],encoding='utf-8')); c=json.load(open(sys.argv[2],encoding='utf-8'))
domain=s['domain']; path=s['path']
if not re.fullmatch(r'[A-Za-z0-9.-]+',domain) or not re.fullmatch(r'/[A-Za-z0-9_/-]+',path): raise SystemExit('域名或路径格式无效')
match=any(i.get('streamSettings',{}).get('wsSettings',{}).get('path')==path for i in c.get('inbounds',[]))
print('安装记录和服务端 WebSocket 路径：'+('一致' if match else '不一致，请核对'))
with open(sys.argv[3],'w',encoding='utf-8') as f: f.write(domain+'\n'+path+'\n')
PY
    domain=$(sed -n '1p' "$work/values"); path=$(sed -n '2p' "$work/values")
    echo "节点域名：$domain"
    echo 'DNS 解析（当前服务器视角）：'
    timeout 8 getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u | head -n 8 || true
    printf 'url = "https://%s%s"\n' "$domain" "$path" > "$work/request.curl"
    origin=$(curl -4 --http1.1 --noproxy '*' --connect-timeout 5 --max-time 4 -sS -o /dev/null -w '%{http_code}' --resolve "$domain:443:127.0.0.1" -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: MDEyMzQ1Njc4OWFiY2RlZg==' --config "$work/request.curl" 2>/dev/null || true)
    edge=$(curl --http1.1 --noproxy '*' --connect-timeout 5 --max-time 4 -sS -o /dev/null -w '%{http_code}' -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: MDEyMzQ1Njc4OWFiY2RlZg==' --config "$work/request.curl" 2>/dev/null || true)
    [[ $origin =~ ^[0-9]{3}$ ]] || origin=000; [[ $edge =~ ^[0-9]{3}$ ]] || edge=000
    printf '源站 HTTPS WebSocket 状态：%s\n公网入口 HTTPS WebSocket 状态：%s\n' "$origin" "$edge"
    python3 "$HELPER" diagnostic-status "$origin" "$edge"
    echo '说明：101 只代表握手成功，不代表认证、住宅出口或目标网站一定可用；Cloudflare Origin CA 可能无法被本机 curl 信任。'
    if [[ -t 0 ]] && yesno '是否继续检测节点的实际出口 IP'; then verify_exit || true; fi
)

edit_config() {
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    cp "$CONF" "$WORK/edit.json"
    echo '修改入站 UUID、密码或路径后，原导入链接不会自动更新；路径还需同步修改 Caddy。'
    if command -v nano >/dev/null; then nano "$WORK/edit.json"; elif command -v vi >/dev/null; then vi "$WORK/edit.json"; else echo '请先安装 nano 或 vi'; return; fi
    apply_config "$WORK/edit.json" || true
}

protocol_menu() {
    local target selection backup
    [[ -x $CORE && -f $CONF && -f $STATE/state.json && -f $STATE/client.json ]] || { error '缺少已安装节点配置'; return 1; }
    menu_print '主节点协议：' '1) VMess + WebSocket + TLS（推荐）' '2) Trojan + WebSocket + TLS' '3) 管理独立 Shadowsocks 节点' '0) 返回'
    choice '选择 [0]: ' 0; selection=$REPLY
    case $selection in 1) target=vmess ;; 2) target=trojan ;; 3) ss_menu; return ;; 0) return ;; *) warn '选项无效'; return 1 ;; esac
    warn '切换将中断现有主节点，旧链接失效，需要重新导入；保留住宅出口和其他入站。'
    yesno '确认切换主节点协议' || return 0
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    python3 "$HELPER" switch-protocol "$CONF" "$STATE/state.json" "$target" "$WORK/server.json" "$WORK/state.json" "$WORK/client.json" || { error '节点配置生成失败，未修改'; return 1; }
    "$CORE" test -c "$WORK/server.json" || { error '服务端配置验证失败，未修改'; return 1; }
    "$CORE" test -c "$WORK/client.json" || { error '客户端配置验证失败，未修改'; return 1; }
    mkdir -p /var/backups || { error '无法创建备份目录，未修改'; return 1; }
    backup=$(mktemp -d /var/backups/alvinlv-protocol-XXXXXXXX) || return 1
    cp -p "$CONF" "$backup/server.json"; cp -p "$STATE/state.json" "$backup/state.json"; cp -p "$STATE/client.json" "$backup/client.json"
    if ! apply_config "$WORK/server.json"; then error "切换失败，备份保存在 $backup"; return 1; fi
    if ! install -m 600 "$WORK/state.json" "$STATE/state.json" || ! install -m 600 "$WORK/client.json" "$STATE/client.json"; then
        install -o root -g alvinlv-v2fly -m 640 "$backup/server.json" "$CONF"; cp -p "$backup/state.json" "$STATE/state.json"; cp -p "$backup/client.json" "$STATE/client.json"; systemctl restart v2ray || true
        error "写入客户端配置失败，已尝试回滚；备份：$backup"; return 1
    fi
    info "主节点已切换为 $target；原配置备份：$backup（包含密钥，请妥善保管）"
    echo '运行 v2ray url 查看新导入链接，v2ray exit-check 检测完整链路和出口。'
}

exit_menu() {
    local selection
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    menu_print '1) 配置/更换住宅出口' '2) 切回 VPS 直连' '0) 返回'
    choice '选择 [0]: ' 0
    selection=$REPLY
    case $selection in
        1) collect_exit || return ;;
        2) yesno '确认切回 VPS 直连出口' || return; printf 'null' > "$WORK/exit.json" ;;
        *) return ;;
    esac
    echo '本操作会重建出站和路由；手工配置的路由规则将被替换。'
    yesno '确认应用以上出口及路由' || return
    python3 "$HELPER" exit "$CONF" "$WORK/new.json" < "$WORK/exit.json"
    python3 - "$STATE/state.json" "$WORK/exit.json" "$WORK/state.json" <<'PY'
import json,sys
state=json.load(open(sys.argv[1],encoding='utf-8'))
state['exit']=json.load(open(sys.argv[2],encoding='utf-8'))
with open(sys.argv[3],'w',encoding='utf-8') as f: json.dump(state,f,ensure_ascii=False,indent=2)
PY
    if apply_config "$WORK/new.json"; then
        install -m 600 "$WORK/state.json" "$STATE/state.json"
        echo '正在通过实际节点链路检测出口。'
        [[ $selection != 1 ]] || echo '住宅出口检测失败时不会自动切回 VPS。'
        verify_exit || true
    fi
}

ss_menu() {
    [[ -x $CORE && -f $CONF ]] || die '尚未安装 V2Fly'
    local selection host port method password current
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    current=$(python3 "$HELPER" ss-port "$CONF")
    printf '\n'; menu_print '1) 启用或修改 Shadowsocks（TCP）' '2) 关闭 Shadowsocks' '0) 返回'
    choice '选择 [0]: ' 0; selection=$REPLY
    case $selection in
        0) return ;;
        2)
            [[ $current != 0 ]] || { echo '尚未启用 Shadowsocks'; return; }
            yesno '确认关闭 Shadowsocks 入站' || return
            printf 'null' | python3 "$HELPER" ss-set "$CONF" "$WORK/new.json"
            if apply_config "$WORK/new.json"; then rm -f "$STATE/ss.json"; fi
            return ;;
        1) ;;
        *) echo '选项无效'; return ;;
    esac
    echo 'Shadowsocks 使用 VPS 公网 IPv4 直连；Cloudflare 橙云不能转发此 TCP 端口。'
    read -r -p 'VPS 公网 IPv4: ' host || return
    read -r -p 'Shadowsocks TCP 端口 [23333]: ' port || return; port=${port:-23333}
    if [[ ! $port =~ ^[0-9]{1,5}$ ]] || ! (( 10#$port >= 1024 && 10#$port <= 65535 )); then echo '端口须为 1024～65535'; return; fi
    if [[ $port != "$current" ]] && [[ -n $(ss -H -ltn "sport = :$port") ]]; then echo '端口已被占用，未修改'; return; fi
    menu_print '1) aes-256-gcm（推荐）' '2) aes-128-gcm' '3) chacha20-poly1305'
    choice '加密方式 [1]: ' 1
    case $REPLY in 1) method=aes-256-gcm ;; 2) method=aes-128-gcm ;; 3) method=chacha20-poly1305 ;; *) echo '选项无效'; return ;; esac
    read -rs -p '密码（至少 16 字符；直接回车自动生成）: ' password || return; echo
    [[ -n $password ]] || password=$(python3 -c 'import secrets; print(secrets.token_hex(24))')
    printf '%s\0' "$host" "$port" "$method" "$password" | python3 -c 'import json,sys; a=sys.stdin.buffer.read().decode().split("\0"); json.dump(dict(host=a[0],port=int(a[1]),method=a[2],password=a[3]),sys.stdout)' > "$WORK/ss-profile.json"
    unset password
    python3 "$HELPER" ss-set "$CONF" "$WORK/new.json" < "$WORK/ss-profile.json" || { echo 'Shadowsocks 选项无效，未修改'; return; }
    python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); json.dump({"host":p["host"]},sys.stdout)' "$WORK/ss-profile.json" > "$WORK/ss-host.json"
    if apply_config "$WORK/new.json"; then
        install -m 600 "$WORK/ss-host.json" "$STATE/ss.json"
        echo '已启用；请在云安全组和系统防火墙放行所选 TCP 端口。'
        echo '链接包含密钥，请勿公开：'; python3 "$HELPER" ss-share "$CONF" "$STATE/ss.json"
    fi
}

show_qr() {
    local kind=$1
    if [[ $kind == ss ]]; then [[ -f $STATE/ss.json && -f $CONF ]] || die '尚未配置 Shadowsocks'
    else [[ -f $STATE/state.json ]] || die '尚未安装'; fi
    if ! command -v qrencode >/dev/null; then
        echo '生成终端二维码需要 qrencode。'
        yesno '现在安装 qrencode' || { echo '未安装二维码工具，可使用 v2ray link 或 v2ray ssinfo 查看链接。'; return 0; }
        check_platform
        if [[ $FAMILY == apt ]]; then DEBIAN_FRONTEND=noninteractive apt-get install -y qrencode
        else dnf install -y qrencode; fi
    fi
    echo '二维码包含节点密钥，请勿公开：'
    if [[ $kind == ss ]]; then
        python3 "$HELPER" ss-share "$CONF" "$STATE/ss.json" | qrencode -t ANSIUTF8 -o -
    else
        python3 "$HELPER" share "$STATE/state.json" | qrencode -t ANSIUTF8 -o -
        echo '如果手动修改了入站身份或路径，二维码中的安装记录可能已过期。'
    fi
}

update_manager() {
    local helper_temp wrapper_temp source_file=${1:-$0}
    [[ -f $STATE/state.json && -f $HELPER && -x $CORE ]] || { echo '未发现完整的 AlvinLv V2Fly 安装，请先完成安装。'; return 1; }
    [[ -f $source_file && -r $source_file ]] || { echo '请先将更新后的脚本保存为文件，再填写路径。'; return 1; }
    grep -Fq 'AlvinLv V2Fly interactive manager' "$source_file" || { echo '更新文件不是 AlvinLv V2Fly 脚本。'; return 1; }
    grep -Fq 'AlvinLv V2Fly interactive manager' /usr/local/bin/v2ray || { echo '现有 v2ray 入口不是本脚本的管理程序，未覆盖。'; return 1; }
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    if [[ $source_file -ef $0 ]]; then write_helper "$WORK/config.py"
    else
        python3 - "$source_file" "$WORK/config.py" <<'PY' || return 1
import base64,re,sys
text=open(sys.argv[1],encoding='utf-8').read()
m=re.search(r"cat <<'ALVINLV_CONFIG_BASE64' \| base64 -d > \"\$1\"\n(.*?)\nALVINLV_CONFIG_BASE64",text,re.S)
if not m: raise SystemExit('更新文件缺少配置辅助程序')
open(sys.argv[2],'wb').write(base64.b64decode(m.group(1),validate=False))
PY
    fi
    python3 -m py_compile "$WORK/config.py" || return 1
    bash -n "$source_file" || return 1
    cp -p "$HELPER" "$WORK/previous-config.py"
    helper_temp=$(mktemp "$STATE/.config-XXXXXXXX")
    wrapper_temp=$(mktemp /usr/local/bin/.alvinlv-v2ray-XXXXXXXX)
    if ! install -m 600 "$WORK/config.py" "$helper_temp" || ! install -m 755 "$source_file" "$wrapper_temp"; then
        rm -f "$helper_temp" "$wrapper_temp"; echo '更新文件准备失败，原管理程序未修改。'; return 1
    fi
    if ! mv -f "$helper_temp" "$HELPER"; then
        rm -f "$helper_temp" "$wrapper_temp"; echo '更新辅助程序失败。'; return 1
    fi
    if ! mv -f "$wrapper_temp" /usr/local/bin/v2ray; then
        cp -p "$WORK/previous-config.py" "$HELPER"; rm -f "$wrapper_temp"; echo '更新管理入口失败，已恢复辅助程序。'; return 1
    fi
    info '管理菜单与辅助程序已更新；内核、节点配置和服务未更改。'
}

update_manager_from_file() {
    local source_file
    read -r -p '填写已下载的新版 AlvinLv 脚本路径: ' source_file || return
    [[ -n $source_file ]] || { echo '已取消'; return; }
    update_manager "$source_file"
}

verify_release_archive() {
    local archive=$1 digest_file=$2 expected actual
    expected=$(awk -F '= ' '/256=/ {print $2}' "$digest_file")
    [[ $expected =~ ^[0-9a-fA-F]{64}$ ]] || die '官方 SHA256 校验文件格式无效'
    actual=$(sha256sum "$archive" | awk '{print $1}')
    [[ ${expected,,} == "${actual,,}" ]] || die '内核压缩包 SHA256 不匹配，未更新'
}

update_core() {
    [[ -x $CORE && -f $CONF ]] || die '尚未安装 V2Fly'
    local wanted current arch url backup newcore
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    read -r -p '目标版本（如 v5.53.0；回车获取 GitHub 最新正式版）: ' wanted || return
    if [[ -z $wanted ]]; then
        download 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest' "$WORK/release.json" || die '无法获取官方最新版本，请检查网络'
        wanted=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8"))["tag_name"])' "$WORK/release.json")
    fi
    [[ $wanted =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die '版本格式无效，使用如 v5.53.0 的正式版标签'
    current=$($CORE version | head -n 1)
    printf '当前：%s\n目标：%s\n' "$current" "$wanted"
    if [[ $current == "V2Ray ${wanted#v} "* ]]; then echo '目标版本已安装，无需更新'; return; fi
    yesno '下载并校验官方内核，更新后重启 V2Ray' || return
    case $(uname -m) in x86_64) arch=64 ;; aarch64) arch=arm64-v8a ;; *) die '不支持的 CPU 架构' ;; esac
    url="https://github.com/v2fly/v2ray-core/releases/download/$wanted/v2ray-linux-$arch.zip"
    download "$url" "$WORK/v2ray.zip" || die '内核下载失败，原服务未改动'
    download "$url.dgst" "$WORK/v2ray.zip.dgst" || die '校验文件下载失败，原服务未改动'
    verify_release_archive "$WORK/v2ray.zip" "$WORK/v2ray.zip.dgst"
    unzip -p "$WORK/v2ray.zip" v2ray > "$WORK/v2ray-core" || die '无法从官方压缩包提取内核'
    chmod 755 "$WORK/v2ray-core"
    [[ $("$WORK/v2ray-core" version | head -n 1) == "V2Ray ${wanted#v} "* ]] || die '下载的内核版本不匹配'
    "$WORK/v2ray-core" test -c "$CONF" || die '新内核不接受现有配置，未更新'
    install -d -m 700 /var/backups/alvinlv-v2fly
    backup=$(mktemp /var/backups/alvinlv-v2fly/v2ray-core-XXXXXXXX)
    cp -p "$CORE" "$backup"
    newcore=$(mktemp /usr/local/libexec/alvinlv-v2fly/.v2ray-core-XXXXXXXX)
    install -m 755 "$WORK/v2ray-core" "$newcore"
    mv -f "$newcore" "$CORE"
    if ! systemctl restart v2ray || ! { sleep 2; systemctl is-active --quiet v2ray; }; then
        install -m 755 "$backup" "$CORE"; systemctl restart v2ray || true
        die "新内核启动失败，已尝试恢复原内核；备份：$backup"
    fi
    info "内核已更新至 $wanted；旧内核备份：$backup"
}

uninstall_menu() {
    local stage remove_caddy=0 answer plan=caddy
    WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
    write_cleanup "$WORK/cleanup.py"
    stage=$(python3 "$WORK/cleanup.py" phase)
    if [[ -z $stage ]]; then
        if [[ $(python3 "$WORK/cleanup.py" old-xray) == yes ]]; then
            old_xray_migration
            return 0
        fi
        printf '%s\n' '未发现可核实的 AlvinLv 安装标记，无法安全自动清理。' '检测到的冲突路径如下（仅显示路径，不显示密钥）：'
        python3 "$WORK/cleanup.py" conflicts
        printf '%s\n' '可能还存在软件包、命令或端口占用；旧版安装中途失败或其他脚本的残留，需要核对归属。'
        return 0
    fi
    printf '\n%s\n' "检测到本脚本安装阶段：$stage" '卸载会停止 V2Ray、删除列出的服务和配置、客户端密钥及住宅代理凭据。'
    if [[ $stage == caddy || $stage == complete || $stage == legacy ]]; then
        if command -v xray >/dev/null || [[ -e /usr/local/etc/xray || -e /etc/xray || -e /etc/systemd/system/xray.service ]] || systemctl is-active --quiet xray; then
            printf '%s\n' '发现 Xray；为避免影响现有服务，保留 Caddy 软件包及其配置。'
        elif yesno '同时卸载本脚本安装的 Caddy 软件包及其配置（可能影响复用 Caddy 的网站）'; then
            remove_caddy=1
        fi
    fi
    [[ $remove_caddy == 1 ]] || plan=no-caddy
    echo '将删除以下已存在文件（仅固定路径；其他文件保留）：'
    python3 "$WORK/cleanup.py" plan "$plan"
    if [[ $remove_caddy == 1 ]]; then
        echo '软件包管理器预计执行的 Caddy 删除操作：'
        if command -v dpkg-query >/dev/null && dpkg-query -W -f='${Status}' caddy 2>/dev/null | grep -q 'install ok installed'; then
            apt-get -s purge caddy || die '无法预览 Caddy 软件包操作，未卸载'
        elif command -v rpm >/dev/null && rpm -q caddy >/dev/null 2>&1; then
            dnf remove --assumeno caddy || true
        else echo '未检测到已安装的 Caddy 软件包。'; fi
    fi
    printf '%s\n' '不会删除系统依赖、软件源、Caddy 证书缓存、Xray 或非本脚本文件。请先自行备份需要保留的配置。'
    read -r -p '输入 UNINSTALL 确认卸载；其他内容取消: ' answer || return 0
    [[ $answer == UNINSTALL ]] || { echo '已取消'; return 0; }
    if [[ $stage != begin ]]; then systemctl disable --now v2ray 2>/dev/null || true; fi
    if [[ $remove_caddy == 1 ]]; then
        systemctl disable --now caddy 2>/dev/null || true
        if command -v dpkg-query >/dev/null && dpkg-query -W -f='${Status}' caddy 2>/dev/null | grep -q 'install ok installed'; then
            DEBIAN_FRONTEND=noninteractive apt-get purge -y caddy || die 'Caddy 软件包卸载失败，安装标记保留；可重新运行卸载'
        elif command -v rpm >/dev/null && rpm -q caddy >/dev/null 2>&1; then
            dnf remove -y caddy || die 'Caddy 软件包卸载失败，安装标记保留；可重新运行卸载'
        fi
    fi
    if [[ $stage == caddy || $stage == complete || $stage == legacy ]]; then
        if getent passwd alvinlv-v2fly >/dev/null; then userdel alvinlv-v2fly || die '专用用户删除失败，安装标记保留'; fi
        if getent group alvinlv-v2fly >/dev/null; then groupdel alvinlv-v2fly || die '专用组删除失败，安装标记保留'; fi
    fi
    python3 "$WORK/cleanup.py" remove "$plan"
    systemctl daemon-reload
    echo '卸载完成。未识别或非本脚本文件已保留。'
    if [[ $remove_caddy == 0 && $stage != begin && $stage != core ]]; then echo 'Caddy 已保留；若重新安装遇到冲突，请检查其是否仍被其他服务使用。'; fi
}

# SYSTEM_SETTINGS_BEGIN
BBR_FILE=/etc/sysctl.d/90-alvinlv-bbr.conf
BBR_STATE=/var/lib/alvinlv-v2fly-bbr

bbr_enable() {
    local old_cc old_qdisc available
    if [[ -e $BBR_FILE || -e $BBR_STATE ]]; then
        warn '检测到既有 BBR 配置或备份；请先检查或恢复，未覆盖。'; return 1
    fi
    old_cc=$(sysctl -n net.ipv4.tcp_congestion_control) || { error '无法读取当前拥塞算法'; return 1; }
    old_qdisc=$(sysctl -n net.core.default_qdisc) || { error '无法读取默认队列'; return 1; }
    printf '当前拥塞算法：%s；默认队列：%s\n' "$old_cc" "$old_qdisc"
    warn '将更改系统级 TCP 设置，可能影响其他服务；已有连接和网卡队列未必立即变化。'
    yesno '确认启用 BBR 和 fq' || return 0
    available=$(sysctl -n net.ipv4.tcp_available_congestion_control) || return 1
    if [[ " $available " != *' bbr '* ]]; then
        if ! modprobe tcp_bbr; then error '无法加载 BBR 模块；未更改 TCP 设置。'; return 1; fi
        available=$(sysctl -n net.ipv4.tcp_available_congestion_control) || return 1
        [[ " $available " == *' bbr '* ]] || { error '内核未注册 BBR；未更改 TCP 设置。'; return 1; }
    fi
    mkdir -p "$BBR_STATE" || return 1
    printf '%s\n%s\n' "$old_cc" "$old_qdisc" > "$BBR_STATE/original" || return 1
    printf '# AlvinLv BBR managed configuration\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\n' > "$BBR_STATE/managed" || return 1
    if ! sysctl -w net.core.default_qdisc=fq >/dev/null || ! sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null; then
        sysctl -w "net.ipv4.tcp_congestion_control=$old_cc" >/dev/null 2>&1 || true
        sysctl -w "net.core.default_qdisc=$old_qdisc" >/dev/null 2>&1 || true
        error '应用失败，已尝试恢复原值；备份保留，请检查当前状态。'; return 1
    fi
    if ! cp -n "$BBR_STATE/managed" "$BBR_FILE" || ! cmp -s "$BBR_STATE/managed" "$BBR_FILE"; then
        sysctl -w "net.ipv4.tcp_congestion_control=$old_cc" >/dev/null 2>&1 || true
        sysctl -w "net.core.default_qdisc=$old_qdisc" >/dev/null 2>&1 || true
        error '持久配置写入失败，已尝试恢复原值；备份保留。'; return 1
    fi
    info 'BBR 已应用并写入独立配置。其他 sysctl 文件可能影响重启后的最终值。'
}

bbr_restore() {
    local old_cc old_qdisc current_cc current_qdisc
    [[ -f $BBR_STATE/original && -f $BBR_STATE/managed && -f $BBR_FILE ]] || { warn '未找到完整的 AlvinLv BBR 备份和配置；请人工检查。'; return 1; }
    cmp -s "$BBR_STATE/managed" "$BBR_FILE" || { warn 'BBR 配置已被修改，保留文件和当前设置。'; return 1; }
    old_cc=$(sed -n '1p' "$BBR_STATE/original"); old_qdisc=$(sed -n '2p' "$BBR_STATE/original")
    [[ $old_cc =~ ^[a-zA-Z0-9_-]+$ && $old_qdisc =~ ^[a-zA-Z0-9_-]+$ ]] || { warn '备份内容无效，未恢复。'; return 1; }
    current_cc=$(sysctl -n net.ipv4.tcp_congestion_control) || return 1
    current_qdisc=$(sysctl -n net.core.default_qdisc) || return 1
    if [[ $current_cc != bbr || $current_qdisc != fq ]]; then
        warn '当前 TCP 设置已被其他程序更改；为避免覆盖，未恢复。'; return 1
    fi
    printf '将恢复运行时设置：%s / %s\n' "$old_cc" "$old_qdisc"
    yesno '确认恢复之前的 TCP 设置' || return 0
    if ! sysctl -w "net.ipv4.tcp_congestion_control=$old_cc" >/dev/null || ! sysctl -w "net.core.default_qdisc=$old_qdisc" >/dev/null; then
        error '恢复未完全成功，配置和备份已保留，请检查当前状态。'; return 1
    fi
    rm -f "$BBR_FILE" "$BBR_STATE/original" "$BBR_STATE/managed"
    rmdir "$BBR_STATE" || true
    info '已恢复记录的运行时值并移除本脚本配置；重启后的值取决于系统其他配置。'
}

system_status() {
    echo '内核：'; uname -r
    echo 'TCP 设置：'; sysctl net.ipv4.tcp_congestion_control net.ipv4.tcp_available_congestion_control net.core.default_qdisc 2>/dev/null || true
    echo 'BBR 模块：'; if command -v modinfo >/dev/null && modinfo tcp_bbr >/dev/null 2>&1; then echo '模块可用'; else echo '未检测到模块（也可能内建于内核）'; fi
    echo '当前网卡队列：'; if command -v tc >/dev/null; then tc qdisc show || true; else echo '未安装 tc'; fi
}
system_firewall() {
    echo 'firewalld：'; systemctl is-active firewalld || true
    if command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then firewall-cmd --get-active-zones || true; firewall-cmd --list-all || true; fi
    if command -v ufw >/dev/null; then ufw status || true; fi
    echo '监听端口：'; if command -v ss >/dev/null; then ss -lntup || true; else echo '未安装 ss'; fi
    echo '云安全组及其他防火墙规则需要另行检查。'
}
system_menu() {
    while :; do
        printf '\n'; menu_print '========== 系统设置 ==========' '1) 查看 BBR、内核和网卡队列' '2) 启用 BBR' '3) 恢复启用前的 TCP 设置' '4) 查看防火墙和监听端口' '5) 查看 SELinux 状态' '6) 查看系统 DNS' '0) 返回'
        choice '请选择 [0]: ' 0
        case $REPLY in
            1) system_status ;; 2) bbr_enable || true ;; 3) bbr_restore || true ;; 4) system_firewall ;;
            5) if command -v getenforce >/dev/null; then getenforce || true; else echo '未安装 SELinux 工具'; fi ;;
            6) cat /etc/resolv.conf || true ;; 0) return ;; *) warn '选项无效' ;;
        esac
    done
}
# SYSTEM_SETTINGS_END

menu() {
    while :; do
        printf '\n'; menu_print '========== AlvinLv · V2Fly 管理 ==========' '1) 安装 V2Ray' '2) 查看服务状态' '3) 启动/停止/重启服务' '4) 查看服务日志' '5) 查看服务端配置（含敏感信息）' '6) 编辑服务端配置' '7) 配置住宅出口 / 切回 VPS 出口' '8) 查看客户端配置和导入链接' '9) 检查配置' '10) 卸载 / 清理本脚本残留' '11) 更新管理菜单与辅助程序' '12) 配置 Shadowsocks' '13) 显示节点二维码' '14) 更新 V2Fly 内核' '15) 查看命令帮助' '16) 检测节点实际出口 IP' '17) 一键诊断' '18) 系统设置 / BBR' '19) 切换主节点协议' '0) 退出'
        choice '请选择 [0]: ' 0
        case $REPLY in
            1) install_wizard ;;
            2) systemctl --no-pager --full status v2ray caddy || true ;;
            3) menu_print '1) 启动' '2) 停止' '3) 重启'; choice '选择 [0]: ' 0; case $REPLY in 1) systemctl start v2ray caddy ;; 2) systemctl stop v2ray caddy ;; 3) systemctl restart v2ray caddy ;; esac ;;
            4) journalctl -u v2ray -u caddy -n 100 --no-pager || true ;;
            5) [[ -f $CONF ]] && cat "$CONF" || echo '尚未安装' ;;
            6) [[ -x $CORE ]] && edit_config || echo '尚未安装' ;;
            7) [[ -x $CORE ]] && exit_menu || echo '尚未安装' ;;
            8) if [[ -f $STATE/state.json ]]; then echo '以下信息包含密钥，请勿公开：'; python3 "$HELPER" share "$STATE/state.json"; echo '客户端配置：'; cat "$STATE/client.json"; echo '注意：手动修改入站身份或路径后，此处为安装时的原始配置。'; else echo '尚未安装'; fi ;;
            9) if [[ -x $CORE ]]; then "$CORE" test -c "$CONF" || true; caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile || true; else echo '尚未安装'; fi ;;
            10) uninstall_menu; return ;;
            11) update_manager || true ;;
            12) ss_menu ;;
            13) show_qr node ;;
            14) update_core ;;
            15) show_help ;;
            16) verify_exit || true ;;
            17) diagnose || true ;;
            18) system_menu ;;
            19) protocol_menu || true ;;
            0) return ;; *) warn '选项无效' ;;
        esac
    done
}
case $ACTION in
    menu) menu ;;
    status) systemctl --no-pager --full status v2ray caddy || true ;;
    start) systemctl start v2ray caddy ;;
    stop) systemctl stop v2ray caddy ;;
    restart) systemctl restart v2ray caddy ;;
    log) journalctl -u v2ray -u caddy -n 100 --no-pager ;;
    config) [[ -x $CORE ]] || die '尚未安装'; edit_config ;;
    link|url) [[ -f $STATE/state.json ]] || die '尚未安装'; echo '包含密钥，手动修改入站后链接不会自动更新：'; python3 "$HELPER" share "$STATE/state.json" ;;
    info|textlink) [[ -f $STATE/state.json && -f $CONF ]] || die '尚未安装或配置缺失'; echo '包含密钥，请勿公开；节点信息为安装记录，手动修改入站后需自行核对：'; python3 "$HELPER" info "$STATE/state.json" "$CONF" ;;
    qr) show_qr node ;;
    ss) ss_menu ;;
    ssinfo) [[ -f $STATE/ss.json && -f $CONF ]] || die '尚未配置 Shadowsocks'; echo '包含密钥，请勿公开：'; python3 "$HELPER" ss-info "$CONF" "$STATE/ss.json" ;;
    ssqr) show_qr ss ;;
    update) update_core ;;
    update.sh) update_manager_from_file ;;
    check) [[ -x $CORE ]] || die '尚未安装'; "$CORE" test -c "$CONF"; caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile ;;
    doctor) diagnose ;;
    system) system_menu ;;
    protocol) protocol_menu ;;
    exit-proxy) [[ -x $CORE ]] || die '尚未安装'; exit_menu ;;
    exit-check) verify_exit ;;
    uninstall) uninstall_menu ;;
    update-menu) update_manager ;;
esac
