cd %~dp0
ECHO %PROCESSOR_ARCHITECTURE%|FINDSTR AMD64>NUL && SET ARCH=x64|| SET ARCH=x86

findstr /m "NVIDIA" .userdata\%USERNAME%\info\gpu_vendor
if %errorlevel%==0 (
	SET ARCH=x86
)

cd .base/bin/windows/%arch%/
start luajit.exe ../../../lua/init.lua
