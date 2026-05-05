# z_sysp_sap_adapter2 

Z-Transaction to dump code and data needed for Sysparency analysis using abapGit

It requires SAP BASIS version 702 or higher.
 
latest build: [z_sysp_sap_adapter2.zip](https://github.com/user-attachments/files/27405868/z_sysp_sap_adapter2.zip)

Build was generated using [abapmerge](https://github.com/larshp/abapmerge)

## Installation

1. Download the latest build: [z_sysp_sap_adapter2.zip](https://github.com/user-attachments/files/27405868/z_sysp_sap_adapter2.zip)
2. In your SAP® system in SE38, create the program Z_SYSP_SAP_ADAPTER2_STANDALONE with the downloaded ABAP® code and start it.
3. Under Package you can select which files you want to download (e.g. Z* for all packages in the Z namespace).
4. Run the report to download your ABAP® programs.
   If the error "sy-subrc 15" occurs, check in the SAP GUI options -> Security -> Security Settings whether a rule prevents access to the local directory.

## Credits and References
Adapter is based on [abapGit](https://github.com/abapGit/abapGit).
