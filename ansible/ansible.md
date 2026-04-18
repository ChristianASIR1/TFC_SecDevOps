# 🛠️ INFRAESTRUCTURA ANSIBLE - TFC SecDevOps v2

## CONFIGURACIÓN DE ENTORNO

### [cite_start]ansible.cfg [cite: 1]
[defaults]
host_key_checking = False
inventory = hosts.ini
private_key_file = ~/v2_secdevops/ssh_keys/ssh_tfc_v2

### hosts.ini
[wazuh]
wazuh-server ansible_host=10.0.0.10 ansible_user=walter

[podman]
podman-node ansible_host=10.0.0.20 ansible_user=walter

[redteam]
redteam-node ansible_host=192.168.122.84 ansible_user=walter

---

## PLAYBOOKS DE DESPLIEGUE

### despliegue_inicial.yml
---
- name: Preparación de Nodos SecDevOps
  hosts: wazuh, podman
  become: yes
  gather_facts: yes
  tasks:
    - name: Actualizar el sistema (Apt upgrade)
      ansible.builtin.apt:
        update_cache: yes
        upgrade: dist
        cache_valid_time: 3600
    - name: Instalar herramientas esenciales
      ansible.builtin.apt:
        name: [curl, gnupg, apt-transport-https, net-tools]
        state: present
    - name: Verificar estado de la memoria RAM
      ansible.builtin.shell: free -h
      register: ram_status
    - name: Mostrar RAM
      ansible.builtin.debug:
        var: ram_status.stdout_lines

### hardening_ssh.yml
---
- name: Hardening del servicio SSH (CIS Benchmark)
  hosts: all
  become: yes
  tasks:
    - name: Aplicar configuraciones seguras en sshd_config
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '(?i)^#?{{ item.key }}\b'
        line: '{{ item.key }} {{ item.value }}'
        state: present
        validate: /usr/sbin/sshd -t -f %s
      loop:
        - { key: 'UsePAM', value: 'yes' }
        - { key: 'PermitUserEnvironment', value: 'no' }
        - { key: 'PermitEmptyPasswords', value: 'no' }
        - { key: 'MaxSessions', value: '2' }
        - { key: 'LogLevel', value: 'INFO' }
        - { key: 'IgnoreRhosts', value: 'yes' }
        - { key: 'HostbasedAuthentication', value: 'no' }
        - { key: 'GSSAPIAuthentication', value: 'no' }
        - { key: 'MACs', value: '-hmac-md5,hmac-md5-96,hmac-ripemd160,umac-64@openssh.com,hmac-md5-etm@openssh.com,hmac-md5-96-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-64-etm@openssh.com,umac-128-etm@openssh.com' }
      notify: Reiniciar SSH
  handlers:
    - name: Reiniciar SSH
      ansible.builtin.systemd: { name: ssh, state: restarted }

### wazuh_server.yml
---
- name: Despliegue Maestro Wazuh Manager
  hosts: wazuh
  become: yes
  tasks:
    - name: Ejecutar instalador All-in-One
      ansible.builtin.shell: "bash /root/wazuh-install.sh -a"
      args: { chdir: /root, creates: /var/ossec/etc/ossec.conf }
    - name: Configurar receptor Syslog para OPNsense
      ansible.builtin.blockinfile:
        path: /var/ossec/etc/ossec.conf
        insertafter: '<ossec_config>'
        block: |
          <remote>
            <connection>syslog</connection>
            <port>514</port>
            <protocol>udp</protocol>
            <allowed-ips>10.0.0.254</allowed-ips>
          </remote>
      notify: Reiniciar Wazuh Manager
    - name: Desplegar reglas personalizadas (SQLi y Brute Force)
      copy:
        dest: /var/ossec/etc/rules/local_rules.xml
        content: |
          <group name="local,web_attacks,">
            <rule id="100021" level="3">
              <if_sid>31108, 31100</if_sid>
              <match>POST /login.php</match>
              <description>DVWA: Intento de autenticacion web detectado.</description>
            </rule>
            <rule id="100022" level="10" frequency="10" timeframe="60">
              <if_matched_sid>100021</if_matched_sid>
              <same_source_ip />
              <description>DVWA: Ataque de FUERZA BRUTA web detectado.</description>
            </rule>
            <rule id="100002" level="12">
              <if_sid>31100</if_sid>
              <regex type="pcre2">(?i)(%27|').*(or|and|union|select).*(=|\%3D)</regex>
              <description>¡Ataque SQLi detectado!</description>
            </rule>
          </group>
      notify: Reiniciar Wazuh Manager
  handlers:
    - name: Reiniciar Wazuh Manager
      ansible.builtin.systemd: { name: wazuh-manager, state: restarted }

### podman_wazuh.yml
---
- name: Despliegue Nodo Podman + Agente Wazuh
  hosts: podman
  become: yes
  tasks:
    - name: Instalar Podman
      ansible.builtin.apt: { name: [podman, gnupg2, curl], state: latest }
    - name: Vincular Agente al Manager (10.0.0.10)
      ansible.builtin.lineinfile:
        path: /var/ossec/etc/ossec.conf
        regexp: '<address>MANAGER_IP</address>'
        line: "      <address>10.0.0.10</address>"
    - name: Crear Quadlet DVWA
      ansible.builtin.copy:
        dest: /etc/containers/systemd/dvwa.container
        content: |
          [Unit]
          Description=Contenedor DVWA vulnerable
          [Container]
          Image=docker.io/vulnerables/web-dvwa:latest
          PublishPort=8080:80
          Volume=/var/log/dvwa:/var/log/apache2
          [Install]
          WantedBy=multi-user.target
    - name: Monitorización de la DVWA en ossec.conf
      ansible.builtin.blockinfile:
        path: /var/ossec/etc/ossec.conf
        insertbefore: "</ossec_config>"
        block: |
          <localfile>
            <log_format>apache</log_format>
            <location>/var/log/dvwa/access.log</location>
          </localfile>

### instalar_waf.yml
---
- name: Despliegue de WAF perimetral
  hosts: podman
  become: yes
  tasks:
    - name: Crear Quadlet para el WAF
      ansible.builtin.copy:
        dest: /etc/containers/systemd/waf.container
        content: |
          [Unit]
          Description=Contenedor WAF (Nginx + ModSecurity)
          After=dvwa.service
          [Container]
          Image=docker.io/owasp/modsecurity-crs:nginx
          PublishPort=80:8080
          Environment=BACKEND=http://10.0.0.20:8080
          Volume=/var/log/waf:/var/log/nginx:Z
    - name: Monitorización del WAF en ossec.conf
      ansible.builtin.blockinfile:
        path: /var/ossec/etc/ossec.conf
        insertbefore: "</ossec_config>"
        block: |
          <localfile>
            <log_format>apache</log_format>
            <location>/var/log/waf/error.log</location>
          </localfile>

### preparar_redteam.yml
---
- name: Preparar entorno de ataque Red Team
  hosts: redteam
  become: yes
  tasks:
    - name: Instalar arsenal
      ansible.builtin.apt:
        name: [nmap, sqlmap, ffuf, nikto, hydra, tmux, git]
        state: present
    - name: Optimizar File Descriptors
      ansible.builtin.blockinfile:
        path: /etc/security/limits.conf
        block: |
          * soft nofile 65535
          * hard nofile 65535

---

## [cite_start]CREDENCIALES WAZUH [cite: 2, 3, 4]

- [cite_start]**Indexer/Dashboard Admin**: `admin` / `0eS9fC?KHMiw9RPA6GD*8mtuCs36N58i` [cite: 3]
- **Anomaly Detection**: `anomalyadmin` / `vE.CiN2u8R*fC+C1RvQ.yl+8wHeQzY+q` [cite: 3]
- [cite_start]**Wazuh API**: `wazuh` / `ClXyw8u2y?ezIU*?Xk.vllLGCPm?zDW*` [cite: 3]
- [cite_start]**Wazuh-WUI API**: `wazuh-wui` / `3S1?lmE4UD3XTlNGwRMXx6qrc9syU3Bj` [cite: 3]
