#!/usr/bin/env bash
#
# Lint and validate the repository. Used by `make check` and CI.
# Needs no secrets: 1Password lookups are answered by a stub `op`.
#
# Usage: scripts/check.sh
#
# Tools: shellcheck, shfmt, chezmoi (required); markdownlint-cli2, gitleaks,
# actionlint, plutil (used when installed, required with CI=true).

# ok/warn always succeed, so `cmd && ok || failed` is a safe if/else here.
# shellcheck disable=SC2015

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
strict_mode
cd "$DOTFILES_DIR"

failures=0
step() { log "$1"; }
failed() {
  warn "$1"
  failures=$((failures + 1))
}
optional() {
  has "$1" && return 0
  [[ "${CI:-}" == true ]] && die "$1 is required in CI"
  warn "$1 not installed; skipping $2"
  return 1
}

require shellcheck "brew install shellcheck"
require shfmt "brew install shfmt"
require chezmoi "brew install chezmoi"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# --- Render chezmoi templates without secrets ----------------------------------

# Stub 1Password CLI: answers `op read` with a recognisable placeholder.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/op" <<'EOF'
#!/bin/sh
while [ "$1" = --session ] || [ "$1" = --account ]; do shift 2; done
case "$1" in
--version) echo 2.32.0 ;;
signin) echo stub-session-token ;;
whoami | account) exit 0 ;;
read) echo "stub-value-for-$*" ;;
*) echo "op stub: unsupported command: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/op"
export PATH="$WORK/bin:$PATH"

# Render the config template non-interactively, once per signing method, and
# render every other template with each resulting config.
render_all() {
  local variant=$1 config="$WORK/$1/chezmoi.toml" out="$WORK/$1/rendered"
  mkdir -p "$out"
  # Unanswered prompts take their defaults. Flags are keyed by prompt text.
  chezmoi execute-template --init --no-tty \
    --promptChoice "Git commit signing method=$variant" \
    --source "$DOTFILES_DIR" <"$DOTFILES_DIR/home/.chezmoi.toml.tmpl" >"$config" ||
    {
      failed "home/.chezmoi.toml.tmpl failed to render ($variant)"
      return
    }

  local template rel
  while IFS= read -r template; do
    rel="${template#"$DOTFILES_DIR/home/"}"
    [[ "$rel" == .chezmoi.toml.tmpl ]] && continue
    mkdir -p "$out/$(dirname "$rel")"
    if ! chezmoi execute-template --config "$config" --source "$DOTFILES_DIR" \
      <"$template" >"$out/${rel%.tmpl}" 2>"$WORK/err"; then
      failed "$rel failed to render ($variant): $(cat "$WORK/err")"
    fi
  done < <(find "$DOTFILES_DIR/home" -name '*.tmpl' -type f | sort)

  # The full target state must also compute (catches bad attributes/ignores).
  chezmoi --config "$config" --source "$DOTFILES_DIR" --destination "$WORK/$variant/dest" \
    --persistent-state "$WORK/$variant/state.boltdb" managed >/dev/null 2>"$WORK/err" ||
    failed "chezmoi target state failed ($variant): $(cat "$WORK/err")"
}

step "Rendering chezmoi templates"
before=$failures
render_all gpg
render_all ssh
grep -q 'format = ssh' "$WORK/ssh/rendered/dot_gitconfig" || failed "ssh variant of dot_gitconfig lacks gpg.format = ssh"
((failures == before)) && ok "templates render for gpg and ssh signing"

# --- Shell scripts ----------------------------------------------------------------

shell_files=(setup.sh scripts/*.sh)
rendered_scripts=()
while IFS= read -r f; do rendered_scripts+=("$f"); done < <(find "$WORK/gpg/rendered/.chezmoiscripts" -name '*.sh' | sort)

step "ShellCheck"
if shellcheck --external-sources --source-path=SCRIPTDIR "${shell_files[@]}"; then
  ok "repository scripts"
else
  failed "shellcheck found problems in repository scripts"
fi
# Rendered chezmoi scripts source scripts/lib.sh by absolute path (SC1091), and
# may contain typographic quotes from config values such as the computer name (SC1112).
if shellcheck --external-sources --exclude=SC1091,SC1112 "${rendered_scripts[@]}"; then
  ok "rendered chezmoi scripts"
else
  failed "shellcheck found problems in rendered chezmoi scripts"
fi

step "shfmt"
if shfmt --diff --indent 2 "${shell_files[@]}" "${rendered_scripts[@]}"; then
  ok "formatting"
else
  failed "shfmt: run 'make fmt' to fix formatting"
fi

step "zsh syntax"
if has zsh; then
  for f in home/dot_zshrc home/dot_zprofile; do
    zsh -n "$f" || failed "$f has a syntax error"
  done
  ok "dot_zshrc, dot_zprofile"
else
  warn "zsh not installed; skipping"
fi

# --- Other configuration ------------------------------------------------------------

step "Other configuration"
if optional plutil "plist validation"; then
  plutil -lint "$WORK/gpg/rendered/Library/LaunchAgents/"*.plist >/dev/null || failed "LaunchAgent plist is invalid"
  ok "LaunchAgent plist"
fi
if optional actionlint "workflow linting"; then
  actionlint && ok "GitHub Actions workflows" || failed "actionlint found problems"
fi

step "Markdown"
if optional markdownlint-cli2 "Markdown linting"; then
  markdownlint-cli2 "**/*.md" >/dev/null 2>"$WORK/err" && ok "Markdown" ||
    failed "markdownlint: $(head -n 20 "$WORK/err")"
fi

step "Secrets"
if optional gitleaks "secret scanning"; then
  gitleaks git --no-banner --redact --log-level warn . && ok "no secrets in git history" ||
    failed "gitleaks found possible secrets"
  gitleaks dir --no-banner --redact --log-level warn . && ok "no secrets in working tree" ||
    failed "gitleaks found possible secrets in the working tree"
fi

if ((failures > 0)); then
  die "$failures check(s) failed"
fi
log "All checks passed"
