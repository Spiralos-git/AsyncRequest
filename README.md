Copyright (c) 2026 by Dominique Beneteau (dombeneteau@yahoo.com)

This SQL Server package allows you to run asynchronously a request. It is articulated around:
- A table that contains the requests to run (stored procs, commands, etc),
- An API (stored procedure) that allows you to insert into this table a request to run later,
- A SQL Agent job that polls this table every 30 seconds and process one request at a time.

This is particularly useful when you want to run a multi-step process (e.g. ETL) and part of it you want to execute non-urgent sequences... without having to wait these are completed.

Just run the Init.sql file on your platform. It will create the ARE schema, the ARE.Request table, the ARE.InsertRequest stored proc (API), the ARE.ExecRequest stored proc (called by the job) and the AsyncRequest SQL agent job.

------------------------------------------------------------------------------------------------------------
NOTE: Please rename the database used by the SQL Agent job with your own before running the Init.sql script.
------------------------------------------------------------------------------------------------------------

That's just a core engine. You can adapt it to monitor executions in real time (select ARE.Request), to report past executions (select ARE.Request), to create operational notifications or alerts (tweak/enhance error handling), etc.

Feel free to get in touch.
