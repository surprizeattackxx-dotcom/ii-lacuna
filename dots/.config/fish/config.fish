if status is-interactive
    fastfetch --logo-type file-raw --logo (pokemon-colorscripts -r --no-title | psub)
end

# opencode
fish_add_path $HOME/.opencode/bin
fish_add_path $HOME/.local/bin
function fish_greeting; end

abbr -a cachy-update 'cachy-update --devel'
abbr -a arch-update 'arch-update --devel'

function qwen35 --wraps=ollama
    OLLAMA_NUM_GPU_LAYERS=8 ollama run qwen3.5:35b $argv
end

# Added by LM Studio CLI (lms)
set -gx PATH $PATH $HOME/.lmstudio/bin
# End of LM Studio CLI section

set -x XCURSOR_THEME oreo_red_cursors
set -x XCURSOR_SIZE 24
