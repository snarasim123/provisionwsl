#!/usr/bin/env bash

cd ~/code/provisionwsl
ansible-playbook -i hosts ./playbook-gui.yaml
