-- Copyright (c) 2026 by Dominique Beneteau (dombeneteau@yahoo.com)


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- init script
--
-- Create schema if not exists
IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ARE'))
BEGIN
    EXEC('CREATE SCHEMA [ARE] AUTHORIZATION [dbo]');
END
go

drop table if exists ARE.Request;
create table ARE.Request(
ID int identity (1, 1) NOT NULL,
CreatedOn datetime2(7) NOT NULL,
Request nvarchar(255) NOT NULL,		-- The request to run (e.g. a stored procedure name)
Arg nvarchar(255) NULL,				-- the optional arguments (@arg1 = ..., @arg2 = ...). That allows you to populate them dynamically before using the API.
RequestPriority int NULL,			-- 1 (urgent) to 3 (less urgent). NULL = 3.
StartedOn datetime2(7) NULL,
EndedOn datetime2(7) NULL,
ReturnCode int NULL,
ReturnMessage nvarchar(255) NULL);
go

create or alter proc ARE.InsertRequest
@Request nvarchar(255) = NULL,
@Arg nvarchar(255) = NULL,
@RequestPriority int = NULL as
begin

-- When		Who			What
-- 20260102	Spiralos	Creation

	if ISNULL(ltrim(rtrim(@Request)), '') = ''
	begin
		throw 50000, 'Missing @Request', 1;
		return -1;
	end		

	if ISNULL(@RequestPriority, 4) NOT BETWEEN 1 and 3
		set @RequestPriority = 3;

	insert into ARE.Request (CreatedOn, Request, Arg, RequestPriority) VALUES (getdate(), @Request, @Arg, @RequestPriority);

	return 0
end
go

create or alter proc ARE.ExecRequest as
begin

-- When		Who			What
-- 20260102	Spiralos	Creation

	declare @ID int, @Request nvarchar(255), @Arg nvarchar(255), @SQL nvarchar(4000), @Err int, @ErrMessage nvarchar(255);
	declare @StartedOn datetime2(7), @EndedOn datetime2(7);

	if exists (select top 1 1 from ARE.Request where StartedOn IS NULL)
	begin
		select top 1
			@ID = ID,
			@Request = Request,
			@Arg = Arg
		from	ARE.Request
		where StartedOn IS NULL
		order by RequestPriority;

		set @StartedOn = getdate();
		begin try
			set @SQL = concat(@Request,	' ', ISNULL(@Arg, ''));
			EXEC(@SQL);
		end try
		begin catch
			set @Err = ERROR_NUMBER();
			set @ErrMessage = ERROR_MESSAGE();
		end catch

		set @EndedOn = getdate();

		update ARE.Request
		set StartedOn = @StartedOn,
			EndedOn = @EndedOn,
			ReturnCode = ISNULL(@Err, 0),
			ReturnMessage = @ErrMessage
		where ID = @ID;

	end
	return 0;
end
go

-- test requests
exec ARE.InsertRequest @Request='select 1';
exec ARE.InsertRequest @Request='select 1/0';
go

USE [msdb]
GO

EXEC msdb.dbo.sp_delete_job @job_id=N'3877daf9-c78c-4efb-9e34-f1d795de6178', @delete_unused_schedule=1
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'AsyncRequest', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'RunMe', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec ARE.ExecRequest;', 
		@database_name=N'dev', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 30 seconds', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=30, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20260102, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'de629cd7-2ebc-47a1-a8ef-10605c15aee8'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


