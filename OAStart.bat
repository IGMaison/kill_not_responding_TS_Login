

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
for %%i in (%WPISs%) do (
    set "found=false"
    for %%j in (%SPIDs%) do (
        if %%i==%%j (
            set "found=true"
        )
    )
    if "!found!"=="false" (
        set "ToBeClosed= !ToBeClosed! %%i"
    )
)
REM Считаем, сколько непарных процессов
set "Count=0"
for %%A in (%ToBeClosed%) do (
    set /a Count+=1
)
echo Найдено непарных процессов -- !Count! :
echo !ToBeClosed!
if "!Count!" GTR "0" (

    if not defined CheckToBeClosed (
        REM При отсутствии на сервере некоторых из запущенных в винде процессов перепроверяем, что уже имеющийся у нас их перечень не уменьшился через !Timeout! сек.
        set "CheckToBeClosed=!ToBeClosed!"
        echo Повторный поиск....
        timeout /t !Timeout! > nul
        goto SearchToBeClosed
    ) else (
        echo Ищем,сравнив с найденными непарными процессами, исчезли ли какие-нибудь из уже составленного списка непарных процессов

        set "NewCheckToBeClosed="
        for %%i in (!CheckToBeClosed!) do (
            for %%j in (!ToBeClosed!) do (
                if %%i==%%j (
                    set "NewCheckToBeClosed=!NewCheckToBeClosed! %%i"
                )
            )
        )

        REM Проверяем изменился ли список непарных после предыдущего действия
        set "matchingValues=true"

        for %%i in (!CheckToBeClosed!) do (
            set "found=false"
            for %%j in (!NewCheckToBeClosed!) do (
                if %%i==%%j (
                    set "found=true"
                )
            )
            if "!found!"=="false" (
                set "matchingValues=false"
                goto changed
            )
        )

        :changed
        echo Обновлённый список непарных процессов для проверки:
        echo !NewCheckToBeClosed!

        if "!matchingValues!"=="true" (
            echo Изменений в непарных процессах не найдено
            REM Если изначально полученный список непарных больше не уменьшается, принудительно закрываем процессы с PID этого списка и добавляем инфу в файл !OAErrFile!
            for %%A in (!CheckToBeClosed!) do (
                echo ...записываем лог в !OAErrFile!
                set "Log="
                for /f "skip=1 tokens=*" %%B in ('wmic process where "ProcessID=%%A" get CommandLine^,ProcessId') do (
                        set "Log=!Log! %%B"
                    )
                echo %date% %time% - Был закрыт процесс !Log! >> %OAErrFile%
                echo Закрываем процесс:
                echo !Log!
                taskkill /F /PID %%A > nul
            )
            echo и ждём !Timeout! сек....
            timeout /t !Timeout! > nul
        ) else (
            echo Список непарных процессов уменьшился. Повторный поиск....
            timeout /t !Timeout! > nul
            set "CheckToBeClosed=!NewCheckToBeClosed!"
            goto SearchToBeClosed
        )
    )
)
REM Запускаем новый процесс....
set "cmdLine=!TSClientFile! !cfg! !wnd! !usr! !pwd!"
start !cmdLine!
echo Запуск нового процесса: !cmdLine! !wnd!
timeout /t !Timeout! > nul
echo Готово!
