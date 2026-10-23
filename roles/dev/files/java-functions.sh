#!/usr/bin/env bash

java-use() {
    if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+$ ]]; then
        printf 'Usage: java-use <major-version> (for example: java-use 17)\n' >&2
        return 2
    fi

    local java_home="/usr/lib/jvm/java-$1-openjdk"
    if [[ ! -x "$java_home/bin/java" || ! -x "$java_home/bin/javac" ]]; then
        printf 'JDK %s is not installed at %s (java and javac are required).\n' "$1" "$java_home" >&2
        return 1
    fi
    local tool output
    for tool in java javac; do
        if ! output=$("$java_home/bin/$tool" -version 2>&1); then
            printf 'Cannot use JDK %s: %s failed:\n%s\n' "$1" "$tool" "$output" >&2
            return 1
        fi
    done

    local remaining="$PATH" entry new_path="$java_home/bin"
    local previous_java_bin="${JAVA_HOME:+$JAVA_HOME/bin}"
    while true; do
        entry="${remaining%%:*}"
        if [[ "$entry" != "$previous_java_bin" || -z "$previous_java_bin" ]]; then
            case "$entry" in
                /usr/lib/jvm/java-*-openjdk/bin) ;;
                *) new_path+=":$entry" ;;
            esac
        fi
        [[ "$remaining" == *:* ]] || break
        remaining="${remaining#*:}"
    done

    export JAVA_HOME="$java_home"
    export PATH="$new_path"
    hash -r
    printf 'Using Java %s (%s)\n' "$1" "$JAVA_HOME"
}
