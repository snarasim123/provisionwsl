#!/usr/bin/env bash

require_repo_checkout() {
    local repo_path="$HOME/code/provisionwsl"

    if [[ ! -d "$repo_path/.git" && ! -f "$repo_path/playbook-github.yaml" ]]; then
        echo "Expected existing repo checkout at $repo_path"
        exit 1
    fi

    export GITHUB_PLAYBOOK_REPO_PATH="$repo_path"
}

run_ansible() {
    cd "$GITHUB_PLAYBOOK_REPO_PATH"

    if [[ ! -f secrets.yaml || ! -f secrets.pass ]]; then
        echo "GitHub playbook requires secrets.yaml and secrets.pass"
        exit 1
    fi

    chmod -x secrets.*
    ansible-playbook -i hosts -e @secrets.yaml --vault-password-file secrets.pass ./playbook-github.yaml
}

profile_path=$1
source "$profile_path"

require_repo_checkout
echo "#### install-github.sh: profile_path = $profile_path repo = $GITHUB_PLAYBOOK_REPO_PATH"

run_ansible