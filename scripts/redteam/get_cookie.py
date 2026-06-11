import requests
from bs4 import BeautifulSoup

# Configuración de URLs (IP de la WAN de OPNsense)
url_base = "http://192.168.122.144"
url_login = f"{url_base}/login.php"

def obtener_cookie():
    s = requests.Session()
    
    # 1. Obtener el Token CSRF inicial
    r_get = s.get(url_login)
    soup = BeautifulSoup(r_get.text, 'html.parser')
    try:
        token = soup.find('input', {'name': 'user_token'})['value']
    except TypeError:
        return "ERROR: No se pudo encontrar el token CSRF"

    # 2. Realizar el Login
    datos_login = {
        'username': 'admin',
        'password': 'password',
        'Login': 'Login',
        'user_token': token
    }
    r_post = s.post(url_login, data=datos_login)

    # Verificación de éxito 
    if "login.php" in r_post.url:
        return "ERROR: Login fallido (revisa credenciales)"

    # 3. Extraer y devolver la cookie formateada
    cookie_dict = s.cookies.get_dict()
    if 'PHPSESSID' in cookie_dict:
        # Devolvemos la cadena exacta
        return f"PHPSESSID={cookie_dict['PHPSESSID']}; security=low"
    
    return "ERROR: No se encontró la cookie PHPSESSID"

if __name__ == "__main__":
    # Imprimimos el resultado de la función "obtener_cookies()"
    resultado = obtener_cookie()
    print(resultado)
