# 📈 PROGRESO DEL PROYECTO TFC: SecDevOps IaC

## 1. Infraestructura y Despliegue (Estado: COMPLETADO)
La base de la infraestructura se ha desplegado con éxito mediante Terraform y Ansible en múltiples iteraciones.

* **Host Machine**: Intel Ultra 5 225H con 32GB RAM.
* **Networking**: LAN privada 10.0.0.0/24 con gateway en OPNsense (10.0.0.254).
* **Virtualización (Recursos asignados en main.tf)**:
    * **Wazuh Server**: 6GB RAM (6144MB), 2 vCPU, disco de 50GB.
    * **Podman Node**: 4GB RAM (4096MB), 2 vCPU.
    * **RedTeam Node**: 4GB RAM (4096MB), 2 vCPU.
    * **OPNsense Firewall**: 2GB RAM (2048MB), 2 vCPU.

## 2. Configuración de Servicios (Estado: OPERATIVO)
* **Contenedores**: Motor Podman desplegado en el nodo víctima.
* **Wazuh Manager**: Instalación All-in-One finalizada y receptores de Syslog activos para OPNsense.
* **Hardening**: Aplicado CIS Benchmark en SSH en todos los nodos.
* **Capa de Aplicación**: Desplegados mediante Quadlets de Podman:
    * **DVWA**: Aplicación vulnerable para pruebas de ataque.
    * **WAF**: Proxy inverso Nginx con ModSecurity (CRS) protegiendo la DVWA.

## 3. Fase Actual: Seguridad Activa y Respuesta
Actualmente, el proyecto se encuentra en la etapa de ataque y monitorización:
* **Ataque**: Ejecución de herramientas desde el nodo RedTeam (Nmap, SQLmap, Hydra) para generar logs.
* **Detección**: Creación de reglas personalizadas en Wazuh (local_rules.xml) para detectar Fuerza bruta (ID 100022) e inyecciones SQL (ID 100002).
* **Respuesta Activa**: Configuración de firewall-drop en el Manager para bloquear IPs tras ataques de fuerza bruta.

## 4. Próximos Objetivos
* Validar la persistencia de los logs del WAF hacia el agente Wazuh.
* Ajustar el timeout de la respuesta activa.
* Documentar las trazas de ataque en el Dashboard de Wazuh.
