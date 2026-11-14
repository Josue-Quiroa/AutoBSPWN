# Minimal p10k stub — run `p10k configure` after first login for full wizard.
# Instant prompt off for simplicity on first boot.
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time time)
typeset -g POWERLEVEL9K_MODE=nerdfont-complete
