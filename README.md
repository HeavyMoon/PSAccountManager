# PowerSehll Account Manager
## PSAccountManager
This is a password manager implemented using only standard Windows functions based on PowerShell 5.1.
All account information is encrypted with DPAPI.

### Simple instructions for use
1. Run `Run_PSAM.bat` to start PSAccountManager.  
![PSAM_list](./image/PSAM_list.PNG "PSAccountManager list")  
2. To add new account data, first click the NEW button and enter the account data. You will need to enter the password twice for confirmation. 
3. Then click the UPDATE button to add the account.

## PSPasswdGenerator
This is a password generator implemented using only standard Windows functions based on PowerShell 5.1.
As with PSAccountManager, please start it by running `Run_PSPG.bat`.

![PSPG](./image/PSPG.PNG "PSPasswdGenerator")

The symbols contain following characters:  
`/*-+,!?=()@;:._`

## Notes
- Requires Windows PowerShell 5.1 or later
- All data is stored locally; no network communication is performed
- For any issues or feature requests, please open an issue on GitHub
