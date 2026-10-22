#!/usr/bin/env bash
# Recreate the ~/code development folder: clone all Bitbucket repos (with submodules)
# and restore the VS Code workspace files.
#
# Usage:
#   ./clone-code.sh [target-dir] [--branches]
#
#   target-dir   where to create the folder (default: $HOME/code)
#   --branches   after cloning, check out the working branch listed for each repo
#                (falls back to the default branch if it no longer exists on the remote)
#
# Safe to re-run: existing repos are fetched and their submodules updated, not re-cloned.

set -uo pipefail

TARGET="$HOME/code"
CHECKOUT_BRANCHES=false
for arg in "$@"; do
  case "$arg" in
    --branches) CHECKOUT_BRANCHES=true ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

BB="git@bitbucket.org:automationanywhere"

# bitbucket-repo | working branch (used only with --branches) | local dir (blank = repo name)
REPOS=(
  "aaenterprise|snarasim/dsCacheSecurityContext|aae"
  "ba-orchestrator|dscache-uprev-orchestrator-3.1.1-1013120137|"
  "bb-bot|master|"
  "cognitive-platform|dscache-uprev-iqbot-3.1.1-1013122123|"
  "connector-factory|dscache-uprev-acf-3.1.1-1015145358|"
  "controlroom|release/a360.41_CSO|"
  "distributed-cache|master|"
  "hbc|snarasim/PD-91072|"
  "protoss-ignite|release/2.3.x|"
  "storageservice|dscache-uprev-storage-3.1.1-1015145358|"
)

mkdir -p "$TARGET" "$TARGET/logs" "$TARGET/.vscode" || exit 1
cd "$TARGET" || exit 1

# Fail fast if SSH auth to Bitbucket isn't working.
if ! git ls-remote "$BB/bb-bot.git" HEAD >/dev/null 2>&1; then
  echo "ERROR: cannot reach $BB via SSH. Check your Bitbucket SSH key / VPN." >&2
  exit 1
fi

failed=()

for entry in "${REPOS[@]}"; do
  IFS='|' read -r repo branch dir <<<"$entry"
  dir="${dir:-$repo}"
  echo
  echo "=== $dir ($repo) ==="

  if [ -d "$dir/.git" ]; then
    echo "Already present, fetching..."
    git -C "$dir" fetch --all --prune || { failed+=("$dir"); continue; }
  else
    git clone --recurse-submodules "$BB/$repo.git" "$dir" || { failed+=("$dir"); continue; }
  fi

  if $CHECKOUT_BRANCHES && [ "$(git -C "$dir" branch --show-current)" != "$branch" ]; then
    if git -C "$dir" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
      git -C "$dir" checkout "$branch" || failed+=("$dir (checkout $branch)")
    else
      echo "Branch '$branch' not on remote; staying on $(git -C "$dir" branch --show-current)."
    fi
  fi

  git -C "$dir" submodule sync --recursive
  git -C "$dir" submodule update --init --recursive || failed+=("$dir (submodules)")
done

# VS Code workspace files (only written if missing, so local edits are kept).
write_if_missing() { [ -e "$1" ] || { cat >"$1"; echo "Created $1"; }; }

write_if_missing code.code-workspace <<'EOF'
{
	"folders": [
		{
			"path": "."
		}
	],
	"settings": {
		"java.jdt.ls.vmargs": "-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Dsun.zip.disableMemoryMapping=true -Xmx64G -Xms100m -Xlog:disable"
	}
}
EOF

write_if_missing distributed-cache.code-workspace <<'EOF'
{
	"folders": [
		{
			"path": "distributed-cache"
		},
		{
			"path": "protoss-ignite"
		},
		{
			"path": "aae"
		},
		{
			"path": "controlroom"
		}
	],
	"settings": {
		"java.compile.nullAnalysis.mode": "disabled"
	}
}
EOF

write_if_missing .vscode/settings.json <<'EOF'
{
    "python-envs.pythonProjects": [
        {
            "path": ".",
            "envManager": "ms-python.python:pyenv",
            "packageManager": "ms-python.python:pip"
        }
    ]
}
EOF

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "Done. Open with:  code \"$TARGET/code.code-workspace\""
else
  echo "Finished with errors in: ${failed[*]}" >&2
  exit 1
fi
