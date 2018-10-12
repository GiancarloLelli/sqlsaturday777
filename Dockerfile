# escape=`
FROM sixeyed/msbuild:netfx-4.5.2-ssdt AS builder

WORKDIR C:\src\Docker.Database
COPY src\Docker.Database .
RUN msbuild Docker.Database.sqlproj `
    /p:SQLDBExtensionsRefPath="C:\Microsoft.Data.Tools.Msbuild.10.0.61026\lib\net40" `
    /p:SqlServerRedistPath="C:\Microsoft.Data.Tools.Msbuild.10.0.61026\lib\net40"

# db image
FROM microsoft/mssql-server-windows-developer:latest

ENV ACCEPT_EULA="Y" `
    DATA_PATH="C:\data" `
    SA_PWD="D0ck3rD3v0ps" `
    DB_NAME="Docker" `
    DAC_NAME="Docker.Database"

WORKDIR C:\
COPY artifacts\DacFramework.msi .
COPY seed\Data_Seed.sql .
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN Start-Process 'C:\\DacFramework.msi' '/qn' -PassThru | Wait-Process;

VOLUME ${DATA_PATH}
WORKDIR C:\init

COPY artifacts\Initialize-Database.ps1 .
CMD powershell ./Initialize-Database.ps1 -sa_password $env:SA_PWD -data_path $env:DATA_PATH -db_name $env:DB_NAME -dac_name $env:DAC_NAME -Verbose

COPY --from=builder C:\docker\Docker.Database.dacpac .