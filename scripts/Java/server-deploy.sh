#!/bin/bash
# First argument -> project name
projectName=$1
# Second argument -> server name,deploy server name
serverName=$2
# Third argument  -> deploy port
serverPort=$3
# Fourth argument -> deploy environment
springProfilesActive=$4
# Five argument -> SENTRY_DSN
sentryDsn=$5

#########Absolute path###########
# source absolute path.
sourceAbsPath=/home/$projectName/codepipeline
# project absolute path.
projectAbsPath=/home/$projectName/server
# destination absolute path.
destAbsPath=$projectAbsPath/jar
# destination absolute log path
destAbsLogPath=/mnt/$projectName/log
# backup folder
backupFolder=$projectAbsPath/backup
#################################

# jar file
sourceFile=$sourceAbsPath/$serverName.jar
destFile=$destAbsPath/$serverName.jar
backupFile=$backupFolder/$serverName.jar
# log file
logFile=$destAbsLogPath/$serverName.log
whatToFind="Started "
msgBuffer="Buffering: "
msgAppStarted="Application Started... exiting buffer!"

########Function#########
# 修改环境
function modifyEnv() {
	export LANG=en_US.UTF-8
	export LC_CTYPE=en_US.UTF-8
}

# 备份jar包服务
function backup() {
	if [[ ! -d "$backupFolder" ]]; then
		echo "Mkdir backup folder $backupFolder"
		mkdir -p $backupFolder
	fi
	if [[ -f "$destFile" ]]; then
		echo "Backup $destFile to $backupFile"
		cp $destFile $backupFile
	fi
	echo " "
}

# 删除旧的jar包服务
function delete() {
	echo "Deleting old jar file $destFile"
	rm -rf $destFile
	echo " "
}

# 将新的jar包复制到工作目录
function copy() {
	if [[ ! -d $destAbsPath ]]; then
		echo "Mkdir dest folder $destAbsPath"
		mkdir -p $destAbsPath
	fi
	if [[ ! -f "$sourceFile" ]]; then
		echo "Error,$sourceFile not exists!Please check it!"
		exit
	else
		echo "Copying file $sourceFile to $destFile"
		cp $sourceFile $destFile
	fi
	echo " "
}

# 修改jar包文件权限
function changeFilePermission() {
	echo "Changing File Permission: chmod 777 $destFile"
	chmod 777 $destFile
	echo " "
}
# 结束服务，首先判断lsof命令是否存在，不存在则先安装lsof命令；存在使用命令查找指定端口所在进程并结束
function stopServer() {
	if hash lsof 2>/dev/null; then
        echo "lsof command exist!"
    else
        echo "lsof command not exist,start install"
		yum install -y lsof
    fi
	
	name=$(lsof -i:$serverPort|tail -1|awk '"$1"!=""{print $2}')
	if [ -z $name ]
	then
		echo "No process can be used to killed!"
	fi
	id=$(lsof -i:$serverPort|tail -1|awk '"$1"!=""{print $2}')
	kill -9 $id
	 
	echo "Process name=$name($id) kill!"
}

# 清理
function cleanUp() {
	if [[ -f "$logFile" ]]; then
		echo "Deleting $logFile"
		rm -rf $logFile
	fi
	if [[ ! -d "$destAbsLogPath" ]]; then
	   echo "Mkdir dest log folder $destAbsLogPath"
	   mkdir -p $destAbsLogPath
	fi
	echo "Creating $logFile" 
	touch $logFile
	echo " "
}

# 执行jar包服务
function run() {
	echo "COMMAND: nohup java -Dsentry.dsn=$sentryDsn -jar $destFile --SPRING_PROFILES_ACTIVE=$springProfilesActive --server.port=$serverPort $> $logFile 2>&1 &"
	nohup java -Dsentry.dsn=$sentryDsn -jar $destFile --SPRING_PROFILES_ACTIVE=$springProfilesActive --server.port=$serverPort $> $logFile 2>&1 &
	echo " "
}

function watch(){
    tail -f $logFile|
        while IFS= read line
            do
                echo "$msgBuffer" "$line"

                if [[ "$line" == *"$whatToFind"* ]]; then
                    echo $msgAppStarted
                    pkill  tail
                fi
        done
}

##### functions calls #####
# 1.修改运行环境
modifyEnv
# 2.备份jar包服务
backup
# 3.删除旧的jar包服务
delete
# 4.将新的jar包复制到工作目录
copy
# 5.修改jar包文件权限
changeFilePermission
# 6.stop server on port ...
stopServer
# 7.清理日志文件
cleanUp
# 8.start server
run
# 9.watch loading messages until  ($whatToFind) message is found
watch