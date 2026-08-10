set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

scripts_dir := justfile_dir() + '/docs/scripts'

[private]
[script]
default:
    just -l docs

[doc('Render the generated sections of docs/context/ from the repo')]
[script]
generate:
    just check-tools python3
    python3 "{{ scripts_dir }}/generate.py"

[doc('Fail if any generated docs section is stale')]
[no-exit-message]
[script]
check:
    just check-tools python3
    python3 "{{ scripts_dir }}/generate.py" --check
