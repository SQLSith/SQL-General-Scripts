
SELECT	[folder_name]
		,[project_name]
		,[package_name]
		,[environment_name] 
		,CASE [status] 
			WHEN 1 THEN 'created' 
			WHEN 2 THEN 'Running' 
			WHEN 3 THEN 'canceled' 
			WHEN 4 THEN 'failed' 
			WHEN 5 THEN 'pending' 
			WHEN 6 THEN 'ended unexpectedly' 
			WHEN 7 THEN 'succeeded' 
			WHEN 8 THEN 'stopping' 
			WHEN 9 THEN 'completed' 
		END ExecutionStatus
		,count(*) Executions
		,cast(min([start_time]) as smalldatetime) EarliestExecution
		,cast(max([start_time]) as smalldatetime) LatestExecution
FROM	[SSISDB].[catalog].[executions]
where	folder_name = 'Logistics'
group by [folder_name]
		,[project_name]
		,[package_name]
		,[environment_name] 
		,CASE [status] 
			WHEN 1 THEN 'created' 
			WHEN 2 THEN 'Running' 
			WHEN 3 THEN 'canceled' 
			WHEN 4 THEN 'failed' 
			WHEN 5 THEN 'pending' 
			WHEN 6 THEN 'ended unexpectedly' 
			WHEN 7 THEN 'succeeded' 
			WHEN 8 THEN 'stopping' 
			WHEN 9 THEN 'completed' 
		END
