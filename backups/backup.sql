/*expdp实现的物理备份*/
--step1：先查看是否存在相应的备份目录
SELECT * FROM dba_directories;

--step2：没有目录则创建 在下面的命令中需要用到
create directory dump_dir as '/data2/orabak';

--step3：导出备份的命令 这里指定了表
expdp username/password tables=RPT_WI_WARESKUPC_LLBAK dumpfile=RPT_WI_WARESKUPC_LLBAK1018.dmp directory=dump_dir exclude=statistics logfile=export1.log;