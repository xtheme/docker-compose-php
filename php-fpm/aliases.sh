alias ll='ls -l'
alias ls='ls -F --color=auto --show-control-chars'

# Laravel Artisan 別名
alias pa="php artisan"
alias artisan="php artisan"
alias tinker="php artisan tinker"
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'

# MySQL 連接別名
alias mysql57="mysql -h mysql -P 3306 -u root -p"
alias mysql80="mysql -h mysql8 -P 3306 -u root -p"

alias cdagent="cd /var/www/API_Agent/_release"
alias cdcronjob="cd /var/www/RD-Studio-01/_release"
alias cdexternal="cd /var/www/API_External/_release"
alias cdfront="cd /var/www/API_Frontend/_release"
alias cdinternal="cd /var/www/api-internal/_release"
alias cdsocket="cd /var/www/WEB_CustomerServiceSocket/_release"

# Git 分支顯示（detached HEAD 時 fallback 顯示 short SHA）
parse_git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || branch=$(git rev-parse --short HEAD 2>/dev/null)
    [ -n "$branch" ] && echo " ($branch)"
}

# Prompt：依 Shell 種類設定正確語法
if [ -n "$ZSH_VERSION" ]; then
    # Zsh 語法
    setopt PROMPT_SUBST
    PROMPT='[php-fpm] %F{green}%n@%m%f:%F{blue}%~%f%F{yellow}$(parse_git_branch)%f%# '
else
    # Bash 語法（單引號讓 $(parse_git_branch) 每次顯示 prompt 時才求值）
    export PS1='[php-fpm] \[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\[\e[33m\]$(parse_git_branch)\[\e[0m\]\$ '
fi
