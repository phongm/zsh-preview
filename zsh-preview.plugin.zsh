autoload -Uz add-zle-hook-widget

# Show suggestions only for aliases whose expanded command starts with these words.
# Add more commands as needed.
typeset -ga ALIAS_PREVIEW_COMMANDS=(git docker)

# Maximum number of alias suggestions to display at once (window size).
typeset -gi ALIAS_PREVIEW_MAX=${ALIAS_PREVIEW_MAX:-5}

# ---- Internal state ----
typeset -g _alias_preview_last=""
typeset -ga _ap_all_items=()        # ALL matching candidate alias names (sorted)
typeset -ga _ap_items=()            # currently visible window of candidates
typeset -gi _ap_sel=0               # highlighted absolute index (0 = not engaged)
typeset -gi _ap_offset=0            # scroll offset (0-based start of visible window)
typeset -g _ap_suppress_word=""     # hide menu while first word equals this (after accept)
typeset -g _ap_last_word=""         # last seen first word (to reset selection on change)
# Original key bindings + save-flag must persist across re-sources, so they are
# declared WITHOUT "=value" (a bare typeset preserves any existing value).
typeset -g _ap_orig_up _ap_orig_down _ap_orig_tab
typeset -gA _ap_orig_digit
typeset -g _ap_originals_saved

# Return 0 if $1 is a subsequence of $2 (characters appear in order, fuzzy match).
function _alias_preview_is_subseq() {
    local word="$1" str="$2"
    local -i wi=1 ai=1
    while (( wi <= ${#word} && ai <= ${#str} )); do
        [[ "${word[wi]}" == "${str[ai]}" ]] && (( wi++ ))
        (( ai++ ))
    done
    (( wi > ${#word} ))
}

# Compute ALL matching alias names for the current first word into _ap_all_items,
# then derive the visible window into _ap_items.
function _ap_compute_items() {
    local trimmed="${BUFFER#"${BUFFER%%[! ]*}"}"
    local word="${trimmed%% *}"

    # Reset the highlight whenever the word being typed changes.
    if [[ "$word" != "$_ap_last_word" ]]; then
        _ap_sel=0
        _ap_offset=0
        _ap_last_word="$word"
    fi

    _ap_all_items=()
    _ap_items=()
    [[ -z "$word" ]] && return
    [[ "$word" == "$_ap_suppress_word" ]] && return

    local -a candidates=()
    local alias_name expanded exp_cmd
    local -i score
    for alias_name in ${(k)aliases}; do
        expanded="${aliases[$alias_name]}"
        exp_cmd="${expanded%% *}"
        (( ${ALIAS_PREVIEW_COMMANDS[(Ie)$exp_cmd]} )) || continue

        score=0
        if [[ "$alias_name" == "$word" ]]; then
            score=10000
        elif [[ "$alias_name" == "$word"* ]]; then
            score=$(( 5000 - ${#alias_name} ))
        elif [[ "$alias_name" == *"$word"* ]]; then
            score=$(( 1000 - ${#alias_name} ))
        elif _alias_preview_is_subseq "$word" "$alias_name"; then
            score=$(( 100 - ${#alias_name} ))
        fi

        (( score > 0 )) && candidates+=("${score}:${alias_name}")
    done

    if (( ${#candidates} > 0 )); then
        local -a sorted=(${(On)candidates})
        local entry
        for entry in "${sorted[@]}"; do
            _ap_all_items+=("${entry#*:}")
        done
    fi

    _ap_update_window
}

# Derive the visible window (_ap_items) from _ap_all_items based on _ap_offset.
function _ap_update_window() {
    _ap_items=()
    local -i total=${#_ap_all_items}
    (( total == 0 )) && return

    # Clamp offset to valid range
    local -i window_size=$ALIAS_PREVIEW_MAX
    (( window_size > total )) && window_size=total
    (( _ap_offset > total - window_size )) && _ap_offset=$(( total - window_size ))
    (( _ap_offset < 0 )) && _ap_offset=0

    local -i i
    for (( i=_ap_offset+1; i<=_ap_offset+window_size; i++ )); do
        _ap_items+=("${_ap_all_items[i]}")
    done
}

# Render the numbered menu (with a ➤ on the engaged selection) via zle -M.
function _ap_render_msg() {
    local msg=""
    local -i total=${#_ap_all_items}
    if (( total > 0 )); then
        local -a lines=()
        local -i i
        local marker aname expanded
        for (( i=1; i<=${#_ap_items}; i++ )); do
            aname="${_ap_items[i]}"
            expanded="${aliases[$aname]}"
            if (( ${#expanded} > 80 )); then
                expanded="${expanded[1,77]}..."
            fi
            # _ap_sel is absolute; visible cursor position is _ap_sel - _ap_offset
            if (( i == _ap_sel - _ap_offset )); then
                marker="➤"
            else
                marker=" "
            fi
            lines+=(" ${marker} ${i}. ${aname}: ${expanded}")
        done
        # Show scroll indicator when there are more items than the window size
        if (( total > ALIAS_PREVIEW_MAX )); then
            lines+=("    [${_ap_offset+1}-${_ap_offset+${#_ap_items}}/${total}] ↕ scroll")
        fi
        msg="${(F)lines}"
    fi

    if [[ "$msg" != "$_alias_preview_last" ]]; then
        _alias_preview_last="$msg"
        zle -M "$msg"
    fi
}

# Insert the chosen alias into the buffer (replacing the first word), keep the rest.
function _ap_accept() {
    local -i idx=$1   # absolute index into _ap_all_items
    local aname="${_ap_all_items[idx]}"
    [[ -z "$aname" ]] && return

    local trimmed="${BUFFER#"${BUFFER%%[! ]*}"}"
    local first_word="${trimmed%% *}"
    local rest="${trimmed#"$first_word"}"

    BUFFER="${aname}${rest}"
    CURSOR=${#aname}

    _ap_suppress_word="$aname"
    _ap_last_word="$aname"
    _ap_sel=0
    _ap_offset=0
    _ap_all_items=()
    _ap_items=()
    _alias_preview_last=""
    zle -M ""
}

# ---- Interactive widgets ----

function _ap_down() {
    _ap_compute_items
    local -i total=${#_ap_all_items}
    if (( total > 0 )); then
        if (( _ap_sel == 0 )); then
            _ap_sel=1
        elif (( _ap_sel >= total )); then
            # Wrap around to the top
            _ap_sel=1
            _ap_offset=0
        else
            (( _ap_sel++ ))
            # Scroll window down if selection moved below visible area
            if (( _ap_sel > _ap_offset + ALIAS_PREVIEW_MAX )); then
                (( _ap_offset++ ))
            fi
        fi
        _ap_update_window
        _ap_render_msg
    else
        local orig="${_ap_orig_down:-down-line-or-history}"
        [[ -z "$orig" || "$orig" == "undefined-key" ]] && orig="down-line-or-history"
        zle "$orig"
    fi
}

function _ap_up() {
    _ap_compute_items
    local -i total=${#_ap_all_items}
    if (( _ap_sel >= 1 && total > 0 )); then
        if (( _ap_sel <= 1 )); then
            # Wrap around to the bottom
            _ap_sel=$total
            local -i window_size=$ALIAS_PREVIEW_MAX
            (( window_size > total )) && window_size=total
            _ap_offset=$(( total - window_size ))
        else
            (( _ap_sel-- ))
            # Scroll window up if selection moved above visible area
            if (( _ap_sel <= _ap_offset )); then
                (( _ap_offset-- ))
            fi
        fi
        _ap_update_window
        _ap_render_msg
    else
        local orig="${_ap_orig_up:-up-line-or-history}"
        [[ -z "$orig" || "$orig" == "undefined-key" ]] && orig="up-line-or-history"
        zle "$orig"
    fi
}

function _ap_tab() {
    _ap_compute_items
    if (( _ap_sel >= 1 && _ap_sel <= ${#_ap_all_items} )); then
        _ap_accept "$_ap_sel"
    else
        local orig="${_ap_orig_tab:-expand-or-complete}"
        [[ -z "$orig" || "$orig" == "undefined-key" ]] && orig="expand-or-complete"
        zle "$orig"
    fi
}

function _ap_digit() {
    local d="$KEYS"
    _ap_compute_items
    local -i total=${#_ap_all_items}
    # Digit selects from the visible window (offset + digit = absolute index)
    local -i abs_idx=$(( _ap_offset + d ))
    if [[ "$d" == [1-5] ]] && (( abs_idx >= 1 && abs_idx <= total )); then
        _ap_accept "$abs_idx"
    else
        local orig="${_ap_orig_digit[$d]:-self-insert}"
        [[ -z "$orig" || "$orig" == "undefined-key" ]] && orig="self-insert"
        zle "$orig"
    fi
}

# ---- Hook: refresh the menu on every redraw ----
function _preview_alias_message() {
    case "$LASTWIDGET" in
        *complete*|list-choices|_complete_help)
            _alias_preview_last=""
            _ap_sel=0
            _ap_offset=0
            return
            ;;
    esac
    _ap_compute_items
    _ap_render_msg
}

# ---- Setup: remember original bindings, install widgets & keys ----
function _ap_bound_widget() {
    local out
    out="$(bindkey "$1" 2>/dev/null)"
    echo "${out##* }"
}

function _ap_save_originals() {
    local up="${terminfo[kcuu1]}" down="${terminfo[kcud1]}"
    [[ -n "$up" ]] && _ap_orig_up="$(_ap_bound_widget "$up")"
    [[ -n "$down" ]] && _ap_orig_down="$(_ap_bound_widget "$down")"
    _ap_orig_tab="$(_ap_bound_widget '^I')"
    local d
    for d in 1 2 3 4 5; do
        _ap_orig_digit[$d]="$(_ap_bound_widget "$d")"
    done
}

function _ap_bind_keys() {
    local up="${terminfo[kcuu1]}" down="${terminfo[kcud1]}"
    [[ -n "$up" ]] && bindkey "$up" _ap_up
    [[ -n "$down" ]] && bindkey "$down" _ap_down
    bindkey '^I' _ap_tab
    local d
    for d in 1 2 3 4 5; do
        bindkey "$d" _ap_digit
    done
}

zle -N _ap_up
zle -N _ap_down
zle -N _ap_tab
zle -N _ap_digit

# Save the original key bindings only once (so re-sourcing doesn't capture our own widgets).
if [[ -z "$_ap_originals_saved" ]]; then
    _ap_save_originals
    _ap_originals_saved=1
fi
_ap_bind_keys

add-zle-hook-widget line-pre-redraw _preview_alias_message
