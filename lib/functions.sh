# shellcheck shell=bash
# RHEL HA Advisor check functions

declare -gA SOSROOT

function is_sos_data_dir {
  [ -f "$1/installed-rpms" ] || [ -f "$1/etc/os-release" ]
}

function resolve_sos_folder {
  local folder="$1"
  local candidate resolved

  if is_sos_data_dir "./$folder"; then
    resolved=$(cd "./$folder" && pwd)
    printf '%s' "$resolved"
    return 0
  fi

  for candidate in ./"$folder"/*; do
    [ -d "$candidate" ] || continue
    if is_sos_data_dir "$candidate"; then
      resolved=$(cd "$candidate" && pwd)
      printf '%s' "$resolved"
      return 0
    fi
  done

  return 1
}

function clear_sos_roots {
  SOSROOT=()
}

function register_sos_folder {
  local folder="$1"
  local root

  root=$(resolve_sos_folder "$folder") || return 1
  SOSROOT[$folder]="$root"
}

function sos_root {
  local id="$1"

  if [ -n "${SOSROOT[$id]:-}" ]; then
    printf '%s' "${SOSROOT[$id]}"
    return 0
  fi

  resolve_sos_folder "$id"
}

function pcs_property_all {
  local root file

  root=$(sos_root "$1")
  for file in "$root/sos_commands/pacemaker"/pcs_property_*_--all; do
    if [ -f "$file" ]; then
      cat "$file"
      return 0
    fi
  done

  return 1
}

CHECK_COL_WIDTH=70
CHECK_TABLE_WIDTH=83

function _check_hrule {
  local left="$1"
  local right="$2"

  printf "%s" "$left"
  printf '%*s' "$CHECK_COL_WIDTH" '' | tr ' ' '-'
  printf "%s\n" "$right"
}

function check_table_begin {
  local title="$1"
  local prefix="+-- ${title} "
  local pad=$((CHECK_TABLE_WIDTH - ${#prefix}))

  if [ "$pad" -lt 1 ]; then
    pad=1
  fi

  printf "%s" "$prefix"
  printf '%*s' "$pad" '' | tr ' ' '-'
  printf "+\n"
  printf "| %-6s | %-${CHECK_COL_WIDTH}s |\n" "Status" "Check"
  _check_hrule "+--------+" "+"
}

function check_table_end {
  _check_hrule "+--------+" "+"
}

function _check_row {
  local status="$1"
  local color="$2"
  local line="$3"

  if [ -n "$status" ]; then
    printf '| %b%-6s%b | %-*s |\n' "$color" "$status" "$NC" "$CHECK_COL_WIDTH" "$line"
  else
    printf "| %-6s | %-${CHECK_COL_WIDTH}s |\n" "" "$line"
  fi
}

function _check_emit {
  local status="$1"
  local color="$2"
  local message="$3"
  local first=1
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$first" -eq 1 ]; then
      _check_row "$status" "$color" "$line"
      first=0
    else
      _check_row "" "" "$line"
    fi
  done < <(printf '%s' "$message" | fold -s -w "$CHECK_COL_WIDTH")
}

function check_pass {
  _check_emit "PASS" "$GRN" "$1"
}

function check_fail {
  _check_emit "FAIL" "$RED" "$1"
}

function check_warn {
  _check_emit "WARN" "$YLW" "$1"
}

function check_info {
  _check_emit "INFO" "$BLE" "$1"
}

function check_detail {
  local message="$1"
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    _check_row "" "" "$line"
  done < <(printf '%s' "$message" | fold -s -w "$CHECK_COL_WIDTH")
}

function check_ref {
  check_detail "-> $1"
  check_detail "  $2"
}

function getOSdistro {
  grep ^NAME "$(sos_root "$1")/etc/os-release"
}

function getOSrelease {
  grep ^VERSION_ID "$(sos_root "$1")/etc/os-release" | cut -d'=' -f2 | tr -d '"'
}

function getConsSubscriptions {
  if [ -f "$(sos_root "$1")/sos_commands/subscription_manager/subscription-manager_list_--consumed" ]; then
    devsubsc=$(grep -c 'Developer Subscription for Individuals' "$(sos_root "$1")/sos_commands/subscription_manager/subscription-manager_list_--consumed" || true)
    if [ "$devsubsc" -gt 0 ]; then
      check_fail "At least one node is registered with Developer Subscriptions"
    else
      check_pass "The nodes are not registered with Developer Subscriptions"
    fi
  else
    check_info "There is no information of the subscriptions consumed"
  fi
}

function isRHUI {
  local repolist
  repolist="$(sos_root "$1")/sos_commands/dnf/dnf_-C_repolist"
  if [ -f "$repolist" ]; then
    rhui=$(grep -c 'rhui' "$repolist" || true)
    if [ "${rhui:-0}" -gt 0 ]; then
      check_warn "The systems have RHUI repos, this can be a cloud PAYG instance or have wrongly enabled these repositories"
    else
      check_pass "The systems don't have RHUI repositories"
    fi
  else
    check_warn "The sos report did not include repositories information"
  fi
}

function lv_meta {
  cat "$(sos_root "$1")/etc/lvm/lvm.conf" | grep -v '#'| sed '/^$/d' | grep use_lvmetad | head -1 | cut -d= -f2 | awk '{print $1}'
}

function isClusterInstalled {
  grep -ciE 'pacemaker|corosync' "$(sos_root "$1")/installed-rpms" || true
}

function isVRTSCluster {
  grep -ci '/opt/VRTSvcs/' "$(sos_root "$1")/ps" || true
}

function isHPECluster {
  grep -ci 'cmcluster' "$(sos_root "$1")/ps" || true
}

function isLinbitClusterInstalled {
  grep -ciE 'pacemaker|corosync' "$(sos_root "$1")/installed-rpms" | grep -c linbit || true
}

function isIBMClusterInstalled {
  grep -ciE 'pacemaker|corosync' "$(sos_root "$1")/installed-rpms" | grep -c db2pcmk || true
}

function isIBMGPFS {
  grep -ci '^gpfs' "$(sos_root "$1")/installed-rpms" || true
}

function isORAC {
  grep -i 'GTX0\|LMON\|LMD\|LMS\|RMS' "$(sos_root "$1")/ps" | grep -c ^'oracle\|grid'
}

function is3PClusterInstalled {
  grep -ciE 'pacemaker|corosync' "$(sos_root "$1")/sos_commands/rpm/package-data" | grep -ciE 'Oracle|Rocky|asianux' || true
}

function getNodeNumber {
  local fcib
  fcib=$(find "$(sos_root "$1")" -name cib.xml | head -1)
  if [ -n "$fcib" ]; then
    grep -c 'node id' "$fcib" || true
  else
    if [ -e "$(sos_root "$1")/sos_commands/pacemaker/crm_report/members.txt" ]; then
      cat "$(sos_root "$1")/sos_commands/pacemaker/crm_report/members.txt" | tr ' ' '\n' | sed '/^$/d' | wc -l
    else
      grep 'ring0' "$(sos_root "$1")/etc/corosync/corosync.conf" | grep -cv '#' || true
    fi
  fi
}

function getHardware {
  local ibmz fhw dmidecode_file
  dmidecode_file="$(sos_root "$1")/dmidecode"
  ibmz=$(grep -c s390x "$(sos_root "$1")/uname" || true)

  if [ "$ibmz" -gt 0 ]
  then
    echo "IBMZ"
  elif [ -f "$dmidecode_file" ]; then
    fhw=$(grep 'Manufacturer:' "$dmidecode_file" | grep -v 'UNKNOWN\|Not Specified\|Intel\|Samsung\|QEMU' | head -1 | cut -d":" -f2 | sed 's/ //')
    echo "$fhw"
  fi
}

function hwisazure {
  grep -c fence_azure_arm "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true
}

function hwisazurebyos {
  jq '.licenseType' "$(sos_root "$1")/sos_commands/azure/instance_metadata.json" | grep -ci 'RHEL_BYOS'
}

function hwisOpenStack {
  grep -c OpenStack "$(sos_root "$1")/dmidecode" || true
}

function hwisFusionCompute {
  grep -c 'FusionCompute(KVM)' "$(sos_root "$1")/dmidecode" || true
}

function hwisOLVM {
  grep -i vendor "$(sos_root "$1")/dmidecode" | grep -ci oracle || true
}

function ha_stonith {
  stonena=$(pcs_property_all "$1" | grep stonith-enabled | head -1 | sed 's/=/:/' | cut -d: -f2 | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

  if [ "$stonena" != "true" ]; then
      check_fail "stonith-enabled must be enabled but is not"
      check_ref "How to set stonith-enabled to true in a Pacemaker cluster" "https://access.redhat.com/solutions/2476841"
  else
      check_pass "stonith-enabled is enabled"
  fi
}

function ha_quorum {
  noquorum=$(pcs_property_all "$1" | grep no-quorum-policy | head -1 | sed 's/=/:/' | cut -d: -f2 | awk '{print $1}')

  if [ "$noquorum" == "ignore" ]; then
      check_fail "no-quorum-policy is set to ignore"
      check_ref "Can I configure pacemaker to continue to manage resources after a loss of quorum in RHEL 6, 7, or 8?" "https://access.redhat.com/solutions/645843"
  else
      check_pass "no-quorum-policy is in a supported state"
  fi
}

function conf_coros {
  cat "$(sos_root "$1")/etc/corosync/corosync.conf"
}

function rpm_version {
  cat "$(sos_root "$1")/installed-rpms" | grep -e ^'pacemaker\|pcs-\|corosync\|gfs2-\|resource-agents\|dlm\|lvm2-lockd' | grep -v 'corosync-qnetd' | sort | uniq | awk '{print $1}'
}

function get_cluster_name {
  local name props cib

  props=$(pcs_property_all "$1" 2>/dev/null)
  name=$(printf '%s\n' "$props" | grep -i 'cluster-name' | head -1 | sed -E 's/^[^:=]*[:=][[:space:]]*//' | tr -d '[:space:]')
  if [ -n "$name" ]; then
    printf '%s' "$name"
    return
  fi

  cib=$(find "$(sos_root "$1")" -name cib.xml 2>/dev/null | head -1)
  if [ -n "$cib" ]; then
    name=$(grep 'cluster-name' "$cib" 2>/dev/null | head -1 | sed -n 's/.*value="\([^"]*\)".*/\1/p')
    if [ -n "$name" ]; then
      printf '%s' "$name"
      return
    fi
  fi

  name=$(grep -E '^\s*name:\s*' "$(sos_root "$1")/etc/corosync/corosync.conf" 2>/dev/null | grep -v '#' | head -1 | awk '{print $2}')
  if [ -n "$name" ]; then
    printf '%s' "$name"
    return
  fi

  printf 'unknown'
}

function get_sos_hostname {
  local root

  root=$(sos_root "$1")
  if [ -f "$root/hostname" ]; then
    tr -d '[:space:]' < "$root/hostname"
    return
  fi
  if [ -f "$root/uname" ]; then
    awk '{print $2}' "$root/uname"
    return
  fi
  basename "$root"
}

function get_pacemaker_version {
  cat "$(sos_root "$1")/installed-rpms" 2>/dev/null | grep -E '^pacemaker-[0-9]' | head -1 | awk '{print $1}' | sed -E 's/\.(x86_64|aarch64|ppc64le|s390x)$//' | sed 's/^pacemaker-//'
}

function get_corosync_version {
  cat "$(sos_root "$1")/installed-rpms" 2>/dev/null | grep -E '^corosync-[0-9]' | grep -v 'corosync-qnet' | head -1 | awk '{print $1}' | sed -E 's/\.(x86_64|aarch64|ppc64le|s390x)$//' | sed 's/^corosync-//'
}

function print_cluster_summary {
  local sosreports_name="$1"
  local noden="$2"
  local -n _sosreports=$sosreports_name
  local count cluster_name
  local -a hostnames pacemaker_versions corosync_versions
  local pcmk_mismatch=0 coros_mismatch=0
  local pcmk_status coros_status

  cluster_name=$(get_cluster_name "${_sosreports[1]}")

  for ((count=1; count<=noden; count++)); do
    hostnames[count]=$(get_sos_hostname "${_sosreports[count]}")
    pacemaker_versions[count]=$(get_pacemaker_version "${_sosreports[count]}")
    corosync_versions[count]=$(get_corosync_version "${_sosreports[count]}")
    [ -z "${pacemaker_versions[count]}" ] && pacemaker_versions[count]="n/a"
    [ -z "${corosync_versions[count]}" ] && corosync_versions[count]="n/a"
  done

  for ((count=2; count<=noden; count++)); do
    [ "${pacemaker_versions[count]}" != "${pacemaker_versions[1]}" ] && pcmk_mismatch=1
    [ "${corosync_versions[count]}" != "${corosync_versions[1]}" ] && coros_mismatch=1
  done

  if [ "$pcmk_mismatch" -eq 0 ]; then
    pcmk_status="${pacemaker_versions[1]} (in sync)"
  else
    pcmk_status="mismatch detected"
  fi

  if [ "$coros_mismatch" -eq 0 ]; then
    coros_status="${corosync_versions[1]} (in sync)"
  else
    coros_status="mismatch detected"
  fi

  printf "+------------------+------------------------------------------+\n"
  printf "| %-16s | %-40s |\n" "Cluster name" "$cluster_name"
  printf "| %-16s | %-40s |\n" "Nodes" "$noden"
  printf "| %-16s | %-40s |\n" "Pacemaker" "$pcmk_status"
  printf "| %-16s | %-40s |\n" "Corosync" "$coros_status"
  printf "+------------------+------------------------------------------+\n"

  if [ "$pcmk_mismatch" -eq 1 ] || [ "$coros_mismatch" -eq 1 ]; then
    printf "\n"
    printf "+----------+----------------------+----------------------+\n"
    printf "| %-8s | %-20s | %-20s |\n" "Node" "Pacemaker" "Corosync"
    printf "+----------+----------------------+----------------------+\n"
    for ((count=1; count<=noden; count++)); do
      printf "| %-8s | %-20s | %-20s |\n" "${hostnames[count]}" "${pacemaker_versions[count]}" "${corosync_versions[count]}"
    done
    printf "+----------+----------------------+----------------------+\n"
  fi

  printf "\n"
}

function rpm_qdevice {
  grep -cE '^corosync-qnet' "$(sos_root "$1")/installed-rpms" || true
}

function run_kernel {
  cat "$(sos_root "$1")/uname" | head -1 | awk '{print $3}'
}

function use_gfs2_fs {
  grep -ci 'gfs2' "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true
}

function gfs2_withdraw {
  local root withdraw_file
  root=$(sos_root "$1")
  shopt -s nullglob
  for withdraw_file in "$root"/sys/fs/gfs2/*/withdraw; do
    if [ -f "$withdraw_file" ]; then
      cat "$withdraw_file"
      return
    fi
  done
  printf '0'
}

function RemoteNodes {
  grep -ci 'ocf:pacemaker:remote' "$(sos_root "$1")/sos_commands/pacemaker/pcs_status_--full" || true
}

function GuestNodes {
  grep -ci 'ocf:heartbeat:VirtualDomain' "$(sos_root "$1")/sos_commands/pacemaker/pcs_status_--full" || true
}

function ThirdPartyApps {
  tpa=$(grep -ciE 'commvault|nessus|veeam|Tanium|TrendMicro|CrowdStrike|falcon-sensor-bpf|guard_stap' "$(sos_root "$1")/ps" || true)
  if [ "$tpa" -gt 0 ]
  then
    check_fail "Third party apps known to prevent clusters from properly working have been detected"
  else
    check_pass "No third party apps known to prevent clusters from properly working have been detected"
  fi
}

function resourcemon {
  if [ -e "$(sos_root "$1")/var/spool/cron/root" ]; then
    rmon=$(grep -c 'ha-resourcemon.sh' "$(sos_root "$1")/var/spool/cron/root" || true)
    if [ "$rmon" -eq 0 ]
    then
      check_info "ha-resourcemon.sh is not configured on the cluster"
    else
      check_pass "ha-resourcemon.sh is configured at least in one node"
    fi
  else
    check_info "ha-resourcemon.sh is not configured on the cluster"
  fi
}

function trace_ra_enabled {
  trceena=$(grep -c trace_ra "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true)
  if [ "$trceena" -eq 0 ]
  then
    check_info "trace_ra is not enabled for any resource"
  else
    check_info "trace_ra is enabled for $trceena resource(s)"
  fi
}

function pcmk_dbg {
  dbgena=$(cat "$(sos_root "$1")/etc/sysconfig/pacemaker" | grep PCMK_debug | grep -v ^'#' | head -1 | cut -d= -f2 | awk '{print $1}')
  if [ -z "$dbgena" ]
  then
    check_info "Debug is not enabled in Pacemaker"
  else
    if [ "$dbgena" == "no" ]; then
      check_info "Debug is not enabled in Pacemaker"
    else
      check_info "Debug is enabled in Pacemaker"
    fi
  fi
}

function tpreview7 {
  bz1413573=$(grep -c 'Heuristics:' "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true)
    if [ "$bz1413573" -gt 0 ]
    then
      check_fail "Technology preview is being used: Heuristics in corosync-qdevice available as a Technology Preview (BZ#1413573)"
      check_ref "Technology Preview Features Support Scope" "https://access.redhat.com/support/offerings/techpreview"
    fi

  bz1476401=$(grep -c 'fence_heuristics_ping' "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true)
    if [ "$bz1476401" -gt 0 ]
    then
      check_fail "Technology preview is being used: Pacemaker podman bundles available as a Technology Preview (BZ#1619620)"
      check_ref "Technology Preview Features Support Scope" "https://access.redhat.com/support/offerings/techpreview"
    fi

  bz1513957=$(grep -cE 'lvmlockd|LVM-activate' "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true)
    if [ "$bz1513957" -gt 0 ]
    then
      check_fail "Technology preview is being used: New LVM and LVM lock manager resource agents (BZ#1513957)"
      check_ref "Technology Preview Features Support Scope" "https://access.redhat.com/support/offerings/techpreview"
    fi

    if [ "$bz1413573" -eq 0 ]
    then
      if [ "$bz1476401" -eq 0 ]
      then
        if [ "$bz1513957" -eq 0 ]
        then
          check_pass "Technology preview is not being used"
        fi
      fi
    fi
}

function tpreview8 {
  bz1619620=$(grep -c 'class=ocf provider=heartbeat type=podman' "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true)
    if [ "$bz1619620" -gt 0 ]
    then
      check_fail "Technology preview is being used: Pacemaker podman bundles available as a Technology Preview (BZ#1619620)"
      check_ref "Technology Preview Features Support Scope" "https://access.redhat.com/support/offerings/techpreview"
    fi

  bz1775847=$(grep -c 'fence_heuristics_ping' "$(sos_root "$1")/sos_commands/pacemaker/pcs_config" || true)
    if [ "$bz1775847" -gt 0 ]
    then
      check_fail "Technology preview is being used: New fence-agents-heuristics-ping fence agent (BZ#1775847)"
      check_ref "Technology Preview Features Support Scope" "https://access.redhat.com/support/offerings/techpreview"
    fi

    if [ "$bz1619620" -eq 0 ]
    then
      if [ "$bz1775847" -eq 0 ]
      then
        check_pass "Technology preview is not being used"
      fi
    fi
}

function tpreview9 {
  :
}

function tpreview10 {
  :
}

function check_hardware_platform {
  local sosreport_name="$1"
  local hw
  hw=$(getHardware "$sosreport_name")

  case "$hw" in
    Dell*|HP*|BULL*|Cisco*|IBM*|Lenovo*|LENOVO*|Hitachi*|FUJITSU*|*H3C*)
      check_pass "This is a Hardware based cluster"
      ;;
    Red*Hat)
      ostack=$(hwisOpenStack "$sosreport_name")
      if [ "$ostack" -eq 0 ]; then
        check_pass "This is a Red Hat's KVM based cluster"
      else
        ostrhel=$(getOSrelease "$sosreport_name")
        if [ "$(printf "%s\n" "8.7" "$ostrhel" | sort -V | tail -1)" = "$ostrhel" ]; then
          check_pass "This cluster is deployed in OpenStack VMs running RHEL 8.7+"
        else
          check_fail "This cluster is deployed in OpenStack VMs not running the OS requirements. It is unsupported"
          check_ref "Support Policies for RHEL High Availability Clusters - OpenStack Virtual Machines as Cluster Members" "https://access.redhat.com/articles/3131311"
        fi
      fi
      ;;
    VMware*)
      check_pass "This is a VMware based cluster"
      ;;
    Google*)
      check_pass "This is a Google Cloud Platform based cluster"
      ;;
    Amazon*)
      check_pass "This is an AWS based cluster"
      ;;
    Microsoft*)
      aze=$(hwisazure "$sosreport_name")
      if [ "$aze" -eq 0 ]
      then
        check_warn "This looks like a Microsoft HyperV virtual system, unsupported"
        check_ref "Support Policies for RHEL High Availability Clusters - Microsoft Hyper-V Virtual Machines as Cluster Members" "https://access.redhat.com/articles/3131321"
      else
        check_pass "This is a Microsoft Azure virtual system"
      fi
      azebyos=$(hwisazurebyos "$sosreport_name")
      if [ "$azebyos" -eq 1 ]
      then
        check_pass "This is a BYOS based instance"
      else
        check_fail "This is a PAYG based instance, support is provided by the cloud vendor"
        check_ref "What is a Red Hat pay-as-you-go (PAYG) image?" "https://access.redhat.com/articles/3664231#bwhat-is-a-red-hat-pay-as-you-go-payg-imageb-17"
      fi
      ;;
    Nutanix)
      check_fail "This is a Nutanix virtual system, unsupported"
      check_ref "Support Policies for RHEL High Availability Clusters - Nutanix AHV Virtual Machines as Cluster Members" "https://access.redhat.com/articles/6113961"
      ;;
    Huawei*)
      fusioncpte=$(hwisFusionCompute "$sosreport_name")
      if [ "$fusioncpte" -eq 1 ]
      then
        check_fail "This cluster is deployed in Huawei FusionCompute(KVM), unsupported"
        check_ref "Support Policies for RHEL High Availability Clusters - RHEL libvirt/KVM Virtual Machines as Cluster Members" "https://access.redhat.com/articles/3131301"
      else
        check_warn "This is a Huawei unknown platform"
      fi
      ;;
    RDO)
      ostack=$(hwisOpenStack "$sosreport_name")
      if [ "$ostack" -eq 1 ]
      then
        check_fail "This cluster is deployed in an upstream version of OpenStack (RDO), unsupported"
        check_ref "Support Policies for RHEL High Availability Clusters - OpenStack Virtual Machines as Cluster Members" "https://access.redhat.com/articles/3131311"
      else
        check_warn "This is an RDO unknown platform"
      fi
      ;;
    oVirt)
      olvm=$(hwisOLVM "$sosreport_name")
      if [ "$olvm" -eq 1 ]
      then
        check_fail "This cluster is deployed in Oracle's OLVM, unsupported"
        check_ref "Support Policies for RHEL High Availability Clusters - RHEL libvirt/KVM Virtual Machines as Cluster Members" "https://access.redhat.com/articles/3131301"
      else
        check_fail "This is an oVirt unknown platform, unsupported"
        check_ref "Support Policies for RHEL High Availability Clusters - RHEL libvirt/KVM Virtual Machines as Cluster Members" "https://access.redhat.com/articles/3131301"
      fi
      ;;
    *)
      check_info "Hardware not found or not defined in the script"
      ;;
  esac
}

function run_cluster_checks {
  local sosreports_name="$1"
  local -n _sosreports=$sosreports_name
  local tmpfolder="$2"
  local noden="$3"
  local count
  local osdist osdist2 osvers osversmaj rpmvers kervers cinsync lvmtastate qdev
  local clremotend clguestnd fs_gfs2 wdraw

  print_cluster_summary "$sosreports_name" "$noden"

  check_table_begin "Installation & Health checks"

  getConsSubscriptions "${_sosreports[1]}"
  isRHUI "${_sosreports[1]}"
  check_hardware_platform "${_sosreports[1]}"

  count=1
  while [ "$count" -le "$noden" ]
  do
    getOSdistro "${_sosreports[count]}" > "$tmpfolder/os_distro.$count"
    getOSrelease "${_sosreports[count]}" > "$tmpfolder/os_release.$count"
    rpm_version "${_sosreports[count]}" > "$tmpfolder/rpm_version.$count"
    run_kernel "${_sosreports[count]}" > "$tmpfolder/run_kernel.$count"
    conf_coros "${_sosreports[count]}" > "$tmpfolder/corosync.conf.$count"
    lv_meta "${_sosreports[count]}" > "$tmpfolder/use_lvmetad.$count"
    rpm_qdevice "${_sosreports[count]}" > "$tmpfolder/qdevice.$count"
    ((count++))
  done

  osdist=$(diff --from-file="$tmpfolder/os_distro.1" "$tmpfolder"/os_distro.* | wc -l)
  osdist2=$(cat "$tmpfolder/os_distro.1" | grep -c 'Red Hat Enterprise Linux')
  osvers=$(diff --from-file="$tmpfolder/os_release.1" "$tmpfolder"/os_release.* | wc -l)
  osversmaj=$(cat "$tmpfolder/os_release.1" | cut -d. -f1)
  rpmvers=$(diff --from-file="$tmpfolder/rpm_version.1" "$tmpfolder"/rpm_version.* | wc -l)
  kervers=$(diff --from-file="$tmpfolder/run_kernel.1" "$tmpfolder"/run_kernel.* | wc -l)
  cinsync=$(diff --from-file="$tmpfolder/corosync.conf.1" "$tmpfolder"/corosync.conf.* | wc -l)
  lvmtastate=0
  for f in "$tmpfolder"/use_lvmetad.*; do
    [ -f "$f" ] && [ "$(cat "$f")" != "0" ] && ((lvmtastate++)) || true
  done
  qdev=0
  for f in "$tmpfolder"/qdevice.*; do
    [ -f "$f" ] && [ "$(cat "$f")" != "0" ] && ((qdev++)) || true
  done

  if [ "$osdist" -eq 0 ]
  then
    if [ "$osdist2" -gt 0 ]
    then
      check_pass "All the cluster nodes run Red Hat Enterprise Linux $osversmaj"
    else
      check_fail "None of the cluster nodes run Red Hat Enterprise Linux"
    fi
  else
    check_fail "Some of the cluster nodes dont run Red Hat Enterprise Linux"
  fi

  if [ "$osvers" -eq 0 ]
  then
    check_pass "All the cluster nodes run the same OS Major/minor version"
  else
    check_fail "Some of the cluster nodes dont run the same OS Major/minor version"
  fi

  if [ "$rpmvers" -eq 0 ]
  then
    check_pass "Cluster related packages are in the same version in all nodes"
  else
    check_fail "Some of the cluster related packages are not in the same version in all the nodes"
  fi

  if [ "$kervers" -eq 0 ]
  then
    check_pass "All the nodes runs the same kernel version"
  else
    check_fail "All the cluster nodes are not running the same kernel version"
  fi

  if [ "$cinsync" -eq 0 ]
  then
    check_pass "Corosync config is in sync between nodes"
  else
    check_fail "Corosync config is not in sync between nodes"
    check_ref "Editing the corosync.conf file in Red Hat Enterprise Linux 7" "https://access.redhat.com/articles/3185291"
  fi

  if [ "$lvmtastate" -eq 0 ]
  then
    check_pass "lvmetad is disabled in all the cluster nodes"
  else
    check_warn "lvmetad is not disabled in all the cluster nodes"
    check_ref "Support Policies for RHEL High Availability Clusters - LVM in a Cluster" "https://access.redhat.com/articles/3071171"
  fi

  if [ "$qdev" -eq 0 ]
  then
    check_pass "Package corosync-qnetd is not installed on the cluster nodes"
  else
    check_warn "Package corosync-qnetd is installed in at least one node, ensure the cluster doesn't use that device"
  fi

  ha_quorum "${_sosreports[1]}"
  ha_stonith "${_sosreports[1]}"

  case "$osversmaj" in
    7) tpreview7 "${_sosreports[1]}"
       ;;
    8) tpreview8 "${_sosreports[1]}"
       ;;
    9) tpreview9 "${_sosreports[1]}"
       ;;
    10) tpreview10 "${_sosreports[1]}"
       ;;
    *)
       ;;
  esac

  clremotend=$(RemoteNodes "${_sosreports[1]}")

  if [ "$clremotend" -gt 0 ]
  then
    check_info "The cluster has $clremotend remote node(s)"
  else
    check_info "The cluster has no remote nodes"
  fi

  clguestnd=$(GuestNodes "${_sosreports[1]}")

  if [ "$clguestnd" -gt 0 ]
  then
    check_info "The cluster has $clguestnd guest node(s)"
  else
    check_info "The cluster has no guest nodes"
  fi

  fs_gfs2=$(use_gfs2_fs "${_sosreports[1]}")

  if [ "$fs_gfs2" -eq 0 ]
  then
    check_info "No GFS2 resources, checking withdraw is not needed"
  else
    count=1
    while [ "$count" -le "$noden" ]
    do
      gfs2_withdraw "${_sosreports[count]}" > "$tmpfolder/gfs2_withdraw.$count"
      ((count++))
    done
    wdraw=0
    for f in "$tmpfolder"/gfs2_withdraw.*; do
      [ -f "$f" ] && [ "$(cat "$f")" = "1" ] && ((wdraw++)) || true
    done

    if [ "$wdraw" -eq 0 ]
    then
      check_pass "No withdraw has been found in the GFS2 filesystems"
    else
      check_fail "Withdraw have been found in at least one GFS2 filesystem"
      check_ref "How can I recover from a gfs2 withdrawal and fix any filesystem corruption that might exist in a Red Hat Enterprise Linux 5, 6, 7 or 8 Resilient Storage cluster?" "https://access.redhat.com/solutions/332223"
    fi
  fi

  check_table_end

  printf "\n"
  check_table_begin "Additional stats & debug checks"

  ThirdPartyApps "${_sosreports[1]}"
  resourcemon "${_sosreports[1]}"
  trace_ra_enabled "${_sosreports[1]}"
  pcmk_dbg "${_sosreports[1]}"

  check_table_end

  printf "\n"
}
