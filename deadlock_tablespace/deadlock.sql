/*用户下死锁的查找*/
--step1：首先查询出导致锁表的SQL语句
select A.SQL_TEXT, B.USERNAME, C.OBJECT_ID, C.SESSION_ID,
       B.SERIAL#, C.ORACLE_USERNAME,C.OS_USER_NAME,C.Process,
       ''''||C.Session_ID||','||B.SERIAL#||''''
from v$sql A, v$session B, v$locked_object C
where A.HASH_VALUE = B.SQL_HASH_VALUE and
B.SID = C.Session_ID and b.USERNAME  in ('BIDEV');

--step2：查询出该语句的SQL_ID以及通过SQL_ID查找出相应的历史执行计划查看变化
select * from v$sql where sql_text like '%INSERT INTO RPT_TMRX_ANALYTICS%';

select distinct SQL_ID,PLAN_HASH_VALUE,to_char(TIMESTAMP,'yyyymmdd hh24:mi:ss')  TIMESTAMP
    from dba_hist_sql_plan 
    where SQL_ID='4t5tfjvkuw253'
order by TIMESTAMP;

select plan_hash_value,id,operation,options,object_name,depth,cost,to_char(TIMESTAMP,'yyyymmdd hh24:mi:ss')
    from DBA_HIST_SQL_PLAN  
    where sql_id ='4t5tfjvkuw253' and plan_hash_value in ('2983745106','381682812')
order by ID,TIMESTAMP; 

--step3：通过执行计划来诊断SQL查询过慢或者导致锁表的原因，如果需要人为解锁直接杀死进程
alter system kill session 'SESSION_ID,SERIAL#';

--step4：第三步进程可能未能杀死，只是在V$SESSION视图中标记status='KILLED',一下为部分关键字段解析，你可以在系统进程里面找到对应的进程号来处理
STATUS：这列用来判断session状态是：

        Achtive：正执行SQL语句(waiting for/using a resource)

        Inactive：等待操作(即等待需要执行的SQL语句)

        Killed：被标注为删除

下列各列提供session的信息，可被用于当一个或多个combination未知时找到session。

Session信息

        SID：SESSION标识，常用于连接其它列

        SERIAL#：如果某个SID又被其它的session使用的话则此数值自增加(当一个       SESSION结束，另一个SESSION开始并使用了同一个SID)。

        AUDSID：审查session ID唯一性，确认它通常也用于当寻找并行查询模式

        USERNAME：当前session在oracle中的用户名。

Client信息

数据库session被一个运行在数据库服务器上或从中间服务器甚至桌面通过SQL*Net连接到数据库的客户端进程启动，下列各列提供这个客户端的信息

        OSUSER：  客户端操作系统用户名

        MACHINE：客户端执行的机器

        TERMINAL：客户端运行的终端

        PROCESS：客户端进程的ID

        PROGRAM：客户端执行的客户端程序

要显示用户所连接PC的TERMINAL、OSUSER，需在该PC的ORACLE.INI或Windows中设置关键字TERMINAL，USERNAME。

Application信息

调用DBMS_APPLICATION_INFO包以设置一些信息区分用户。这将显示下列各列。

        CLIENT_INFO：DBMS_APPLICATION_INFO中设置

        ACTION：DBMS_APPLICATION_INFO中设置

        MODULE：DBMS_APPLICATION_INFO中设置

下列V$SESSION列同样可能会被用到：

        ROW_WAIT_OBJ#

        ROW_WAIT_FILE#

        ROW_WAIT_BLOCK#

        ROW_WAIT_ROW#
        
        
--step5：附注查询被存储过程或者函数视图所引用的SQL语句的视图
create materialized view BIRPT.UTI_DBA_COL_COMMENTS
refresh force on demand
start with to_date('12-01-2018 10:06:03', 'dd-mm-yyyy hh24:mi:ss') next SYSDATE + 1 
as
select
 nvl(tb.comments, '无') as tbcomments,
 t."OWNER",
 t."TABLE_NAME",
 t."COLUMN_NAME",
 t."COMMENTS"
  from dba_col_comments t, dba_tab_comments tb
 where t.owner = tb.owner
   and t.table_name = tb.table_name
   and not regexp_like(t.owner, 'SYS|OUT|DEP|ORD|FLO|APE|SC|STA');