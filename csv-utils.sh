#!/usr/bin/env bash

get_csv_record() {
    local distro_id="$1"
    local scriptroot_path="$2"
    local csv_path="${scriptroot_path}/data/urls.csv"
    
    echo "##### DEBUG get_csv_record: distro_id='$distro_id'" >&2
    echo "##### DEBUG get_csv_record: scriptroot_path='$scriptroot_path'" >&2
    echo "##### DEBUG get_csv_record: csv_path='$csv_path'" >&2
    
    # Validate inputs
    if [[ -z "$distro_id" ]]; then
        echo "ERROR: distro_id is required" >&2
        return 1
    fi
    
    if [[ ! -f "$csv_path" ]]; then
        echo "ERROR: CSV file not found: $csv_path" >&2
        return 1
    fi
    
    echo "##### DEBUG get_csv_record: CSV file exists, reading..." >&2
    
    # Clear previous values
    PROFILE_ID=""
    PROFILE_PLATFORM=""
    distro_type=""
    download_url=""
    PROFILE_MD5=""
    PROFILE_SHA512=""
    PROFILE_SHA256=""
    
    # Read CSV and find matching record
    # Skip header line and comments (lines starting with #)
    local line
    local found=0
    
    while IFS=',' read -r id platform type url md5 sha512 sha256; do
        # Skip header and comments
        [[ "$id" == "ID" ]] && continue
        [[ "$id" =~ ^# ]] && continue
        [[ -z "$id" ]] && continue
        
        # Check if this is our record
        if [[ "$id" == "$distro_id" ]]; then
            PROFILE_ID="$id"
            PROFILE_PLATFORM="$platform"
            distro_type="$type"
            download_url="$url"
            PROFILE_MD5="$md5"
            PROFILE_SHA512="$sha512"
            PROFILE_SHA256="$sha256"
            found=1
            break
        fi
    done < "$csv_path"
    
    if [[ $found -eq 0 ]]; then
        echo "ERROR: distro_id '$distro_id' not found in CSV" >&2
        return 1
    fi
    
    echo "##### DEBUG get_csv_record: Found record - PROFILE_ID='$PROFILE_ID', download_url='$download_url'" >&2
    return 0
}

print_csv_record() {
    echo "=== CSV Record ==="
    echo "PROFILE_ID:       ${PROFILE_ID:-<not set>}"
    echo "PROFILE_PLATFORM: ${PROFILE_PLATFORM:-<not set>}"
    echo "distro_type:      ${distro_type:-<not set>}"
    echo "download_url:     ${download_url:-<not set>}"
    echo "PROFILE_MD5:      ${PROFILE_MD5:-<not set>}"
    echo "PROFILE_SHA512:   ${PROFILE_SHA512:-<not set>}"
    echo "PROFILE_SHA256:   ${PROFILE_SHA256:-<not set>}"
    echo "================="
}


list_csv_ids() {
    local scriptroot_path="$1"
    local csv_path="${scriptroot_path}/data/urls.csv"
    
    if [[ ! -f "$csv_path" ]]; then
        echo "ERROR: CSV file not found: $csv_path" >&2
        return 1
    fi
    
    echo "Available distro IDs:"
    while IFS=',' read -r id platform type url md5 sha512 sha256; do
        # Skip header and comments
        [[ "$id" == "ID" ]] && continue
        [[ "$id" =~ ^# ]] && continue
        [[ -z "$id" ]] && continue
        
        echo "  $id ($type on $platform)"
    done < "$csv_path"
}


load_distro_from_profile() {
    local profile_path="$1"
    local scriptroot_path="$2"
    
    if [[ -z "$profile_path" ]]; then
        echo "ERROR: profile_path is required" >&2
        return 1
    fi
    
    if [[ ! -f "$profile_path" ]]; then
        echo "ERROR: Profile file not found: $profile_path" >&2
        return 1
    fi
    
    # Source the profile to get ps_distro_id
    source "$profile_path"
    
    if [[ -z "$ps_distro_id" ]]; then
        echo "WARNING: ps_distro_id not set in profile, skipping CSV lookup" >&2
        return 1
    fi
    
    # Load the CSV record
    get_csv_record "$ps_distro_id" "$scriptroot_path"
    return $?
}
