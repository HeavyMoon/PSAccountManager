# PowerSehll Account Manager
## PSAccountManager

:warning: This program is probably still buggy. :warning:

Run `Run_PSAM.bat` to start PSAccountManager.
In the default configuration, account data is encrypted with DPAPI.
You can choose between DPAPI and AES as the encryption method.

![PSAM_home](./image/PSAM_home.PNG "PSAccountManager home")  
![PSAM_list](./image/PSAM_list.PNG "PSAccountManager list")  
![PSAM_pref](./image/PSAM_pref.PNG "PSAccountManager pref")

Account data has the following values:
- label
- ID
- password
- date of expiry
- note

To add new account data, first click the NEW button and enter the account data. 
You will need to enter the password twice for confirmation. 
Then click the UPDATE button to add the account.


## PSPasswdGenerator
Run `Run_PSPG.bat` to start PSPasswdGenerator.

![PSPG](./image/PSPG.PNG "PSPasswdGenerator")

The symbols contain following characters:  
`/*-+,!?=()@;:._`
