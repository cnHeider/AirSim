@echo off
REM //---------- set up variable ----------
setlocal
set ROOT_DIR=%~dp0

REM // Check command line arguments
set noFullPolyCar=
set vsGen=Visual Studio 14 2015 Win64
:shift
if "%1"=="" goto noargs
if "%1"=="--no-full-poly-car" set "noFullPolyCar=y"
if "%1"=="--15" set vsGen=Visual Studio 15 2017 Win64
shift
goto :shift
:noargs

chdir /d %ROOT_DIR% 

REM //---------- Check cmake version ----------
CALL check_cmake.bat
if ERRORLEVEL 1 (
  CALL check_cmake.bat
  if ERRORLEVEL 1 (
    echo(
    echo ERROR: cmake was not installed correctly.
    goto :buildfailed
  )
)

REM //---------- get rpclib ----------
IF NOT EXIST external\rpclib mkdir external\rpclib
IF NOT EXIST external\rpclib\rpclib-2.2.1 (
	REM //leave some blank lines because powershell shows download banner at top of console
	ECHO(
	ECHO(   
	ECHO(   
	ECHO *****************************************************************************************
	ECHO Downloading rpclib
	ECHO *****************************************************************************************
	@echo on
	powershell -command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iwr https://github.com/rpclib/rpclib/archive/v2.2.1.zip -OutFile external\rpclib.zip }"
	@echo off
	
	REM //remove any previous versions
	rmdir external\rpclib /q /s

	powershell -command "& { Expand-Archive -Path external\rpclib.zip -DestinationPath external\rpclib }"
	del external\rpclib.zip /q
	
	REM //Don't fail the build if the high-poly car is unable to be downloaded
	REM //Instead, just notify users that the gokart will be used.
	IF NOT EXIST external\rpclib\rpclib-2.2.1 (
		ECHO Unable to download high-polycount SUV. Your AirSim build will use the default vehicle.
		goto :buildfailed
	)
)

REM //---------- Build rpclib ------------
ECHO Starting cmake to build rpclib...
IF NOT EXIST external\rpclib\rpclib-2.2.1\build mkdir external\rpclib\rpclib-2.2.1\build
cd external\rpclib\rpclib-2.2.1\build
cmake -G "%vsGen%" ..
cmake --build .
cmake --build . --config Release
if ERRORLEVEL 1 goto :buildfailed
chdir /d %ROOT_DIR% 


REM //---------- copy rpclib binaries and include folder inside AirLib folder ----------
set RPCLIB_TARGET_LIB=AirLib\deps\rpclib\lib\x64
if NOT exist %RPCLIB_TARGET_LIB% mkdir %RPCLIB_TARGET_LIB%
set RPCLIB_TARGET_INCLUDE=AirLib\deps\rpclib\include
if NOT exist %RPCLIB_TARGET_INCLUDE% mkdir %RPCLIB_TARGET_INCLUDE%
robocopy /MIR external\rpclib\rpclib-2.2.1\include %RPCLIB_TARGET_INCLUDE%
robocopy /MIR external\rpclib\rpclib-2.2.1\build\Debug %RPCLIB_TARGET_LIB%\Debug
robocopy /MIR external\rpclib\rpclib-2.2.1\build\Release %RPCLIB_TARGET_LIB%\Release

REM //---------- get High PolyCount SUV Car Model ------------
IF NOT EXIST Unreal\Plugins\AirSim\Content\VehicleAdv mkdir Unreal\Plugins\AirSim\Content\VehicleAdv
IF NOT EXIST Unreal\Plugins\AirSim\Content\VehicleAdv\SUV\v1.1.10 (
    IF NOT DEFINED noFullPolyCar (
        REM //leave some blank lines because powershell shows download banner at top of console
        ECHO(   
        ECHO(   
        ECHO(   
        ECHO *****************************************************************************************
        ECHO Downloading high-poly car assets.... The download is ~37MB and can take some time.
        ECHO To install without this assets, re-run build.cmd with the argument --no-full-poly-car
        ECHO *****************************************************************************************
       
        IF EXIST suv_download_tmp rmdir suv_download_tmp /q /s
        mkdir suv_download_tmp
        @echo on
        REM powershell -command "& { Start-BitsTransfer -Source https://github.com/Microsoft/AirSim/releases/download/v1.1.10/car_assets.zip -Destination suv_download_tmp\car_assets.zip }"
        REM powershell -command "& { (New-Object System.Net.WebClient).DownloadFile('https://github.com/Microsoft/AirSim/releases/download/v1.1.10/car_assets.zip', 'suv_download_tmp\car_assets.zip') }"
        powershell -command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iwr https://github.com/Microsoft/AirSim/releases/download/v1.1.10/car_assets.zip -OutFile suv_download_tmp\car_assets.zip }"
        @echo off
		rmdir /S /Q Unreal\Plugins\AirSim\Content\VehicleAdv\SUV
        powershell -command "& { Expand-Archive -Path suv_download_tmp\car_assets.zip -DestinationPath Unreal\Plugins\AirSim\Content\VehicleAdv }"
        rmdir suv_download_tmp /q /s
        
        REM //Don't fail the build if the high-poly car is unable to be downloaded
        REM //Instead, just notify users that the gokart will be used.
        IF NOT EXIST Unreal\Plugins\AirSim\Content\VehicleAdv\SUV ECHO Unable to download high-polycount SUV. Your AirSim build will use the default vehicle.
    ) else (
        ECHO Not downloading high-poly car asset. The default unreal vehicle will be used.
    )
)

REM //---------- get Eigen library ----------
IF NOT EXIST AirLib\deps mkdir AirLib\deps
IF NOT EXIST AirLib\deps\eigen3 (
    powershell -command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iwr http://bitbucket.org/eigen/eigen/get/3.3.2.zip -OutFile eigen3.zip }"
    powershell -command "& { Expand-Archive -Path eigen3.zip -DestinationPath AirLib\deps }"
    move AirLib\deps\eigen* AirLib\deps\del_eigen
    mkdir AirLib\deps\eigen3
    move AirLib\deps\del_eigen\Eigen AirLib\deps\eigen3\Eigen
    rmdir /S /Q AirLib\deps\del_eigen
    del eigen3.zip
)
IF NOT EXIST AirLib\deps\eigen3 goto :buildfailed

REM //---------- now we have all dependencies to compile AirSim.sln which will also compile MavLinkCom ----------
if not exist build mkdir build 
cd build
cmake -G "%vsGen%" ..
if ERRORLEVEL 1 goto :buildfailed
cmake --build . --config Debug
if ERRORLEVEL 1 goto :buildfailed
cmake --build . --config Release
if ERRORLEVEL 1 goto :buildfailed
cd ..

REM //---------- copy binaries and include for MavLinkCom in deps ----------
set MAVLINK_TARGET_LIB=AirLib\deps\MavLinkCom\lib
if exist %MAVLINK_TARGET_LIB% rd /s /q %MAVLINK_TARGET_LIB%
mkdir %MAVLINK_TARGET_LIB%\Debug
mkdir %MAVLINK_TARGET_LIB%\Release
copy build\output\lib\Debug\mavlinkcom* %MAVLINK_TARGET_LIB%\Debug
copy build\output\lib\Release\mavlinkcom* %MAVLINK_TARGET_LIB%\Release

set MAVLINK_TARGET_INCLUDE=AirLib\deps\MavLinkCom\include
if NOT exist %MAVLINK_TARGET_INCLUDE% mkdir %MAVLINK_TARGET_INCLUDE%
robocopy /MIR MavLinkCom\include %MAVLINK_TARGET_INCLUDE%

REM //---------- copy binaries and include for AirLib in deps ----------
set AIRLIB_TARGET_LIB=AirLib\lib
if exist %AIRLIB_TARGET_LIB% rd /s /q %AIRLIB_TARGET_LIB%
mkdir %AIRLIB_TARGET_LIB%\Debug
mkdir %AIRLIB_TARGET_LIB%\Release
copy build\output\lib\Debug\AirLib* %AIRLIB_TARGET_LIB%\Debug
copy build\output\lib\Release\AirLib* %AIRLIB_TARGET_LIB%\Release

REM //---------- all our output goes to Unreal/Plugin folder ----------
if NOT exist Unreal\Plugins\AirSim\Source\AirLib mkdir Unreal\Plugins\AirSim\Source\AirLib
robocopy /MIR AirLib Unreal\Plugins\AirSim\Source\AirLib  /XD temp *. /njh /njs /ndl /np

REM //---------- done building ----------
exit /b 0

:buildfailed
chdir /d %ROOT_DIR% 
echo(
echo #### Build failed - see messages above. 1>&2
exit /b 1



