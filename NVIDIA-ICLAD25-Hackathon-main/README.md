# NVIDIA Debug Problem Set
The problem set is designed to evaluate agents, with support for tool interaction, iterative workflows, and complex reasoning 
for hardware design task.

Directory structure:

-examples: example dummy agent

-work: a datapoint example of the docker env

# Quick Start

## Installation

### Prerequisites

**Python 3.12 is recommended** for optimal compatibility.

**Docker CE (Community Edition)** with a recent version is required for running test harnesses and agents:
- Install Docker CE from [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)
- **Add your user to the docker group** to run Docker without sudo permissions:
  ```bash
  # Add current user to docker group
  sudo usermod -aG docker $USER
  
  # Log out and back in, or restart your session
  # Verify Docker works without sudo:
  docker --version
  ```

### Setup Instructions

1. **Create a virtual environment** (recommended):
```bash
# Create virtual environment
python -m venv agent_env

# Activate virtual environment
# On Linux/macOS:
source agent_env/bin/activate
# On Windows:
agent_env\Scripts\activate
```

2. **Install Python dependencies**:
```bash
pip install -r requirements.txt
```

## Agentic flow setup

### Dummy agent example
**1. Copy the agent example and build:**
```bash
# Copy the complete agent example
cp -r examples/agent/ ./my-agent/
cd my-agent/

# Build using the provided script
./build_agent.sh
```
**2. Run the agent on batch mode:**
```bash
python run_benchmark.py -f ./dataset/hackathon-agentic-obfuscated_final_corrected.jsonl -l -g example-agent
# check the total benchmark pass/fail status
python run_reporter.py work/report.json | less
# check the run and each problem
cd work
```

**3. Run the agent on one example:**
```bash
cd work/cvdp_agentic_programmable_fsm_dynamic_state_encoding/harness/1/
# invoke the agent run
./run_docker_agent.sh
# debug the agent
./run_docker_agent.sh -d
# run evaluation
./run_docker_harness_direct.sh
```

### Start your own agent
Add your code into ./my-agent/ and build the agent docker image.
