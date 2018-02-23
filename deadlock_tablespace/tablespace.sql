/*表空间清理相关步骤*/
--step1：查询出占用空间最大的对象(表、索引、CLOB字段)
select  t.segment_name, t.segment_type, sum(t.bytes / 1024 / 1024/1024) "占用空间(G)"
--,'select \*+parallel(8)+*\ *  from dba_source t where lower(t.text) like lower('''||t.segment_name||''') order by name;'
from dba_segments t
where --t.segment_type='INDEX' and 
t.owner='BIDEV' 
--and lower(segment_name) like '%rpt_wi%'
--and t.bytes=65536
group by OWNER, t.segment_name, t.segment_type
--having sum(t.bytes / 1024 / 1024/1024) >0.1
order by  sum(t.bytes / 1024 / 1024/1024) desc;

--step2：查找占用空间较大的CLOB字段相关信息
select * from dba_lobs where SEGMENT_NAME in ('SYS_LOB0000311634C00007$$'); 
select * from dba_objects where object_name in ('SYS_LOB0000311634C00007$$');

--step3：查看表空间的总大小，根据业务需求清理大字段或者大表
select tablespace_name,sum(bytes)/1024/1024/1024 from dba_data_files group by tablespace_name;
ALTER TABLE table_name_old RENAME TO table_name_old_bak;--重命名表
/*如果clob字段不能删除，那么可以考虑用下面的命令将该字段移到其他的表空间*/
select 'alter table ' || t.owner || '.' || t.table_name || ' move lob (' ||
       column_name || ') store as ' || t.table_name ||
       '_lobsegment (tablespace USERS );'
  from dba_lobs l, dba_tables t
where l.owner = t.owner
   and l.table_name = t.table_name
   and l.SEGMENT_NAME in
       (select segment_name
          from dba_segments
         where segment_type like 'LOBSEGMENT'
           and tablespace_name = 'BIDEV_DATA')
order by t.owner, t.table_name;

/*清理CLOB字段及压缩CLOB空间*/

--1、创建LOB字段存放表空间：

create tablespace lob_test datafile '/oracle/data/lob_test.dbf' size 500m autoextend on next 10m maxsize unlimited

--2、移动LOB字段到单独存放表空间：

ALTER TABLE CENTER_ADMIN.NWS_NEWS

MOVE LOB(ABSTRACT)

STORE AS (TABLESPACE lob_test);

ABSTRACT---为一CLOB类型的字段

lob_test---为新创建的表空间。

--3、清空指定时间段CLOB字段的内容：

update CENTER_ADMIN.NWS_NEWS

set ABSTRACT=EMPTY_CLOB()

where substr(to_char(pubdate,'yyyy-mm-dd'),1,4)='2011'

--4、单独shrink CLOB字段：

ALTER TABLE CENTER_ADMIN.NWS_NEWS MODIFY LOB (ABSTRACT) (SHRINK SPACE);

--注：此方法会在表空间级释放出部分空间给其他对象使用，但这部分空间在操作系统级还是被占用

--5、在操作系统级释放空间 （这一步 一般不做）：

alter database datafile '/oracle/data/lob_test.dbf' resize 400m

---注：绝大多数情况下，不可能一个表空间中只存放一个CLOB字段，若需要从操作系统级真正释放空间，尚需要shink table或EXP/IMP等操作
