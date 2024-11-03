#!/usr/bin/env bash

# Verificar si se proporcionó la URL del repositorio
if [ -z "$1" ]; then
  echo "Uso: $0 <URL del repositorio>"
  exit 1
fi

# Asignar el primer argumento a una variable
REPO_URL="$1"

echo "Instalando estructura básica para virtualhost y proxy reverso con Docker"

# Habilitando la memoria de intercambio.
sudo dd if=/dev/zero of=/swapfile count=2048 bs=1MiB
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo cp /etc/fstab /etc/fstab.bak
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Instalando los software necesarios para probar el concepto.
sudo apt update && sudo apt -y install zip unzip nmap apache2 certbot tree git

sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
curl -SL https://github.com/docker/compose/releases/download/v2.30.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose

# Subiendo el servicio de Apache.
sudo service apache2 start

# Clonando el repositorio de configuraciones (asegúrate de que tienes configuraciones de ejemplo)
git clone https://github.com/NightmareVCO/virtualhost-reverseproxy.git

# Copiando los archivos de configuración en la ruta indicada.
sudo cp ~/virtualhost-reverseproxy/config/virtualhost-reverseproxy.conf /etc/apache2/sites-available/

# Ingresando el nombre del servidor y el correo de manera dinámica
cd /etc/apache2/sites-available/
read -p "Ingrese el nombre del host: " server_name
read -p "Ingrese su correo: " correo

# Configuración para SSL
sudo sed -i "s/ServerName CAMBIAR/ServerName $server_name/g" virtualhost-reverseproxy.conf
sudo sed -i "s/Redirect 301 \/ https:\/\/CAMBIAR\//Redirect 301 \/ https:\/\/$server_name\//g" virtualhost-reverseproxy.conf
sudo sed -i "s/SSLCertificateFile \/etc\/letsencrypt\/live\/CAMBIAR\/cert.pem/SSLCertificateFile \/etc\/letsencrypt\/live\/$server_name\/cert.pem/g" virtualhost-reverseproxy.conf
sudo sed -i "s/SSLCertificateKeyFile \/etc\/letsencrypt\/live\/CAMBIAR\/privkey.pem/SSLCertificateKeyFile \/etc\/letsencrypt\/live\/$server_name\/privkey.pem/g" virtualhost-reverseproxy.conf

# Configuración de Apache para habilitar módulos
sudo a2enmod proxy proxy_html proxy_http ssl
sudo systemctl restart apache2 

# Configuración de Certbot para SSL
echo "Configurando Certbot para obtener certificados SSL"
sudo certbot certonly -m "$correo" -d "$server_name"

# Reiniciar Apache
sudo systemctl restart apache2

# Iniciar Docker
sudo systemctl start docker

# Clonar el repositorio
cd ~
sudo git clone "$REPO_URL" repo
cd repo

# Si es necesario, personalizar la configuración o permisos del archivo docker-compose
sudo chmod +x ./docker-compose.yml

# Ejecutar docker-compose
sudo docker compose up --build -d

echo "La configuración de VirtualHost y Proxy Reverso con Docker en un solo servidor está completa."