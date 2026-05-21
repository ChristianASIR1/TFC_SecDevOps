#!/bin/bash

# ==========================================================
# Script de Despliegue Automatizado SecDevOps - TFC
# ==========================================================

# Variables #
DIR_PROYECTO="/home/walter/v2_secdevops"
LLAVE_SSH="$DIR_PROYECTO/ssh_keys/ssh_tfc_v2"
IP_REDTEAM=$(terraform -chdir="$DIR_PROYECTO/terraform" output -raw redteam_ip 2>/dev/null)
#IP_REDTEAM=$(cat /home/walter/v2_secdevops/ansible/hosts.ini | grep redteam | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")


# Parar la ejecución si falla algun comando:
set -e


# Limpieza de claves Known_hosts SSH #

echo "Limpiando claves SSH antiguas de ejecuciones previas..."
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "10.0.0.10" >/dev/null 2>&1 || true
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "10.0.0.20" >/dev/null 2>&1 || true
 
if [ -n "$IP_REDTEAM" ]; then
    ssh-keygen -f '/home/walter/.ssh/known_hosts' -R "$IP_REDTEAM" >/dev/null 2>&1 || true
fi



# Comprobación claves SSH #

if [ ! -f "$LLAVE_SSH" ]; then
    echo "[ERROR] Clave SSH no encontrada en $LLAVE_SSH"
    echo "Por favor, crea el par de claves antes de lanzar el despliegue:"
    echo "ssh-keygen -t ed25519 -f $LLAVE_SSH"
    echo "Y asegúrate de pegar el contenido de .pub en terraform/cloud_init.cfg"
    exit 1
else
    echo "Clave SSH detectada"
fi


# Terraform: #
echo  "Levantando infraestructura con Terraform..."
cd "$DIR_PROYECTO/terraform"
terraform init
terraform apply -auto-approve
cd ..

IP_REDTEAM=$(terraform -chdir="$DIR_PROYECTO/terraform" output -raw redteam_ip 2>/dev/null)

echo "Esperando inicialización del SO y SSH (Cloud-init)"
sleep 45

for ip in "10.0.0.10" "10.0.0.20" "$IP_REDTEAM"; do
    echo "Comprobando conexión SSH en $ip..."
    while ! nc -z -w5 $ip 22; do
        sleep 5
    done
    echo " SSH operativo en $ip."
done


# Ansible #

export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_SSH_COMMON_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "Ejecutando 1/5: Despliegue inicial..."
ansible-playbook -i ansible/hosts.ini ansible/playbooks/despliegue_inicial.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 2/5: Instalación Wazuh Manager"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/wazuh_server.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 3/5: Despliegue Podman, DVWA, WAF y Wazuh Agent"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/podman-node.yml --private-key "$LLAVE_SSH"
chmod 600 /home/walter/v2_secdevops/credenciales_wazuh.txt

echo "Ejecutando 4/5: Hardening SSH"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/hardening_ssh.yml --private-key "$LLAVE_SSH"

echo "Ejecutando 5/5: Preparación herramientas Red Team"
ansible-playbook -i ansible/hosts.ini ansible/playbooks/preparar_redteam.yml --private-key "$LLAVE_SSH"




echo "[EXITO]  Infraestructura SecDevOps desplegada"
echo " Manager Wazuh: https://10.0.0.10"
echo " Aplicación DVWA: http://10.0.0.20:8080"
echo "MV Red-Team:  ${IP_REDTEAM:-IP_No_Encontrada}"
echo " Contraseñas guardadas en: $DIR_PROYECTO/credenciales_wazuh.txt"
