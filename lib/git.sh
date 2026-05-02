# Git helpers. All commands run with -C "$CSL_GIT_CWD".

CSL_GIT_CWD=""

git_init_cwd() {
  CSL_GIT_CWD=$(printf '%s' "$INPUT_JSON" | jq -r '.workspace.current_dir // .cwd // "."')
}

git_in_repo() {
  git_init_cwd
  command -v git >/dev/null 2>&1 || return 1
  git -C "$CSL_GIT_CWD" rev-parse --git-dir >/dev/null 2>&1
}

git_branch_name() {
  git -C "$CSL_GIT_CWD" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$CSL_GIT_CWD" rev-parse --short HEAD 2>/dev/null
}

# Prints "STAGED UNSTAGED UNTRACKED"
git_status_counts() {
  local porcelain staged=0 unstaged=0 untracked=0 line x y
  porcelain=$(git -C "$CSL_GIT_CWD" status --porcelain=v1 2>/dev/null) || {
    printf '0 0 0'
    return
  }
  [ -z "$porcelain" ] && { printf '0 0 0'; return; }
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    x="${line:0:1}"
    y="${line:1:1}"
    if [ "$x$y" = "??" ]; then
      untracked=$((untracked + 1))
      continue
    fi
    if [ "$x" != " " ] && [ "$x" != "?" ]; then
      staged=$((staged + 1))
    fi
    if [ "$y" != " " ] && [ "$y" != "?" ]; then
      unstaged=$((unstaged + 1))
    fi
  done <<< "$porcelain"
  printf '%d %d %d' "$staged" "$unstaged" "$untracked"
}

# Prints "AHEAD BEHIND"
git_ahead_behind() {
  local upstream out
  upstream=$(git -C "$CSL_GIT_CWD" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || {
    printf '0 0'
    return
  }
  out=$(git -C "$CSL_GIT_CWD" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null) || {
    printf '0 0'
    return
  }
  printf '%s' "$out" | awk '{print $1, $2}'
}
