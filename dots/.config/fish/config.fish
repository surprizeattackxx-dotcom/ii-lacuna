if status is-interactive
    fastfetch --logo-type file-raw --logo (pokemon-colorscripts -r --no-title | psub)
end

# opencode
fish_add_path /home/donnie/.opencode/bin
fish_add_path /home/donnie/.local/bin
function fish_greeting; end

abbr -a cachy-update 'cachy-update --devel'
abbr -a arch-update 'arch-update --devel'
