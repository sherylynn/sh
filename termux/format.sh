#
#转化普通文件去适合termux的可执行bash
#参数1为文件

#!/usr/bin/env xxx
#!/data/data/com.termux/files/usr/bin/env xxx
#vim搜索下列
#\!\/usr
#替换为
#!\/data\/data\/com.termux\/files\/usr
