/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 14/03/2019

		Description:
		This script is designed to accompany "Create SSIS Environment.sql". 
		Running this script prints a collection of Configurations which can be used
		in "Create SSIS Environment.sql" to source control or replicate existing 
		environments. 

		Usage:
		The body of the script should not be modified. Modify only the section starting 
		"Configuration" and ending "Configuration End"

		Definitions:
		@FolderName - This is the Name of the folder in which the project which 
					  references the environment is deployed.
		@EnviromentName - The name of the environment.

		To Do:
		* Accommodate Projects and Environments in different folders 
*/
Use SSISDB
go


/***************** Configuration *******************/


Declare	@FolderName varchar(128) = 'SolutionName',
		@EnviromentName varchar(128) = 'EnvironmentName'


/***************** Configuration End *******************/














Set nocount on
;

-- Declare variables 
	Declare	@FolderID bigint,
			@EnvironmentID bigint,
			@ProjectID int,
			@ProjectName varchar(255),
			@ProjectCount int,
			@ProjectCurrent int = 1,
			@VariableCount int ,
			@VariableCurrent int = 1,
			@VariableString nvarchar(max)
	;

	Declare	@Projects table
		(
		ProjectSeq int identity(1,1),
		ProjectID int,
		ProjectName varchar(255),
		EnvironmentFolderName varchar(255),
		ReferenceType char(1)
		)
	;

	Declare @Variables table 
		(
		VariableSeq int identity(1,1),
		ProjectID int,
		VariableDefinition nvarchar(max)
		)
	;

-- Lookup folder and environment ids
	Select	@FolderID = [folder_id]
	from	[catalog].[folders]
	where	[name] = @FolderName
	;

	Select	@EnvironmentID = [environment_id]
	from	[catalog].[environments]
	where	[folder_id] = @FolderID
	and		[name] = @EnviromentName
	;


-- Identify Projects that reference the environment

	insert	@Projects (ProjectID, ProjectName, EnvironmentFolderName, ReferenceType)
	Select  p.project_id,
			p.name ProjectName,
			r.environment_folder_name,
			r.reference_type
	from	catalog.environment_references r
	join	[catalog].[projects] p  on	 r.project_id = p.project_id
	where	r.environment_name = @EnviromentName
	and		p.folder_id = @FolderID


-- Iterate projects
	Select	@ProjectCount = count(*),
			@ProjectCurrent = 1
	from	@Projects

	while @ProjectCurrent <= @ProjectCount
	begin
		Select	@ProjectName = ProjectName,
				@ProjectID = ProjectID
		from	@Projects
		where	ProjectSeq = @ProjectCurrent
		;

		Print 'Project: ' + @ProjectName
		print replicate('-', 9 + len(@ProjectName)) + char(10)

		Print 'Declare	@FolderName varchar(128) = ' + quotename(@FolderName, char(39))
		Print 'Declare	@ProjectName varchar(128) = ' + quotename(@ProjectName, char(39))
		Print 'Declare	@EnviromentName varchar(128) = ' + quotename(@EnviromentName, char(39)) + char(10)
		;

		Delete @Variables
		;

		insert	@Variables (ProjectID, VariableDefinition)
		Select	p.project_id,
				'Insert @Variables values (' + 
				quotename(case when p.parameter_name like 'CM.%.ConnectionString' then 'Connection' else 'Parameter' end, char(39)) + ',' + 
				quotename(case when p.parameter_name like 'CM.%.ConnectionString' then parsename(ev.name,2) else ev.[name] end, char(39))  + ',' + 	
				'N' + quotename(ev.[type], char(39))  + ',' + 
				case when ev.[type] in ('String','DateTime') then 'N' + nchar(39) + cast(ev.[Value] as nvarchar(4000)) + nchar(39) else cast(ev.[Value] as nvarchar(4000)) end  + ',' + 
				cast(ev.Sensitive as char(1)) + ',' + 
				isnull(quotename(nullif(p.object_name,@ProjectName), char(39)),'null') + ')'
		from	[catalog].[environment_variables]  ev
		join	[catalog].[object_parameters] p	on	ev.name = p.referenced_variable_name
		where	ev.environment_id = @EnvironmentID
		and		p.project_id = @ProjectID
		and		p.Value_Type = 'R'
		;

		Select	@VariableString = cast((	Select	case when VariableSeq > 1 then char(10) else '' end + VariableDefinition [data()]
											from	@Variables
											order by VariableSeq
											for xml path(''), type
										) as nvarchar(max))
		; 

		Print @VariableString + char(10) + char(10)

		Select @ProjectCurrent = @ProjectCurrent + 1
	end