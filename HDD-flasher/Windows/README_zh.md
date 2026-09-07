# hdd-flasher
定时向指定路径下的flash.txt刷写当前时间戳的脚本,以用于保持HDD运行。

请使用bat文件作为执行入口,在flash-config.txt中填入目标路径即可。

支持运行时控制台命令：
* /pause (暂停/恢复)
* /flash (立即刷写)
* /reload (重载flash-config.txt)
* /stop (终止脚本运行)