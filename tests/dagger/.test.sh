set -e

wait_for_processes

dagger -c ".echo hello" | grep hello
echo "dagger query works" >&2
