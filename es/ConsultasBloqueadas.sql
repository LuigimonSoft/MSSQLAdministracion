SELECT
 m.session_id,
 m.wait_duration_ms,
 m.wait_type,
 m.blocking_session_id,
 m.resource_description,
 a.program_name,
 s.text,
 s.dbid,
 g.query_plan,
 a.cpu_time,
 a.memory_usage
FROM sys.dm_os_waiting_tasks m
INNER JOIN sys.dm_exec_sessions a ON m.session_id=a.session_id
INNER JOIN sys.dm_exec_requests er ON a.session_id=er.session_id
OUTER APPLY sys.dm_exec_sql_text (er.sql_handle) s
OUTER APPLY sys.dm_exec_query_plan (er.plan_handle) g
WHERE a.is_user_process=1
go