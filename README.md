# artix-install

My personal artix install helper scripts. Starting point for a fresh artix install.
Serves as a low tech provisioning, since I did not want to rely on libraries like ansible or
similar, since this would be overkill and not future proof.

Taken and simplified from: https://larbs.xyz/ (https://github.com/lukesmithxyz/larbs)

## Usage

- Boot from an artix ISO
- Follow the steps in the pseudo shell script: curl -o https://github.com/dassi/artix-install/raw/main/artix_install_linux.sh
- After booting into the basic artix linux, get the other two scripts
  - curl -o https://github.com/dassi/artix-install/raw/main/artix_install_desktop.sh
  - curl -o https://github.com/dassi/artix-install/raw/main/artix_progs.csv
- Run the script as root: ./artix_install_desktop.sh
