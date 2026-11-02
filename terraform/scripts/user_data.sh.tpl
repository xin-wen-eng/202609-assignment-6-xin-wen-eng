#!/bin/bash
# CSYE 6225 - Assignment 6
# Provided complete - do not modify.
#
# This script is templated by Terraform (see compute.tf) and used for
# BOTH the api and worker instances, with different values for
# host_role. It requires no internet access: server.py uses only the
# Python standard library, and python3 ships pre-installed on the
# Ubuntu 22.04 AMI used by this assignment - this matters for the
# worker host specifically, since it has no route to the internet.

set -e

mkdir -p /opt/app
cat > /opt/app/server.py << 'PYEOF'
${app_server_py}
PYEOF

cat > /etc/systemd/system/app.service << EOF
[Unit]
Description=CSYE 6225 Assignment 6 Service
After=network.target

[Service]
Environment=HOST_ROLE=${host_role}
Environment=PORT=80
ExecStart=/usr/bin/python3 /opt/app/server.py
Restart=on-failure
User=root
WorkingDirectory=/opt/app

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app.service
systemctl start app.service
