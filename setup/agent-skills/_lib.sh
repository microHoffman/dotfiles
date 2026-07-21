#!/usr/bin/env bash

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'agent-skills: missing required command: %s\n' "$1" >&2
    exit 1
  }
}

install_global_skills() {
  local source="$1"
  shift
  local skill
  local skill_args=()

  need_cmd npx
  for skill in "$@"; do
    skill_args+=(--skill "$skill")
  done
  npx -y skills@latest add "$source" \
    "${skill_args[@]}" \
    --agent '*' \
    --global \
    --yes
}

install_global_skill() {
  install_global_skills "$1" "$2"
}

require_repository() {
  local repository_path="$1"
  local label="$2"

  if [ ! -d "$repository_path/.git" ] && [ ! -f "$repository_path/.git" ]; then
    printf 'agent-skills: %s is not a Git working tree: %s\n' \
      "$label" "$repository_path" >&2
    exit 1
  fi
}

install_repository_skills() {
  local repository_path="$1"
  local source="$2"
  shift 2
  local skill
  local skill_args=()

  need_cmd npx
  for skill in "$@"; do
    skill_args+=(--skill "$skill")
  done
  (
    cd -- "$repository_path" || exit
    npx -y skills@latest add "$source" \
      "${skill_args[@]}" \
      --agent '*' \
      --yes
  )
}

install_repository_skill() {
  install_repository_skills "$1" "$2" "$3"
}
