#!/bin/bash
#
# GitLab backup + config tarball
# Save as /usr/local/bin/gitlab_backup.sh and make executable: chmod +x /usr/local/bin/gitlab_backup.sh
#
#
set -euo pipefail

# ---- Settings (adjust as needed) ----
BACKUP_DIR="/backup/gitlab"
GITLAB_BACKUP_DIR="/var/opt/gitlab/backups"
LOG_FILE="/var/log/gitlab_backup.log"
KEEP=7                                 # how many backups to keep
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

# These paths are *in addition to* the standard GitLab application backup.
# Note: uploads/shared are usually included in the GitLab backup already,
# but listed here in case you explicitly want to archive them with config/ssl too.
CONFIG_PATHS=(
  "etc/gitlab"
  "etc/ssl"
  "var/opt/gitlab/gitlab-rails/uploads"
  "var/opt/gitlab/gitlab-rails/shared"
)

# ---- Helpers ----
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S%z')] $*" | tee -a "$LOG_FILE" ; }

rotate_backups() {
  local pattern="$1"
  # shellcheck disable=SC2012
  local files=( $(ls -1t "${pattern}" 2>/dev/null || true) )
  local count="${#files[@]}"
  if (( count > KEEP )); then
    for f in "${files[@]:KEEP}"; do
      rm -f -- "$f"
      log "Rotated old backup: $f"
    done
  fi
}

ensure_dirs() {
  mkdir -p "$BACKUP_DIR"
  mkdir -p "$(dirname "$LOG_FILE")"
}

trap 'log "ERROR: Backup failed (line $LINENO)."; exit 1' ERR

# ---- Start ----
ensure_dirs
log "Starting GitLab backup run…"

# 1) Trigger GitLab application backup
# Prefer the omnibus CLI if present; fall back to rake task name if needed.
if command -v gitlab-backup >/dev/null 2>&1; then
  log "Running: gitlab-backup create STRATEGY=copy"
  gitlab-backup create STRATEGY=copy 2>&1 | tee -a "$LOG_FILE"
elif command -v gitlab-rake >/dev/null 2>&1; then
  log "Running: gitlab-rake gitlab:backup:create STRATEGY=copy"
  gitlab-rake gitlab:backup:create STRATEGY=copy 2>&1 | tee -a "$LOG_FILE"
else
  log "ERROR: Neither gitlab-backup nor gitlab-rake found in PATH."
  exit 1
fi

# 2) Move/rename the generated GitLab backup tar into BACKUP_DIR with timestamped name
# shellcheck disable=SC2012
LATEST_BACKUP="$(ls -Art "$GITLAB_BACKUP_DIR"/*.tar* 2>/dev/null | tail -n 1 || true)"

if [[ -n "${LATEST_BACKUP}" && -f "$LATEST_BACKUP" ]]; then
  APP_TAR="${BACKUP_DIR}/gitlab_backup_${TIMESTAMP}.tar"
  # Preserve original compression if present (GitLab can create .tar or .tar.gz depending on version/config)
  if [[ "$LATEST_BACKUP" == *.tar.gz ]]; then
    APP_TAR="${APP_TAR}.gz"
  fi
  cp -f -- "$LATEST_BACKUP" "$APP_TAR"
  sha256sum "$APP_TAR" > "${APP_TAR}.sha256"
  log "Application backup copied to: $APP_TAR"
else
  log "ERROR: No GitLab application backup file found in $GITLAB_BACKUP_DIR"
  exit 1
fi

# 3) Create a single tar.gz for config/ssl/(optional)uploads/shared
CONFIG_TAR="${BACKUP_DIR}/gitlab_config_${TIMESTAMP}.tar.gz"
log "Creating config archive: $CONFIG_TAR"
# Use -C / to avoid absolute paths in the archive while preserving directory structure.
tar -czf "$CONFIG_TAR" -C / "${CONFIG_PATHS[@]}" 2>&1 | tee -a "$LOG_FILE"
sha256sum "$CONFIG_TAR" > "${CONFIG_TAR}.sha256"
log "Config archive created."

# 4) Set restrictive permissions (root-readable) — adjust if you store keys in these paths
chmod 600 "$BACKUP_DIR"/gitlab_*_"$TIMESTAMP".tar* || true
chmod 600 "$BACKUP_DIR"/gitlab_*_"$TIMESTAMP".sha256 || true

# 5) Rotate old backups
rotate_backups "${BACKUP_DIR}/gitlab_backup_*.tar*"
rotate_backups "${BACKUP_DIR}/gitlab_config_*.tar*"
rotate_backups "${BACKUP_DIR}/gitlab_backup_*.sha256"
rotate_backups "${BACKUP_DIR}/gitlab_config_*.sha256"

log "GitLab backup finished successfully."
