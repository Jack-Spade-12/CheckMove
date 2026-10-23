#!/bin/bash

###############################################################################
# CONFIGURATION
###############################################################################

# Folder structure, in order. Each entry is LABEL=value.
#   - value filled in  -> used as is, no prompt
#   - value empty      -> you are prompted for it
#   - blank answer     -> that part is skipped
#   - LABEL ending in ! -> required (a blank answer is not accepted)
# Add, remove or reorder entries freely.
PATH_PARTS=(
    "DEFAULT_ROOT_DESTINATION="
    "YEAR="
    "CLIENT="
    "PROJECT="
    "FOLDER!="
)

###############################################################################
# FUNCTIONS
###############################################################################

print_header() {
    
    local CYAN=$'\033[1;36m'
    local WHITE=$'\033[1;37m'
    local DIM=$'\033[2m'
    local RESET=$'\033[0m'
    local DIV

    DIV=$(printf '─%.0s' $(seq 1 77))

    clear

    echo
    echo "${CYAN}${DIV}${RESET}"
    echo
    echo "${CYAN} ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗███╗   ███╗ ██████╗ ██╗   ██╗███████╗${RESET}"
    echo "${CYAN}██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝████╗ ████║██╔═══██╗██║   ██║██╔════╝${RESET}"
    echo "${CYAN}██║     ███████║█████╗  ██║     █████╔╝ ██╔████╔██║██║   ██║██║   ██║█████╗  ${RESET}"
    echo "${CYAN}██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ██║╚██╔╝██║██║   ██║╚██╗ ██╔╝██╔══╝  ${RESET}"
    echo "${CYAN}╚██████╗██║  ██║███████╗╚██████╗██║  ██╗██║ ╚═╝ ██║╚██████╔╝ ╚████╔╝ ███████╗${RESET}"
    echo "${CYAN} ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝${RESET}"
    echo
    echo "  ${WHITE}Copy it. Check it. Trust it.${RESET}"
    echo "  ${DIM}rsync transfer  •  checksum verified  •  auto-retry${RESET}"
    echo
    echo "${CYAN}${DIV}${RESET}"
    echo
}

print_instructions() {

    local RED=$'\033[0;31m'
    local RESET=$'\033[0m'

    echo
    echo "====================================================="
    echo "INSTRUCTIONS"
    echo "====================================================="
    echo
    echo "WHAT TO DO:"
    echo "  1. Enter or paste one or more file/folder paths."
    echo "  2. ${RED}Press Enter on an EMPTY line when you are done.${RESET}"
    echo "  3. Answer any destination prompts that follow."
    echo "  4. Type '${RED}exit${RESET}' at any prompt to quit."
    echo
    echo "WHAT YOU CAN DO:"
    echo "  1. Paste one path per line. Spaces in a pasted path are fine."
    echo "  2. Put several paths on one line by wrapping each in quotes"
    echo "     ('single' or \"double\") or escaping spaces with a backslash (\\ )."
    echo "  3. Drag & drop items into this window (spaces are escaped for you)."
    echo "  4. Use ~ for your home folder."
    echo "  5. Mix files and folders freely. The type is detected automatically."
    echo "  6. Control how folders are copied with a trailing slash:"
    echo "       ${RED}/path/folder   -> copies the folder ITSELF"
    echo "       /path/folder/  -> copies only the CONTENTS of the folder${RESET}"
    echo
    echo "WHAT YOU CAN'T DO:"
    echo "  1. Put several unquoted paths with spaces on one line."
    echo "     A line is only kept whole if it is a real path as written."
    echo "     Otherwise it is split at unescaped spaces."
    echo "  2. Use wildcards (*, ?). They are NOT expanded."
    echo "  3. Use variables (\$HOME, \$PWD). Only ~ is expanded."
    echo "  4. Use source paths that do not exist. The script prints the bad"
    echo "     path and exits."
    echo "  5. Use 'exit' as a file or folder name."
    echo
    echo "CONFIGURATION (PATH_PARTS at the top of the script):"
    echo "  1. The destination path is built from the entries in order."
    echo "  2. The first entry is the root destination (absolute path or ~)."
    echo "  3. LABEL=value   -> used as is, no prompt."
    echo "  4. LABEL=        -> you are prompted. A blank answer skips the part."
    echo "  5. LABEL${RED}!${RESET}=       -> required. A blank answer is not accepted."
    echo "  6. Folders that do not exist are listed and confirmed first,"
    echo "     but only created after you approve the final summary."
    echo

    PREVIEW=""
    for ENTRY in "${PATH_PARTS[@]}"; do
        P_LABEL="${ENTRY%%=*}"
        P_VALUE="${ENTRY#*=}"
        P_LABEL="${P_LABEL%!}"
        if [ -n "$P_VALUE" ]; then
            PREVIEW+="${P_VALUE%/}/"
        else
            PREVIEW+="<${P_LABEL}>/"
        fi
    done
    echo "CURRENT DESTINATION STRUCTURE:"
    echo "  $PREVIEW"
    echo
}

# Splits a line into PARSED[] on whitespace that is NOT inside quotes
# and NOT backslash-escaped. Handles '...', "...", and \<char>.
# Returns 1 if a quote is never closed.
parse_line() {
    local LINE="$1"
    local LEN=${#LINE}
    local i=0 CH NEXT TOKEN="" IN_TOKEN=0 QUOTE=""

    PARSED=()

    while [ $i -lt $LEN ]; do
        CH="${LINE:$i:1}"

        if [ "$QUOTE" = "'" ]; then
            # Inside single quotes: everything is literal until the closing '
            if [ "$CH" = "'" ]; then QUOTE=""; else TOKEN+="$CH"; fi

        elif [ "$QUOTE" = '"' ]; then
            # Inside double quotes: backslash only escapes " \ $ `
            if [ "$CH" = '"' ]; then
                QUOTE=""
            elif [ "$CH" = "\\" ] && [ $((i + 1)) -lt $LEN ]; then
                NEXT="${LINE:$((i + 1)):1}"
                case "$NEXT" in
                    '"'|'\'|'$'|'`') TOKEN+="$NEXT"; i=$((i + 1)) ;;
                    *) TOKEN+="$CH" ;;
                esac
            else
                TOKEN+="$CH"
            fi

        else
            # Outside quotes
            case "$CH" in
                "'"|'"')
                    QUOTE="$CH"; IN_TOKEN=1 ;;
                '\')
                    if [ $((i + 1)) -lt $LEN ]; then
                        TOKEN+="${LINE:$((i + 1)):1}"
                        i=$((i + 1))
                    else
                        TOKEN+="$CH"
                    fi
                    IN_TOKEN=1 ;;
                ' '|$'\t')
                    if [ $IN_TOKEN -eq 1 ]; then
                        [ -n "$TOKEN" ] && PARSED+=("$TOKEN")
                        TOKEN=""; IN_TOKEN=0
                    fi ;;
                *)
                    TOKEN+="$CH"; IN_TOKEN=1 ;;
            esac
        fi

        i=$((i + 1))
    done

    [ -n "$QUOTE" ] && return 1

    if [ $IN_TOKEN -eq 1 ] && [ -n "$TOKEN" ]; then
        PARSED+=("$TOKEN")
    fi

    return 0
}

check_exit() {
    # Case-insensitive; ignores surrounding whitespace
    local VALUE
    VALUE=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    if [ "$VALUE" = "exit" ]; then
        echo
        echo "Exit requested. Terminating program."
        exit 0
    fi
}

ask_yes_no() {
    while true; do
        read -rp "$1 [y/n/exit]: " ANSWER
        check_exit "$ANSWER"

        case "$ANSWER" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Please enter y or n." ;;
        esac
    done
}

# Builds ROOT and SEGMENTS[] from PATH_PARTS, prompting for empty values.
# Must be called directly (not inside $(...)) so "exit" works.
build_segments() {

    local ENTRY LABEL VALUE REQUIRED
    local IS_ROOT=1

    ROOT=""
    SEGMENTS=()

    for ENTRY in "${PATH_PARTS[@]}"; do

        LABEL="${ENTRY%%=*}"
        VALUE="${ENTRY#*=}"
        REQUIRED=0

        if [[ "$LABEL" == *'!' ]]; then
            REQUIRED=1
            LABEL="${LABEL%!}"
        fi

        # The root is always required
        [ $IS_ROOT -eq 1 ] && REQUIRED=1

        # Prompt if empty
        if [ -z "$VALUE" ]; then
            while true; do
                echo
                if [ $REQUIRED -eq 1 ]; then
                    read -rp "$LABEL: " VALUE
                else
                    read -rp "$LABEL (optional, Enter to skip): " VALUE
                fi
                check_exit "$VALUE"

                # Trim whitespace
                VALUE="${VALUE#"${VALUE%%[![:space:]]*}"}"
                VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"

                if [ -z "$VALUE" ] && [ $REQUIRED -eq 1 ]; then
                    echo "$LABEL cannot be empty."
                    continue
                fi
                break
            done
        fi

        if [ $IS_ROOT -eq 1 ]; then

            # Root: expand ~, require an absolute path, strip trailing slashes
            if [[ "$VALUE" == "~" || "$VALUE" == "~/"* ]]; then
                VALUE="${HOME}${VALUE:1}"
            fi

            if [[ "$VALUE" != /* ]]; then
                echo "ERROR: $LABEL must be an absolute path (or start with ~): $VALUE"
                exit 1
            fi

            while [[ "$VALUE" != "/" && "$VALUE" == */ ]]; do VALUE="${VALUE%/}"; done

            ROOT="$VALUE"
            IS_ROOT=0

        else

            # Strip leading/trailing slashes so parts join cleanly
            while [[ "$VALUE" == /* ]]; do VALUE="${VALUE#/}"; done
            while [[ "$VALUE" == */ ]]; do VALUE="${VALUE%/}"; done

            # Block path traversal
            case "/$VALUE/" in
                */../*)
                    echo "ERROR: '..' is not allowed in $LABEL: $VALUE"
                    exit 1 ;;
            esac

            # Empty = not added
            [ -n "$VALUE" ] && SEGMENTS+=("$VALUE")
        fi
    done
}

###############################################################################
# START
###############################################################################

print_header
print_instructions

###############################################################################
# SOURCE SELECTION
###############################################################################

SOURCES=""
ITEMS=()

while true
do
    IFS= read -r -p "Files/Folders: " LINE

    # Trim leading/trailing whitespace
    LINE="${LINE#"${LINE%%[![:space:]]*}"}"
    LINE="${LINE%"${LINE##*[![:space:]]}"}"

    # Empty line = done
    [ -z "$LINE" ] && break

    check_exit "$LINE"

    # Step 1: is the WHOLE line a real path? (handles unescaped spaces)
    CANDIDATE="$LINE"

    # Remove one pair of wrapping quotes, if present
    if [ ${#CANDIDATE} -ge 2 ]; then
        FIRST="${CANDIDATE:0:1}"
        LAST="${CANDIDATE: -1}"
        if { [ "$FIRST" = "'" ] || [ "$FIRST" = '"' ]; } && [ "$FIRST" = "$LAST" ]; then
            CANDIDATE="${CANDIDATE:1:${#CANDIDATE}-2}"
        fi
    fi

    if [[ "$CANDIDATE" == "~" || "$CANDIDATE" == "~/"* ]]; then
        CANDIDATE="${HOME}${CANDIDATE:1}"
    fi

    if [ -e "$CANDIDATE" ]; then
        ITEMS+=("$CANDIDATE")
        continue
    fi

    # Step 2: otherwise split on unquoted, unescaped whitespace
    if ! parse_line "$LINE"; then
        echo
        echo "ERROR: Unmatched quote in:"
        echo "$LINE"
        exit 1
    fi

    ITEMS+=("${PARSED[@]}")
done

if [ ${#ITEMS[@]} -eq 0 ]; then
    echo "No source files or folders entered."
    exit 1
fi

echo
echo "Validating..."

for ITEM in "${ITEMS[@]}"
do
    # Expand leading ~ to home directory
    if [[ "$ITEM" == "~" || "$ITEM" == "~/"* ]]; then
        ITEM="${HOME}${ITEM:1}"
    fi

    # Detect file vs. folder automatically.
    # Trailing slashes are intentionally preserved for rsync.
    if [ -f "$ITEM" ]; then
        echo "  ✔ File:                    $ITEM"
    elif [ -d "$ITEM" ]; then
        if [[ "$ITEM" == */ ]]; then
            echo "  ✔ Folder (contents only):  $ITEM"
        else
            echo "  ✔ Folder (folder itself):  $ITEM"
        fi
    else
        echo
        echo "ERROR: File or folder does not exist:"
        echo "$ITEM"
        exit 1
    fi

    SOURCES+="${ITEM}"$'\n'
done

###############################################################################
# DESTINATION STRUCTURE (from PATH_PARTS)
###############################################################################

build_segments

FINAL_PATH="$ROOT"
for SEG in "${SEGMENTS[@]}"; do
    FINAL_PATH="${FINAL_PATH}/${SEG}"
done

###############################################################################
# VALIDATE PATHS (nothing is created here)
###############################################################################

MISSING=()
CURRENT="$ROOT"

check_level() {
    local TARGET="$1"

    if [ -e "$TARGET" ] && [ ! -d "$TARGET" ]; then
        echo
        echo "ERROR: A file exists where a folder is needed:"
        echo "$TARGET"
        exit 1
    fi

    if [ ! -d "$TARGET" ]; then
        echo
        echo "Folder does not exist:"
        echo "$TARGET"

        if ask_yes_no "Create it when the transfer starts?"; then
            MISSING+=("$TARGET")
        else
            echo "Operation cancelled."
            exit 1
        fi
    fi
}

check_level "$CURRENT"
for SEG in "${SEGMENTS[@]}"; do
    CURRENT="${CURRENT}/${SEG}"
    check_level "$CURRENT"
done

###############################################################################
# SUMMARY
###############################################################################

echo
echo "====================================================="
echo "TRANSFER SUMMARY"
echo "====================================================="
echo
echo "FILES/FOLDERS TO COPY:"

while IFS= read -r SOURCE
do
    [ -z "$SOURCE" ] && continue
    echo "  <> $SOURCE"
done <<< "$SOURCES"

echo
echo "DESTINATION:"
echo "  => $FINAL_PATH"

if [ ${#MISSING[@]} -gt 0 ]; then
    echo
    echo "FOLDERS TO BE CREATED:"
    for M in "${MISSING[@]}"; do
        echo "  + $M"
    done
fi

echo
echo "The above files/folders will be copied"
echo "to the destination shown above."
echo

if ! ask_yes_no "Proceed?"; then
    echo "Operation cancelled."
    exit 0
fi

###############################################################################
# CREATE FOLDERS (only after everything has passed)
###############################################################################

for M in "${MISSING[@]}"; do
    if ! mkdir -p "$M"; then
        echo "Failed to create folder:"
        echo "$M"
        exit 1
    fi
    echo "Created: $M"
done

###############################################################################
# TRANSFER + CHECKSUM VERIFICATION LOOP
###############################################################################

while true
do

    echo
    echo "====================================================="
    echo "STARTING TRANSFER"
    echo "====================================================="
    echo

    TRANSFER_FAILED=0

    while IFS= read -r SOURCE
    do

        [ -z "$SOURCE" ] && continue

        echo
        echo "Copying:"
        echo "$SOURCE"
        echo

        rsync \
            -avh \
            --progress \
            --partial \
            "$SOURCE" \
            "$FINAL_PATH/"

        RC=$?

        if [ $RC -ne 0 ]; then
            TRANSFER_FAILED=1
            break
        fi

    done <<< "$SOURCES"

    ###########################################################################
    # TRANSFER FAILED
    ###########################################################################

    if [ $TRANSFER_FAILED -ne 0 ]; then

        echo
        echo "Transfer failed."
        echo "Retrying in 2 seconds..."
        sleep 2

        continue
    fi

    ###########################################################################
    # CHECKSUM VERIFICATION
    ###########################################################################

    echo
    echo "====================================================="
    echo "CHECKSUM VERIFICATION"
    echo "====================================================="
    echo

    VERIFY_FAILED=0

    while IFS= read -r SOURCE
    do

        [ -z "$SOURCE" ] && continue

        echo "Verifying:"
        echo "$SOURCE"
        echo

        VERIFY_OUTPUT=$(
        rsync \
            -avhc \
            --dry-run \
            "$SOURCE" \
            "$FINAL_PATH/"
        )

        if echo "$VERIFY_OUTPUT" | grep -qE '^>|^<|^c'; then

            echo "Verification failed for:"
            echo "$SOURCE"

            VERIFY_FAILED=1
        fi

    done <<< "$SOURCES"

    ###########################################################################
    # VERIFICATION PASSED
    ###########################################################################

    if [ $VERIFY_FAILED -eq 0 ]; then

        echo
        echo "====================================================="
        echo "TRANSFER COMPLETE"
        echo "====================================================="
        echo
        echo "All files copied successfully."
        echo
        echo "Checksum verification PASSED."
        echo
        echo "Destination:"
        echo "$FINAL_PATH"
        echo

        break
    fi

    ###########################################################################
    # VERIFICATION FAILED
    ###########################################################################

    echo
    echo "Verification detected differences."
    echo "Retrying transfer in 2 seconds..."
    echo

    sleep 2

done

###############################################################################
# END
###############################################################################

echo "====================================================="
echo "TRANSFER COMPLETE... EXITING"
echo "====================================================="
echo