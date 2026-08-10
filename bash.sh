#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

eval "$(starship init bash)"
export PATH="$HOME/.local/bin:$PATH"

# Override Mamba's terminfo binaries with native system binaries
alias clear="/usr/bin/clear"

# Lazy-load Conda and Mamba to get rid of shell startup lag
lazy_conda_init() {
    unset -f conda
    unset -f mamba
    
    # Run the Conda init
    __conda_setup="$('/home/snes/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/home/snes/miniforge3/etc/profile.d/conda.sh" ]; then
            . "/home/snes/miniforge3/etc/profile.d/conda.sh"
        else
            export PATH="/home/snes/miniforge3/bin:$PATH"
        fi
    fi
    unset __conda_setup

    # Run the Mamba init
    export MAMBA_EXE='/home/snes/miniforge3/bin/mamba'
    export MAMBA_ROOT_PREFIX='/home/snes/miniforge3'
    __mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__mamba_setup"
    else
        alias mamba="$MAMBA_EXE"
    fi
    unset __mamba_setup
}

# Placeholder function that intercepts the first 'conda' command
conda() {
    lazy_conda_init
    conda "$@"
}

# Placeholder function that intercepts the first 'mamba' command
mamba() {
    lazy_conda_init
    mamba "$@"
}