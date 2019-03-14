/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 05/10/2017

		Description:
		This script creates an environment and configures a project to reference it. 
		Because the definition of the environment is held within the script, this 
		also enables environments to be source controlled and moved between servers.

		Usage:
		The body of the script should not be modified. Modify only the section starting 
		"Configuration" and ending "Configuration End"

		Definitions:
		@FolderName - This is the Name of the folder in which the project which will 
					  reference the environment is deployed.
		@ProjectName - The name of the project which will reference the environment.
		@EnviromentName - The name of the environment to be created/modified.

		@Variables - This table variable holds the definition all parameters and variables 
					 to be included in the environment, and how projects should be 
					 configured to use them. The fields are:
			UsageType       The Type of environment variable. This is either Connection or Parameter.
			VariableName    The name of the environment variable. This is the name as it appears in referencing 
						    SSIS packages/projects, and is case sensitive.
			VariableType    The data type of the environment variable.
			VariableValue   The value to assign to the environment variable.
			PackageName     A Package name. If supplied then the package is configured to use the 
						    environment variable. If omitted the project is configured to use the environment variable.
		To Do:
		* Accommodate Projects and Environments in different folders 
*/




Use SSISDB
go

Declare	@Variables table	
		(
		VariableID int identity(1,1) not null,
		UsageType	varchar(50) check (UsageType in ('Connection', 'Parameter')) not null,
		VariableName varchar(125) not null,
		VariableType varchar(50) check (VariableType in ('Boolean', 'Byte', 'DateTime', 'Double', 'Int16', 'Int32', 'Int64', 'Single', 'String', 'UInt32', 'UInt64')) not null,
		VariableValue sql_Variant not null, 
		VariableSensitive bit not null,
		PackageName varchar(255) null
		)


/***************** Configuration *******************/

	Declare	@FolderName varchar(128) = 'SolutionName',
			@ProjectName varchar(128) = 'Test',
			@EnviromentName varchar(128) = 'EnvironmentName'
	;

	insert	@Variables values ('Parameter', 'VariableName', N'String', N'VariableValue', 0, null)
	insert	@Variables values ('Connection', 'MyDatabase', N'String', N'Data Source=Server\Instance;Initial Catalog=DatabaseName;Provider=SQLNCLI11.1;Integrated Security=SSPI;Auto Translate=False;', 0, 'Package.dtsx')




/***************** Configuration End *******************/















-- Declare variables 
	Declare	@FolderID bigint,
			@EnvironmentID bigint,
			@UsageType varchar(50),
			@VariableName nvarchar(125),
			@VariableNameFull nvarchar(125),
			@VariableNameParameter nvarchar(125),
			@VariableType nvarchar(50),
			@VariableValue sql_Variant, 
			@VariableSensitive bit,
			@PackageName varchar(255),
			@ProjectID bigint,
			@ReferenceID bigint,
			@reference_id bigint,
			@VariableCount int ,
			@VariableCurrent int = 1,
			@ObjectType tinyint,
			@ObjectName varchar(50)



	Declare	@VariableParameters table
			(
			VariableID int,
			ObjectType tinyint,
			VariableNameFull varchar(255),
			ParameterName	varchar(255),
			ObjectName	varchar(255)
			)


	Declare	@VariableExisting table
			(
			ExistingVariableID int identity(1,1),
			VariableName varchar(255)
			)

	insert	@VariableParameters
	Select	VariableID,
			case when nullif(PackageName,'') is null then 20 else 30 end ObjectType,
			case when UsageType = 'Connection' then VariableName + '.Connection' else VariableName end VariableNameFull,
			case when UsageType = 'Connection' then 'CM.' + VariableName + '.ConnectionString' else VariableName end ParameterName,
			isnull(nullif(PackageName,''), @ProjectName) ObjectName
	from	@Variables



-- Create Folder

	Select	@FolderID = [folder_id]
	from	[catalog].[folders]
	where	[name] = @FolderName
	;


-- Create Environment

	Select @EnvironmentID = [environment_id]
	from	[catalog].[environments]
	where	[folder_id] = @FolderID
	and		[name] = @EnviromentName
	;

	if @EnvironmentID is null
	begin
		EXEC [catalog].[create_environment] 
				@environment_name=@EnviromentName, 
				@folder_name = @FolderName
				;
	end


-- Create Environement References

	Select	@ProjectID = [project_id]
	from	[catalog].[projects]
	where	folder_id = @FolderID
	and		[name] = @ProjectName
	;

	Select	@reference_id = [reference_id]
	from	[catalog].[environment_references]
	where	[project_id] = @ProjectID
	and		[environment_name] = @EnviromentName
	;

	if @reference_id is null
	begin
		EXEC [catalog].[create_environment_reference] 
				@environment_name=@EnviromentName, 
				@reference_id=@reference_id OUTPUT, 
				@project_name=@ProjectName, 
				@folder_name=@FolderName, 
				@reference_type=R
	end


-- Delete Existing Environemnet Variables

	insert	@VariableExisting (VariableName)
	Select	[name]
	from	[catalog].[environment_variables] 
	where environment_id = @EnvironmentID
	;

	Select	@VariableCount = count(*),
			@VariableCurrent = 1
	from	@VariableExisting


	While @VariableCurrent <= @VariableCount
	begin
		Select	@VariableName = VariableName
		from	@VariableExisting
		where	ExistingVariableID = @VariableCurrent
		;

		EXEC [catalog].[delete_environment_variable]	@folder_name=@FolderName, 
														@environment_name=@EnviromentName, 
														@variable_name=@VariableName
		;

		Select	@VariableCurrent = @VariableCurrent + 1
	end


-- Create Environement Variables and reference

	Select	@VariableCount = count(*),
			@VariableCurrent = 1
	from	@Variables
	;

	While @VariableCurrent <= @VariableCount
	begin
	-- Lookup specific parameters
		Select	@UsageType = UsageType,
				@VariableName = VariableName, 
				@VariableType = VariableType, 
				@VariableValue = VariableValue,
				@VariableSensitive = VariableSensitive
		from	@Variables
		where	VariableID = @VariableCurrent

		Select  @VariableNameFull = VariableNameFull,
				@VariableNameParameter = ParameterName,
				@ObjectType = ObjectType,
				@ObjectName = ObjectName
		from	@VariableParameters
		where	VariableID = @VariableCurrent
		
		
	-- Create Environment variable
		EXEC [catalog].[create_environment_variable] 
				@variable_name=@VariableNameFull, 
				@sensitive = false, 
				@environment_name=@EnviromentName, 
				@folder_name=@FolderName, 
				@value=@VariableValue, 
				@data_type=@VariableType
		;

	-- connect a variable to a package parameter
		EXEC [catalog].[set_object_parameter_value] 
				@object_type=@ObjectType, 
				@parameter_name=@VariableNameParameter, 
				@object_name=@ObjectName, 
				@folder_name=@FolderName, 
				@project_name=@ProjectName,
				@value_type=R, 
				@parameter_value=@VariableNameFull
		;

		Select @VariableCurrent = @VariableCurrent + 1
	end
GO

