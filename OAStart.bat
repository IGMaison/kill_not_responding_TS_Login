

@echo off
@chcp 1251
setlocal enabledelayedexpansion
echo Запускать только при обращении клиента ТС к единственному серверу с этого компа^^!^^!^^!
echo ________________________________________________________________________________________

REM Параметры подключения  серверу для SQL запросов
set "SQLServer="     
set "Database="     
set "Username="     
set "Password="     

REM Параметры запуска TSClient.exe
set "TSClientDir="                             REM Путь к папке с клиентом (D:\Sensum\Terrasoft\Bin\)
set "TSClientFile="                            REM файл запуска клиента (TSClient.exe)
set "cfg=/cfg="                                REM конфигурация сервера (Dev)
set "wnd=/wnd=%1"                              REM Не менять. Параметр, переданный в командной строке bat файла - USI окна
set "usr=/usr="                                REM логин
set "pwd=/pwd="                                REM пароль

set "Timeout=5"                                REM ожидание на выполнение операций в секундах
set "OAErrFile=OAErr.txt"                      REM Файл лога ошибок

set "Query=SELECT host_process_id FROM sys.dm_exec_sessions WHERE program_name = 'TSClient.exe' AND host_name = HOST_NAME()"

cd !TSClientDir!
set "CheckToBeClosed="
:SearchToBeClosed
REM Определение PID запущенных клиентов в Windows этого компа
set "WPISs="
for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq TSClient.exe" /NH ^| findstr /i "TSClient.exe"') do (
    set "pid=%%a"
    set "WPISs=!WPISs! !pid!"
)

echo Процессы TSClient.exe в Windows: !WPISs!

REM Определение на сервере PID запущенных клиентов этого компа
set "Result="
for /f "delims=" %%A in ('sqlcmd -S %SQLServer% -d %Database% -U %Username% -P %Password% -h -1 -W -Q "%Query%"') do (
    if not "!Result!"=="" (
        set "Result=!Result! %%A"
    ) else (
        set "Result=%%A"
    )
)

for /f "delims=" %%A in ('powershell -command "'!Result!' -replace '\(.*\)',''"') do set "SPIDs=%%A"

echo Процессы TSClient.exe на сервере: !SPIDs!

REM Шаг 3: Сравнение PIDs из двух списков и нахождение тех, которые присутствуют в винде и отсутствуют при определении через сервер.
set "ToBeClosed="
for %%c in (%WPISs%) do (
    echo %SPIDs% | findstr /i "%%c" > nul
    if errorlevel 1 (
        REM Шаг 4: Нахождение чисел PID, которые есть в WPISs и нет в SPIDs
        set "ToBeClosed=!ToBeClosed! %%c"
    )
)

REM echo ToBeClosed: !ToBeClosed!

REM Считаем, сколько непарных процессов
set "Count=0"
for %%A in (%ToBeClosed%) do (
    set /a Count+=1
)
echo Найдено непарных процессов -- !Count! :

if !Count!==1 (
    if not defined CheckToBeClosed (
        REM При отсутствии на сервере одного и только одного из запущенных в винде процессов перепроверяем, что эта ситуация сохранилась через !Timeout! сек.
        set "CheckToBeClosed=!ToBeClosed!"
        echo !CheckToBeClosed!
        timeout /t !Timeout! > nul
        echo Повторный поиск....
        goto SearchToBeClosed
    ) else (
        echo Повторно найденные непарные процессы:
        echo !ToBeClosed!
        if !CheckToBeClosed!==!ToBeClosed! (
        echo Изменений в непарных процессах не найдено
            REM Если проверенная ранее ситуация сохранилась, принудительно закрываем процесс с найденным PID и добавляем инфу в файл !OAErrFile!
            for %%A in (!ToBeClosed!) do (
                echo ...записываем лог в !OAErrFile!
                set "Log="
                for /f "skip=1 tokens=*" %%B in ('wmic process where "ProcessID=%%A" get CommandLine^,ProcessId') do (
                        set "Log=!Log! %%B"
                    )
                echo %date% %time% - Был закрыт процесс !Log! >> %OAErrFile%
                echo Закрываем процесс:
                echo !Log!
                echo и ждём !Timeout! сек....
                taskkill /F /PID %%A > nul
                timeout /t !Timeout! > nul
            )
        )
    )
)
REM Запускаем новый процесс....
set "cmdLine=!TSClientFile! !cfg! !wnd! !usr! !pwd!"
start !cmdLine!
echo Запуск нового процесса: !cmdLine! !wnd!
timeout /t !Timeout! > nul
echo Готово!
