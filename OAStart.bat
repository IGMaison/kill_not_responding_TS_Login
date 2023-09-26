

@echo off
@chcp 1251
setlocal enabledelayedexpansion
echo ��������� ������ ��� ��������� ������� �� � ������������� ������� � ����� �����^^!^^!^^!
echo ________________________________________________________________________________________

REM ��������� �����������  ������� ��� SQL ��������
set "SQLServer="     
set "Database="     
set "Username="     
set "Password="     

REM ��������� ������� TSClient.exe
set "TSClientDir="                             REM ���� � ����� � �������� (D:\Sensum\Terrasoft\Bin\)
set "TSClientFile="                            REM ���� ������� ������� (TSClient.exe)
set "cfg=/cfg="                                REM ������������ ������� (Dev)
set "wnd=/wnd=%1"                              REM �� ������. ��������, ���������� � ��������� ������ bat ����� - USI ����
set "usr=/usr="                                REM �����
set "pwd=/pwd="                                REM ������

set "Timeout=5"                                REM �������� �� ���������� �������� � ��������
set "OAErrFile=OAErr.txt"                      REM ���� ���� ������

set "Query=SELECT host_process_id FROM sys.dm_exec_sessions WHERE program_name = 'TSClient.exe' AND host_name = HOST_NAME()"

cd !TSClientDir!
set "CheckToBeClosed="
:SearchToBeClosed
REM ����������� PID ���������� �������� � Windows ����� �����
set "WPISs="
for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq TSClient.exe" /NH ^| findstr /i "TSClient.exe"') do (
    set "pid=%%a"
    set "WPISs=!WPISs! !pid!"
)

echo �������� TSClient.exe � Windows: !WPISs!

REM ����������� �� ������� PID ���������� �������� ����� �����
set "Result="
for /f "delims=" %%A in ('sqlcmd -S %SQLServer% -d %Database% -U %Username% -P %Password% -h -1 -W -Q "%Query%"') do (
    if not "!Result!"=="" (
        set "Result=!Result! %%A"
    ) else (
        set "Result=%%A"
    )
)

for /f "delims=" %%A in ('powershell -command "'!Result!' -replace '\(.*\)',''"') do set "SPIDs=%%A"

echo �������� TSClient.exe �� �������: !SPIDs!

REM ��� 3: ��������� PIDs �� ���� ������� � ���������� ���, ������� ������������ � ����� � ����������� ��� ����������� ����� ������.
set "ToBeClosed="
for %%c in (%WPISs%) do (
    echo %SPIDs% | findstr /i "%%c" > nul
    if errorlevel 1 (
        REM ��� 4: ���������� ����� PID, ������� ���� � WPISs � ��� � SPIDs
        set "ToBeClosed=!ToBeClosed! %%c"
    )
)

REM echo ToBeClosed: !ToBeClosed!

REM �������, ������� �������� ���������
set "Count=0"
for %%A in (%ToBeClosed%) do (
    set /a Count+=1
)
echo ������� �������� ��������� -- !Count! :

if !Count!==1 (
    if not defined CheckToBeClosed (
        REM ��� ���������� �� ������� ������ � ������ ������ �� ���������� � ����� ��������� �������������, ��� ��� �������� ����������� ����� !Timeout! ���.
        set "CheckToBeClosed=!ToBeClosed!"
        echo !CheckToBeClosed!
        timeout /t !Timeout! > nul
        echo ��������� �����....
        goto SearchToBeClosed
    ) else (
        echo �������� ��������� �������� ��������:
        echo !ToBeClosed!
        if !CheckToBeClosed!==!ToBeClosed! (
        echo ��������� � �������� ��������� �� �������
            REM ���� ����������� ����� �������� �����������, ������������� ��������� ������� � ��������� PID � ��������� ���� � ���� !OAErrFile!
            for %%A in (!ToBeClosed!) do (
                echo ...���������� ��� � !OAErrFile!
                set "Log="
                for /f "skip=1 tokens=*" %%B in ('wmic process where "ProcessID=%%A" get CommandLine^,ProcessId') do (
                        set "Log=!Log! %%B"
                    )
                echo %date% %time% - ��� ������ ������� !Log! >> %OAErrFile%
                echo ��������� �������:
                echo !Log!
                echo � ��� !Timeout! ���....
                taskkill /F /PID %%A > nul
                timeout /t !Timeout! > nul
            )
        )
    )
)
REM ��������� ����� �������....
set "cmdLine=!TSClientFile! !cfg! !wnd! !usr! !pwd!"
start !cmdLine!
echo ������ ������ ��������: !cmdLine! !wnd!
timeout /t !Timeout! > nul
echo ������!
