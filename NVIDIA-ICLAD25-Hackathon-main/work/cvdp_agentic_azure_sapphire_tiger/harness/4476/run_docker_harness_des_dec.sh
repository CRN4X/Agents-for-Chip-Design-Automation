#!/bin/bash

# Auto-generated script to run harness Docker container
# Usage: run_docker_harness_des_dec.sh [-d] (where -d enables debug mode with bash entrypoint)
set -e

# Parse command line arguments
DEBUG_MODE=false
while getopts 'd' flag; do
  case "${flag}" in
    d) DEBUG_MODE=true ;;
  esac
done

# Use shared bridge network: cvdp-bridge-hackathon-agentic-obfuscated_final_corrected-cd545e1
NETWORK_CREATED=0

# Check if network exists, create if needed
if ! docker network inspect cvdp-bridge-hackathon-agentic-obfuscated_final_corrected-cd545e1 &>/dev/null; then
  echo "Creating Docker network cvdp-bridge-hackathon-agentic-obfuscated_final_corrected-cd545e1..."
  docker network create --driver bridge cvdp-bridge-hackathon-agentic-obfuscated_final_corrected-cd545e1
  NETWORK_CREATED=1
fi

# Function to clean up resources
cleanup() {
  echo "Cleaning up Docker resources..."
  docker compose -f /Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/docker-compose.yml -p cvdp_agentic_azure_sapphire_tiger_4476_1774587254 kill des_dec 2>/dev/null || true
  docker rmi cvdp_agentic_azure_sapphire_tiger_4476_1774587254-des_dec 2>/dev/null || true
  if [ $NETWORK_CREATED -eq 1 ]; then
    echo "Removing Docker network cvdp-bridge-hackathon-agentic-obfuscated_final_corrected-cd545e1..."
    docker network rm cvdp-bridge-hackathon-agentic-obfuscated_final_corrected-cd545e1 2>/dev/null || true
  fi
}

# Set up cleanup trap
trap cleanup EXIT

# Run the harness container
echo "Running harness with project name: cvdp_agentic_azure_sapphire_tiger_4476_1774587254"
# Get current user and group IDs
USER_ID=$(id -u)
GROUP_ID=$(id -g)

if [ "$DEBUG_MODE" = true ]; then
  echo "DEBUG MODE: Starting container with bash entrypoint"
  docker compose -f /Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/docker-compose.yml -p cvdp_agentic_azure_sapphire_tiger_4476_1774587254 run --rm --user $USER_ID:$GROUP_ID -e HOME=/code/rundir --entrypoint bash -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/docs:/code/docs" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/rundir:/code/rundir" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/rtl:/code/rtl" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/verif:/code/verif" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/src:/code/src" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/src/llm_lib:/pysubj" --rm -w /code/rundir des_dec
else
  docker compose -f /Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/docker-compose.yml -p cvdp_agentic_azure_sapphire_tiger_4476_1774587254 run --rm --user $USER_ID:$GROUP_ID -e HOME=/code/rundir -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/docs:/code/docs" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/rundir:/code/rundir" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/rtl:/code/rtl" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/verif:/code/verif" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_azure_sapphire_tiger/harness/4476/src:/code/src" -v "/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/src/llm_lib:/pysubj" --rm -w /code/rundir des_dec
fi
exit_code=$?

# Exit with the same code as the docker command
exit $exit_code
