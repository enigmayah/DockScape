# DockScape
Container Security - with Docker and Falco and webhook

# DockScape: Container Escape Detection Lab
A Docker-based lab that simulates a controlled container escape and uses **Falco** for runtime security detection.  
When Falco detects a suspicious system call (like reading `/host/etc/passwd`), it triggers a webhook that pauses the offending container automatically.

## Project Overview
This lab environment helps you understand how container breakouts can occur and how runtime security tools like Falco can detect and respond to them.

## Key Components:
-  Victim container — simulates an attack scenario
-  Falco — detects suspicious activity using custom rules
-  Webhook — pauses or reports containers on detection

## Run the lab
```bash
# Clone your repo
git clone https://github.com/mani1710/DockScape.git
cd DockScape

## For exexution of your scripts
chmod +x falco/forwarder.sh

# To Start the lab
docker compose up -d

# To view Falco alerts:
docker logs -f falco


