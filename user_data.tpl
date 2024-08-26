#!/bin/bash
apt-get update
apt-get install -y docker.io
systemctl start docker
systemctl enable docker

# Create a Docker network
docker network create nexus-network

# Run Nexus Repository Manager on the custom Docker network
docker run -d --network nexus-network -p 8081:8081 --name nexus sonatype/nexus3

# Run Nexus IQ Server on the custom Docker network
docker run -d --network nexus-network -p 8070:8070 --name nexus-iq sonatype/nexus-iq-server