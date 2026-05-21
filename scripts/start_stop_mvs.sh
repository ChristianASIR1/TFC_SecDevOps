#!/bin/bash

# ==================================================================================================
# SCRIPT: start_stop_mvs.sh
# DESCRIPCIÓN: Automatiza el arranque, parada y comprobación de estado de la
#              infraestructura virtual (KVM) y gestiona el túnel proxy SSH.
#
# PROYECTO: Despliegue automatizado de una infraestructura empresarial.
#           SecDevOps mediante IaC y monitorización de seguridad centralizada.
#
# AUTOR: Christian Pena Gómez
#
# USO (Configurado mediante alias de sistema):
#   mvs [opción]
#
# OPCIONES:
#   start  : Inicia todas las MVs inactivas y establece el túnel SSH proxy (Puerto 9050).
#   stop   : Envía señal de apagado seguro a las MVs activas y destruye el túnel SSH.
#   estado : Muestra el estado actual de las máquinas en libvirt y la conexión SSH.
# ============================================================================================

ssh_keys="$HOME/v2_secdevops/ssh_keys/ssh_tfc_v2"
ip_redteam="192.168.122.84"
sesiones_tilix="$HOME/Documentos/Tilix"

# ==============================================================================================================================================================
# COMPROBACIÓN DE DEPENDENCIAS
# ==============================================================================================================================================================

for cmd in virsh nc ssh tilix; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: El comando '$cmd' no está instalado o no está en el PATH."
    exit 1
  fi
done

# ==============================================================================================================================================================
# ARRANQUE DE LAS MVS Y DERIVADOS
# ==============================================================================================================================================================

if [ "$1" == "start" ];then
  echo "Levantando MVs de KVM"
  for vm in $(virsh list --inactive --name); 
    do virsh start "$vm"; done

  echo "¡Todas las máquinas están en marcha!"

# *** ==============================================================================================================================================================
# *** COMPROBACIÓN ESTADO PUERTO 22
# *** ==============================================================================================================================================================

  while ! nc -z -w 1 "$ip_redteam" 22 2>/dev/null; do
    echo "Comprobando puerto 22 en Red-Team ($ip_redteam). SSH no detectado ... reintentando"
    sleep 2
  done

  echo "¡SSH detectado! Levantando Túnel..."
  ssh -o ExitOnForwardFailure=yes -D 9050 -N -f -i "$ssh_keys" walter@"$ip_redteam"
  echo "¡Túnel SSH levantado, utilizar FoxyProxy en navegador Firefox!"


# ==============================================================================================================================================================
# PARADA DE LAS MVS
# ==============================================================================================================================================================


elif [ "$1" == "stop" ];then
  echo "Enviando señal de apagado a las mvs KVM..."
  for vm in $(virsh list --state-running --name);
    do virsh shutdown "$vm";done
  echo  "¡Señal enviada! Las máquinas se irán apagando en los próximos segundos."

  echo "Cerrando Tunel SSH del puerto 9050 utilizado"
  pkill -f "ssh -D 9050"
  echo "Tunel SSH cerrado"

# ==============================================================================================================================================================
# COMPROBACIÓN ESTADO INFRAESTRTUCTURA
# ==============================================================================================================================================================


elif [ "$1" == "estado" ];then
  echo  "Estado actual de las MVs de KVM"

  virsh list --all

  if ss -tuln | grep -q ":9050";then
    echo "[ACTIVO] El tunel SSH a Red-Team está activo"
  else
    echo "[INACTIVO] El tunel SSH no está funcionando"
  fi

# ==============================================================================================================================================================
# INTRUCCIONES USO INCORRECTO
# ==============================================================================================================================================================

else
  echo "Uso incorrecto. Ejecuta ->  mvs {start|stop|estado}"
fi

