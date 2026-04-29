#!/bin/bash

# ==========================================================
# Script de Despliegue Automatizado SecDevOps - TFC
# ==========================================================

# El script se para si falla algun comando:
set -e

# Terraform: #
echo  "Levantando infraestructura con Terraform..."
cd "/home/walter/v2_secdevops/terraform"
terraform init
terraform apply -auto-approve
cd ..

echo "Esperando inicialización del SO y SSH (Cloud-init)"
sleep 45

for ip in "10.0.0.10" "10.0.0.20"; do
    echo "Comprobando conexión SSH en $ip..."
    while ! nc -z -w5 $ip 22; do
        sleep 5
    done
    echo " SSH operativo en $ip."
done


# Ansible #

export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_SSH_COMMON_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
LLAVE_SSH="/home/walter/v2_secdevops/ssh_keys/ssh_tfc_v2"
IP_REDTEAM=$(grep -A 1 "\[redteam\]" ansible/hosts.ini | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)


echo "Ejecutando 1/6: Despliegue inicial..."
ansible-playbook -i ansible/hosts.ini ansible/playbooks/despliegue_inicial.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 2/6: Hardening SSH"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/hardening_ssh.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 3/6: Instalación Wazuh Manager"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/wazuh_server.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 4/6: Despliegue Podman, DVWA y Wazuh Agent"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/podman_wazuh.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 5/6: Despliegue WAF"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/instalar_waf.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 6/6: Preparación herramientas Red Team"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/preparar_redteam.yml --private-key "$LLAVE_SSH"




echo "[EXITO]  Infraestructura SecDevOps desplegada"
echo " Manager Wazuh: https://10.0.0.10"
echo " Aplicación DVWA: http://10.0.0.20:8080"
echo "MV Red-Team:  ${IP_REDTEAM:-IP_No_Encontrada}"
echo " Contraseñas guardadas en: /home/walter/v2_secdevops/credenciales_wazuh.txt"
