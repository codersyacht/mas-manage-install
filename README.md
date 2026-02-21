## MAS Manage Installation

### Author: Jawahar

This document illustrates Operator Hub based installation of Maximo Application Manage including manual installation of all the integration components.

<img width="1374" height="774" alt="image" src="https://github.com/user-attachments/assets/37e680c5-8f63-4080-9e00-f78f2012e7ad" />


**Prerequisite**

(i) Maximo Application Suite has to be installed. In not installed yet, follow the instructions [here](https://github.ibm.com/maximo-application-suite/mas-suite-install)

(ii) DB2 has to be installed. If this step is already performed as part of mas suite install, then this can be skipped. If not follow the instructions below to install Db2. <br>

[Setup](https://github.com/codersyacht/maximo-knowledge-center/blob/main/devops/db2/setup.md) <br>
[Create Dstabase](https://github.com/codersyacht/maximo-knowledge-center/blob/main/devops/db2/create-db.md) <br>
[Configure Database](https://github.com/codersyacht/maximo-knowledge-center/blob/main/devops/db2/configuration.md) <br>

(iii) The _Install MAS JdbcCfg_ section in the mas suite install repository has to be completed post database installation. Refer [here](https://github.com/codersyacht/mas-suite-install)
### Cloning this Git Repository.

Create a git account here: https://github.com

Clone this repository to begin installation.

```CMD
git clone https://github.com/codersyacht/mas-manage-install
```
username: &lt;your-git-account-userid>&gt; <br>
password:  &lt;your-git-personal-access-token>&gt;


**Create Maximo Manage Project**

Execute the following command.

```CMD
./01-create-ibm-manage-project.sh
```

**Create Entitlement Key**

Ensure the entitlement key is copied into ./keyfiles/ibm-entitlement-key

Execute the following command.

```CMD
02-ibm-mas-entitlement-key.sh
```

**Manage Operator Installation**

Execute the following command.

```CMD
oc apply -f 03-ibm-manage-operatorgroup.yaml
```
```CMD
oc apply -f 04-ibm-manage-subscription.yaml
```

**Maximo Manage Application Installation**

Execute the following command.

```CMD
oc apply -f 05-ibm-manageapp.yaml
```

**Maximo Manage Workspace Installation**

```CMD
oc apply -f 06-ibm-manageworkspace.yaml
```
