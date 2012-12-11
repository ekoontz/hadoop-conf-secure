#FS=centos1.local
FS=ekoontz1
while [ 1 ] 
do 
    ~/hadoop-runtime/bin/hadoop fs -mkdir hdfs://$FS:8020/tmp/
    ~/hadoop-runtime/bin/hadoop fs -rm hdfs://$FS:8020/tmp/* 
    ~/hadoop-runtime/bin/hadoop fs -copyFromLocal ~/hadoop-runtime/logs/*   hdfs://$FS:8020/tmp/
    ~/hadoop-runtime/bin/hadoop fs -ls -R hdfs://$FS:8020/
    sleep 120
 done
