# sever_install.sh for production servers
To install Run below command
```
wget https://raw.githubusercontent.com/mohamedhagag/OdooInstaller/master/server_install.sh && bash server_install.sh
```

- Works & tested with ubuntu, debian and RHEL8+

- Will ask you for version (latest per default); project name (ov is default); domain name (example.com default)

- Can be used to install muliple versions for multi-project

- will configure nginx per project using best practice

- if domain configured will set domain in nginx config file

- each project will have its own system / postgres user and odoo instance


# odoo_install.sh For Developers
To install Run below command
```
wget https://raw.githubusercontent.com/mohamedhagag/OdooInstaller/master/odoo_install.sh && bash odoo_install.sh
```

Will allow you to install Odoo and VSCode in ~30 minutes in 1st run, then in 3 minutes on Debian, Ubuntu, Fedora, Mint

For developers, this will create and organise an environment for Odoo development

You can install and run multiple Odoo 11+ versions using this script

You can use this script to install odoo master branch and start discovering next version of odoo and testing it.

# Usage

`bash odoo_install.sh $VER`

where $VER is odoo version, by default is latest version
