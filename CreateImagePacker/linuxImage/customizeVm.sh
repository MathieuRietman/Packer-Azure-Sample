# Add microsoft repo for installing blobfuse
    wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb

# All installation packages
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y blobfuse
    apt install -y python3-pip
    apt install -y python-pip
    apt install -y mc
    apt autoremove -y

# install miniconda https://martinralbrecht.wordpress.com/2020/08/23/conda-jupyter-and-emacs/
    curl https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | gpg --dearmor > conda.gpg
    install -o root -g root -m 644 conda.gpg /usr/share/keyrings/conda-archive-keyring.gpg
    gpg --keyring /usr/share/keyrings/conda-archive-keyring.gpg --no-default-keyring --fingerprint 34161F5BF5EB1D4BFBBB8F0A8AEB4F8B29D82806
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/conda-archive-keyring.gpg] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" > /etc/apt/sources.list.d/conda.list
    apt update
    apt install -y conda

# Set path variables
    echo 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/opt/conda/bin' > /etc/environment
 
