# 🛡️ TFC SecDevOps: Laboratorio de Seguridad y Automatización

![Terraform](https://img.shields.io/badge/Terraform-1.x-623CE4.svg?logo=terraform)
![Ansible](https://img.shields.io/badge/Ansible-Core-EE0000.svg?logo=ansible)
![Wazuh](https://img.shields.io/badge/Wazuh-4.x-0078D4.svg?logo=wazuh)
![Podman](https://img.shields.io/badge/Podman-Engine-892CA0.svg?logo=podman)

## 📌 Descripción del Proyecto
Este repositorio contiene la Infraestructura como Código (IaC) y los flujos de configuración automatizada para el despliegue de un entorno **SecDevOps** completo. Diseñado como Proyecto de Fin de Ciclo (TFC), el laboratorio simula un entorno empresarial segmentado, monitorizado y sometido a pruebas de penetración continuas (Red Team vs Blue Team).

Todo el aprovisionamiento de recursos (KVM/Libvirt) y la configuración del software operativo se realiza de forma **100% desatendida**.

## 🏗️ Topología de Red y Arquitectura

El entorno está segmentado mediante un firewall perimetral (OPNsense) que separa el tráfico hostil de la red interna de monitorización.

* **Red Externa (WAN / Red Team):** `192.168.122.0/24`
  * `192.168.122.x` - **Nodo Red Team**: Arsenal de pentesting (Nmap, SQLmap, FFuF). Emula a un atacante externo.
  * `192.168.122.28` - **OPNsense (WAN)**: Interfaz pública del firewall.

* **Red Interna (LAN / Blue Team):** `10.0.0.0/24`
  * `10.0.0.254` - **OPNsense (LAN)**: Puerta de enlace y enrutamiento interno.
  * `10.0.0.10` - **Wazuh Manager**: Cerebro del Blue Team (SIEM/XDR). Recolecta logs y ejecuta respuestas activas (ej. `firewall-drop`).
  * `10.0.0.20` - **Nodo Podman (Víctima)**: Aloja contenedores mediante Quadlets. Contiene una aplicación web vulnerable (DVWA) protegida perimetralmente por un WAF (Nginx + ModSecurity).

## 🚀 Despliegue Automatizado (Quickstart)

El proyecto cuenta con un script que fusiona las fases de provisión (Terraform) y configuración (Ansible), resolviendo las condiciones de carrera y validando la disponibilidad de los puertos antes de inyectar configuraciones.

### Prerrequisitos
* Host Linux con KVM/Libvirt activo.
* Terraform y Ansible instalados.
* Clave pública SSH configurada para la inyección vía `cloud-init`.

### Ejecución
Basta con ejecutar el script principal de despliegue:

```bash
git clone git@github.com:ChristianASIR1/TFC_SecDevOps.git
cd TFC_SecDevOps
./scripts/despliegue.sh
