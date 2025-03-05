#!/bin/bash

# Function to check if SQLite is already installed
is_sqlite_installed() {
    local install_dir="$1"
    if [ -d "$install_dir" ] && [ -f "$install_dir/sqlite3" ]; then
        echo "SQLite is already installed in '$install_dir'."
        return 0  # SQLite is installed
    else
        echo "SQLite is not installed in '$install_dir'."
        return 1  # SQLite is not installed
    fi
}

# Function to download and install SQLite (only if not already installed)
install_sqlite() {
    local install_dir="$1"
    if is_sqlite_installed "$install_dir"; then
        echo "Skipping SQLite installation (already installed in '$install_dir')."
        return
    fi

    echo "Downloading SQLite..."
    wget "$SQLITE_URL" -O "$SQLITE_ZIP"
    if [ $? -ne 0 ]; then
        echo "Failed to download SQLite."
        exit 1
    fi
	mkdir -p "$install_dir"
    echo "Unzipping SQLite to '$install_dir'..."
    unzip -q "$SQLITE_ZIP"
    if [ $? -ne 0 ]; then
        echo "Failed to unzip SQLite."
        exit 1
    fi
	cp sqlite-tools-linux-x86-3420000/* "$install_dir"
	cp sqlite-tools-linux-x86-3420000/.* "$install_dir"
	rm -rf sqlite-tools-linux-x86-3420000/*
	rmdir sqlite-tools-linux-x86-3420000
    echo "SQLite installed successfully in '$install_dir'."
}

# Function to create a database and table
create_database() {
    local db_name="$1"
    local table_name="$2"
    local install_dir="$3"
    echo "Creating database '$db_name' and table '$table_name'..."
    ./"$install_dir"/sqlite3 "$db_name" "CREATE TABLE $table_name (id INTEGER PRIMARY KEY, name TEXT, email TEXT);"
    if [ $? -ne 0 ]; then
        echo "Failed to create database or table."
        exit 1
    fi
    echo "Database and table created successfully."
}

# Function to insert a row into the table
insert_row() {
    local db_name="$1"
    local table_name="$2"
    local name="$3"
    local email="$4"
    local install_dir="$5"
    echo "Inserting row into the table '$table_name'..."
    ./"$install_dir"/sqlite3 "$db_name" "INSERT INTO $table_name (name, email) VALUES ('$name', '$email');"
    if [ $? -ne 0 ]; then
        echo "Failed to insert row."
        exit 1
    fi
    echo "Row inserted successfully."
}

# Function to check if a row exists (parameterized)
check_row() {
    local db_name="$1"
    local table_name="$2"
    local name="$3"
    local email="$4"
    local install_dir="$5"
    echo "Checking if the row with name='$name' and email='$email' exists in table '$table_name'..."
    RESULT=$(./"$install_dir"/sqlite3 "$db_name" "SELECT * FROM $table_name WHERE name='$name' AND email='$email';")
    if [ -z "$RESULT" ]; then
        echo "Row does not exist."
        exit 1
    else
        echo "Row exists: $RESULT"
    fi
}

# Main script execution
echo "Starting SQLite installation and database setup..."



# Step 2: Download and install SQLite (only if not already installed)


# Step 4: Insert a row into the table
# image_hash=$(/bin/echo "test" | /usr/bin/md5sum | /bin/cut -f1 -d" ")

# INSERT_NAME=$image_hash
# INSERT_EMAIL="john@example.com"
# insert_row "$DB_NAME" "$TABLE_NAME" "$INSERT_NAME" "$INSERT_EMAIL" "$INSTALL_DIR"

# Step 5: Check if the row exists
# check_row "$DB_NAME" "$TABLE_NAME" "$INSERT_NAME" "$INSERT_EMAIL" "$INSTALL_DIR"

# echo "SQLite installation and database setup complete."