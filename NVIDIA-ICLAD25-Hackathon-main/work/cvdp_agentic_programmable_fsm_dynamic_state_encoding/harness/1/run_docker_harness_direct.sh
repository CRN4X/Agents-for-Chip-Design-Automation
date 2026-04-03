#!/bin/bash

# Auto-generated script to run harness Docker container
# Usage: run_docker_harness_direct.sh [-d] (where -d enables debug mode with bash entrypoint)
set -e

# Parse command line arguments
DEBUG_MODE=false
while getopts 'd' flag; do
  case "${flag}" in
    d) DEBUG_MODE=true ;;
  esac
done

# Use shared bridge network: cvdp-bridge-hackathon_agentic_easy_example-4f752983
NETWORK_CREATED=0

# Check if network exists, create if needed
if ! docker network inspect cvdp-bridge-hackathon_agentic_easy_example-4f752983 &>/dev/null; then
  echo "Creating Docker network cvdp-bridge-hackathon_agentic_easy_example-4f752983..."
  docker network create --driver bridge cvdp-bridge-hackathon_agentic_easy_example-4f752983
  NETWORK_CREATED=1
fi

# Function to clean up resources
cleanup() {
  echo "Cleaning up Docker resources..."
  docker compose -f /home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/docker-compose.yml -p cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_1750370950 kill direct 2>/dev/null || true
  docker rmi cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_1750370950-direct 2>/dev/null || true
  if [ $NETWORK_CREATED -eq 1 ]; then
    echo "Removing Docker network cvdp-bridge-hackathon_agentic_easy_example-4f752983..."
    docker network rm cvdp-bridge-hackathon_agentic_easy_example-4f752983 2>/dev/null || true
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Run the harness container
echo "Running harness with project name: cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_1750370950"
# Get current user and group IDs
USER_ID=$(id -u)
GROUP_ID=$(id -g)

if [ "$DEBUG_MODE" = true ]; then
  echo "DEBUG MODE: Starting container with bash entrypoint"
  docker compose -f /home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/docker-compose.yml -p cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_1750370950 run --rm --user $USER_ID:$GROUP_ID -e HOME=/code/rundir --entrypoint bash -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/docs:/code/docs" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/rundir:/code/rundir" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/rtl:/code/rtl" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/verif:/code/verif" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/src:/code/src" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/src/llm_lib:/pysubj" --rm -w /code/rundir direct
else
  docker compose -f /home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/docker-compose.yml -p cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_1750370950 run --rm --user $USER_ID:$GROUP_ID -e HOME=/code/rundir -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/docs:/code/docs" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/rundir:/code/rundir" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/rtl:/code/rtl" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/verif:/code/verif" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/src:/code/src" -v "/home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/src/llm_lib:/pysubj" --rm -w /code/rundir direct
fi
exit_code=$?

# Exit with the same code as the docker command
exit $exit_code
