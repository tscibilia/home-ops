#!/usr/bin/env bash
set -euo pipefail

function notify() {
    local event="${KOMETA_EVENT_TYPE:-}"
    local url="${KOMETA_APPLICATION_URL:-https://kometa.wiki}"

    # Ignore non-error events
    case "${event}" in
        "global_error"|"library_error"|"collection_error"|"playlist_error") ;;
        *)
            echo "[INFO] Ignoring non-error event: ${event:-unknown}"
            return 0
            ;;
    esac

    local pushover_title pushover_message pushover_priority pushover_url pushover_url_title
    pushover_url="${url}"
    pushover_url_title="View Kometa"
    pushover_priority="high"

    if [[ "${event}" == "global_error" ]]; then
        printf -v pushover_title "Kometa Global Error"
        printf -v pushover_message "<b>Global Error</b><br><small>%s</small>" \
            "${KOMETA_MESSAGE}"
    elif [[ "${event}" == "library_error" ]]; then
        printf -v pushover_title "Kometa Library Error"
        printf -v pushover_message "<b>Library:</b> %s<br><small>%s</small>" \
            "${KOMETA_LIBRARY_NAME}" \
            "${KOMETA_MESSAGE}"
    elif [[ "${event}" == "collection_error" ]]; then
        printf -v pushover_title "Kometa Collection Error"
        printf -v pushover_message "<b>Library:</b> %s<br><b>Collection:</b> %s<br><small>%s</small>" \
            "${KOMETA_LIBRARY_NAME}" \
            "${KOMETA_COLLECTION_NAME}" \
            "${KOMETA_MESSAGE}"
    elif [[ "${event}" == "playlist_error" ]]; then
        printf -v pushover_title "Kometa Playlist Error"
        printf -v pushover_message "<b>Playlist:</b> %s<br><small>%s</small>" \
            "${KOMETA_PLAYLIST_NAME}" \
            "${KOMETA_MESSAGE}"
    fi

    apprise -vv --title "${pushover_title}" --body "${pushover_message}" --input-format html \
        "${KOMETA_PUSHOVER_URL}?url=${pushover_url}&url_title=${pushover_url_title}&priority=${pushover_priority}&format=html"
}

function main() {
    notify
}

main "$@"
