 #!/usr/bin/env bash
 set -euo pipefail
 devenv processes up --detach
 tail -f .devenv/processes.log &
 process-compose project is-ready
 devenv test
