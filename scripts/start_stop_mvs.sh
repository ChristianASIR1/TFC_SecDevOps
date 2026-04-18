#!/bin/bash


if [ "$1" == "start" ];then
  echo "Levantando MVs de KVM"
  for vm in $(virsh list --inactive --name); 
    do virsh start $vm; done
  echo "¡Todas las máquinas están en marcha!"

# Comprobación y apertura de tunel SSH #
  while ! nmap -p 22 192.168.122.84 | grep -q "22/tcp open"; do
    echo "Red-Team (192.168.122.84) iniciando servicios... reintentando"
    sleep 2
  done
  echo "¡SSH detectado! Levantando Túnel..."
  ssh -D 9050 -N -f -i ~/v2_secdevops/ssh_keys/ssh_tfc_v2 walter@192.168.122.84
  echo "¡Túnel SSH levantado, utilizar FoxyProxy!"

elif [ "$1" == "stop" ];then
  echo "Parando Mvs de KVM"
  for vm in $(virsh list --state-running --name);
    do virsh shutdown $vm;done
  echo "¡Todas las máquinas están paradas!"

  echo "Cerrando Tunel SSH del puerto 9050 utilizado"
  pkill -f "ssh -D 9050"
  echo "Tunel SSH cerrado"

elif [ "$1" == "estado" ];then
  echo "Estado actual de las MVs de KVM"
  virsh list --all

  if ss -tuln | grep -q ":9050";then
    echo "[ACTIVO] El tunel SSH a Red-Team está activo"
  else 
    echo "[INACTIVO] El tunel SSH no está funcionando"
  fi

else
  echo "Usa:  start, stop o estado"
fi

