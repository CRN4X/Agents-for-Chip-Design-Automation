#!/bin/bash

# Auto-generated script to run agent Docker container
# Usage: run_docker_agent.sh [-d] (where -d enables debug mode with bash entrypoint)
# Using agent image: example-agent
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
  docker rmi agent_cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_$(date +%s)-agent 2>/dev/null || true
  if [ $NETWORK_CREATED -eq 1 ]; then
    echo "Removing Docker network cvdp-bridge-hackathon_agentic_easy_example-4f752983..."
    docker network rm cvdp-bridge-hackathon_agentic_easy_example-4f752983 2>/dev/null || true
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Run the agent container
echo "Running agent with project name: agent_cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_$(date +%s)"
# Get current user and group IDs
USER_ID=$(id -u)
GROUP_ID=$(id -g)

if [ "$DEBUG_MODE" = true ]; then
  echo "DEBUG MODE: Starting container with bash entrypoint"
  docker compose -f /home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/docker-compose-agent.yml -p agent_cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_$(date +%s) run --rm --user $USER_ID:$GROUP_ID --entrypoint bash agent
else
  docker compose -f /home/chiatungh/scratch/NVIDIA-ICLAD25-Hackathon/work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/docker-compose-agent.yml -p agent_cvdp_agentic_programmable_fsm_dynamic_state_encoding_1_$(date +%s) run --rm --user $USER_ID:$GROUP_ID agent
fi
exit_code=$?

# Exit with the same code as the docker command
exit $exit_code
