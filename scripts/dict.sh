

# Dictionary storage file
dict_file="dict.db"

# Declare dictionary
declare -A dictionary

# Ensure the dictionary file exists
touch "$dict_file"

# Function to add an entry (writes to dictionary.db)
add_entry() {
    local key="$1"
    local value="$2"
    remove_entry "$key"  # Ensure no duplicate keys
    echo "$key=$value" >> "$dict_file"
    dictionary["$key"]="$value"
}

# Function to remove an entry
remove_entry() {
    local key="$1"
    unset dictionary["$key"]
    grep -v "^$key=" "$dict_file" > "$dict_file.tmp" && mv "$dict_file.tmp" "$dict_file"
}

# Function to get a value by key
get_entry() {
    local key="$1"
    echo "${dictionary[$key]}"
}

# Function to list all entries
list_entries() {
    for key in "${!dictionary[@]}"; do
        echo "$key=${dictionary[$key]}"
    done
}

# Function to load dictionary from dictionary.db
load_dictionary() {
    while IFS='=' read -r key value; do
        if [[ -n "$key" && -n "$value" ]]; then
            dictionary["$key"]="$value"
        fi
    done < "$dict_file"
}

# Ensure dictionary is loaded at script startup
load_dictionary
