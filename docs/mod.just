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

[doc('Validate docs/context/ against the repo — generated sections and named identifiers')]
[no-exit-message]
[script]
test:
    just check-tools python3
    # Run both gates before failing — they need different fixes, so reporting
    # only the first would hide the second until the next run.
    rc=0
    python3 "{{ scripts_dir }}/generate.py" --check || rc=1
    python3 "{{ scripts_dir }}/verify.py" || rc=1
    exit "$rc"
