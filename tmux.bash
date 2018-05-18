#!/bin/sh

/usr/bin/tmux set-option -g default-terminal "screen-256color"

# on ajoute le top en haut (sera 25% de la hauteur)
/usr/bin/tmux new-session -s `/bin/hostname` -n 'Mining' -d '/usr/bin/top -d1 -uth0ma7'

# en dessous en partie centrale on ajoute le log (sera 75% de la hauteur)
/usr/bin/tmux split-window -v -t 0 -p 75 -d 'tail -f /var/log/miners/ethminer.log'

# Ajout de l'etat du CPU a droite du top
/usr/bin/tmux split-window -h -t 0 -p 40 -d '/usr/bin/watch -d -t -n10 "sensors | awk ''/^acpitz-virtual-0/,/^temp1.*/''"'
# Ajout de la version du kernel en dessous de l'etat du CPU
/usr/bin/tmux split-window -v -t 1 -p 40 -d '/usr/bin/watch -t -n1000 "/bin/echo && /bin/echo ''kernel: '' && /bin/uname -r"'

# Divise le bas en 6 panaux egaux
/usr/bin/tmux split-window -v -t 3 -p 45 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/0/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
/usr/bin/tmux split-window -h -t 1 -p 17 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/5/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
/usr/bin/tmux split-window -h -t 2 -p 20 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/4/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
/usr/bin/tmux split-window -h -t 3 -p 25 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/3/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
/usr/bin/tmux split-window -h -t 4 -p 33 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
/usr/bin/tmux split-window -h -t 5 -p 50 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/1/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'

# Divise le bas en 5 panaux egaux (sera 45% de la hauteur)
#/usr/bin/tmux split-window -v -t 3 -p45 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/0/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
#/usr/bin/tmux split-window -h -t 1 -p 20 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/4/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
#/usr/bin/tmux split-window -h -t 2 -p 25 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/3/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
#/usr/bin/tmux split-window -h -t 3 -p 33 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
#/usr/bin/tmux split-window -h -t 4 -p 50 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/1/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'

# Selectionner un panneau specifique de la fenetre active
/usr/bin/tmux select-pane -t `hostname`:Mining.9

# Divise le bas en 3 panaux egaux (sera 45% de la hauteur)
#/usr/bin/tmux split-window -v -t 3 -p45 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/0/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
#/usr/bin/tmux split-window -h -t 1 -p 33 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/2/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'
#/usr/bin/tmux split-window -h -t 2 -p 50 -d '/usr/bin/sudo /usr/bin/watch -t -n1 "cat /sys/kernel/debug/dri/1/amdgpu_pm_info | awk ''/^GFX.Clocks/,/^GPU.Load.*/''"'

# Divise le bas en 4 panaux egaux
#tmux split-window -v -t 2 -d '/usr/bin/watch -d -t -n1 sensors'
#tmux split-window -h -t 3 -p 50 -d '/usr/bin/watch -d -t -n1 sensors'
#tmux split-window -h -t 3 -p 50 -d '/usr/bin/watch -d -t -n1 sensors'
#tmux split-window -h -t 5 -p 50 -d '/usr/bin/watch -d -t -n1 sensors'

#     split-window [-bdfhvP] [-c start-directory] [-l size | -p percentage] [-t target-pane] [shell-command] [-F format]
#                   (alias: splitw)
#             Create a new pane by splitting target-pane: -h does a horizontal split and -v a vertical split; if neither is specified, -v is assumed.  The -l and
#             -p options specify the size of the new pane in lines (for vertical split) or in cells (for horizontal split), or as a percentage, respectively.  The
#             -b option causes the new pane to be created to the left of or above target-pane.  The -f option creates a new pane spanning the full window height
#             (with -h) or full window width (with -v), instead of splitting the active pane.  All other options have the same meaning as for the new-window com‐
#             mand.

# send 'tail -f foo<enter>' to the first pane.
# I adress the first pane using the -t flag. This is not necessary,
# I'm doing it so explicitly to show you how to do it.
# for the <enter> key, we can use either C-m (linefeed) or C-j (newline)
#tmux send-keys -t `hostname`:Mining.0 'tail -f foo' C-j

# Selectionner une fenetre specifique
# (on en a qu'une en ce moment donc implicite)
#tmux select-window -t `hostname`:Mining

# https://leanpub.com/the-tao-of-tmux/read#status-bar
/usr/bin/tmux set-option -g status-bg black
/usr/bin/tmux set-option -g status-fg white
/usr/bin/tmux set-option -g window-status-current-bg white
/usr/bin/tmux set-option -g window-status-current-fg black
/usr/bin/tmux set-option -g window-status-current-attr bold
#tmux status-interval 60
/usr/bin/tmux set-option -g status-left-length 30
/usr/bin/tmux set-option -g status-left '#[fg=green](#S) #(whoami) '
/usr/bin/tmux set-option -g status-right '#[fg=yellow]#(cut -d " " -f 1-3 /proc/loadavg)#[default] #[fg=white]%H:%M:%S#[default]'
#
# set inactive/active window styles
/usr/bin/tmux set-option -g window-style 'fg=colour247,bg=colour236'
/usr/bin/tmux set-option -g window-active-style 'fg=colour250,bg=black'
 
# pane border
/usr/bin/tmux set-option -g pane-border-bg colour235
/usr/bin/tmux set-option -g pane-border-fg green
/usr/bin/tmux set-option -g pane-active-border-bg colour236
/usr/bin/tmux set-option -g pane-active-border-fg green

# Finalement attacher la session active
/usr/bin/tmux attach -t `hostname`
