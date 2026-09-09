#!/usr/bin/env bash
set -euo pipefail

sudo ufw --force reset

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw limit 22/tcp comment 'ssh'

sudo ufw --force enable

sudo ufw status verbose
