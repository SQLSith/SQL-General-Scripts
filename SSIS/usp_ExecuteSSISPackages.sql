CREATE or Alter PROC [dbo].[usp_ExecuteSSISPackages] 
(
      @FolderName VARCHAR(255),
      @ProjectName VARCHAR(255),
      @PackageList varchar(8000),
      @EnvironmentName varchar(255),
	  @ExecutionType char(1)
)
AS
/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 16/03/2019

		Description:
		This procedure is intended to allow a way of executing one or more SSIS packages
		stored in the Integration Services Catalog.

		Usage:
		exec [dbo].[usp_ExecuteSSISPackages] 
			@FolderName = 'SolutionName',
			@ProjectName = 'Test',
			@PackageList = 'Package1.dtsx, Package2.dtsx',
			@EnvironmentName = null,--'EnvironmentName',
			@ExecutionType = 'S'


		Definitions:
			@FolderName 		This is the Name of the folder which contains the Packages to be run.
			@ProjectName 		The name of the project which contains the Packages to be run.
			@PackageList 		A comma seperated lilst of packages to execute.
			@EnviromentName 	The name of the environment against which to run the packages.
			@ExecutionType		Serial (S) or Parallel (P). 
								If run as a Parallel execution all packages will be started and 
								the procedure will complete. The packages will continue to run 
								to completion. Errors in package execution will not be reported.
								If run as a Serial execution the packages will run one at a time, 
								with each package being run to completion before the next is started.
								Failures will be reported, and no futher package will be started.

*/
	Set Nocount on
	;

	Declare 
		  @PackageName varchar(255),
		  @PackageID	int,
		  @PackageCount int,
		  @PackageCurrent int = 1,
		  @EnvironmentID bigint,
		  @execution_id bigint,
		  @Result varchar(50) = '',
		  @Fail int = 0,
		  @Return int = 0,
		  @ErrorMessageID int = 0,
		  @ErrorMessage varchar(8000),
		  @Synchronized bit


		-- Get Package List

			Declare	@Packages table (PackageID int identity(1,1), Package varchar(255), ExecutionID bigint)

			insert	@Packages (Package)
			Select	ltrim([value])
			from	string_split(@PackageList, ',')
			;

			Select	@PackageCount = count(*)
			from	@Packages
			;

		-- Look up Environment

			SELECT	@EnvironmentID = Reference_ID
			FROM	[SSISDB].[catalog].[projects] p
			join	[SSISDB].[catalog].[environment_references] r	on p.project_ID = r.project_ID
			join	[SSISDB].[catalog].[folders] f	on	p.folder_ID = f.folder_ID
			where	p.name = @ProjectName
			and		r.[environment_name] = @EnvironmentName
			and		f.name = @FolderName

		-- Evaluate parameters

			Select	@Synchronized =	Case @ExecutionType	when 'P' then 0
														else 1
									end
			;


		-- Iterate through packages

			Select @PackageCurrent =  1
			;

			-- Create all executions. Creating them as a batch allows easier tracking of progress.
			While @PackageCurrent <= @PackageCount
			begin
				Select	@PackageName = Package
				from	@Packages
				where	PackageID = @PackageCurrent
				;
							
				EXEC [SSISDB].[catalog].[create_execution] 
					@package_name=@PackageName, 
					@execution_id=@execution_id OUTPUT, 
					@folder_name=@FolderName, 
					@project_name=@ProjectName, 
					@use32bitruntime=False, 
					@reference_id=@EnvironmentID
				;
					
				EXEC [SSISDB].[catalog].[set_execution_parameter_value] 
					@execution_id,  
					@object_type=50, 
					@parameter_name=N'LOGGING_LEVEL', 
					@parameter_value=1
				;

				EXEC [SSISDB].[catalog].[set_execution_parameter_value] 
					@execution_id,  
					@object_type=50, 
					@parameter_name=N'SYNCHRONIZED', 
					@parameter_value=@Synchronized
				;

				Update	@Packages
				Set		ExecutionID = @execution_id
				where	PackageID = @PackageCurrent
				;

				Select	@PackageCurrent = @PackageCurrent + 1		
				;
			end

		



			Select @PackageCurrent =  1
			;

			-- Initiate Executions
			While @PackageCurrent <= @PackageCount
			begin
				Select	@execution_id = ExecutionID
				from	@Packages
				where	PackageID = @PackageCurrent
				;

				EXEC @Result = [SSISDB].[catalog].[start_execution] @execution_id
				;

				if @Synchronized = 1 -- Only relevant when running synchronously
				begin
					SELECT @Result = CASE [status] 
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
					FROM   SSISDB.[catalog] .[executions] 
					WHERE  execution_id =@execution_id
					;

					if (@Result <> 'succeeded')
					begin
						Select	@Fail = 1
						;

						Select	@ErrorMessage = [message],
								@ErrorMessageID = [event_message_id]
						from	SSISDB.catalog.event_messages
						where	Operation_ID = @execution_id
						and		message_type = 120
						;
					
						Throw 50001, @ErrorMessage, 1
					end
				end
					;

				Select @PackageCurrent = @PackageCurrent + 1		
				;
			end

go

