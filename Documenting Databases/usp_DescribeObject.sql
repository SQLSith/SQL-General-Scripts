Create or alter procedure dbo.usp_DescribeObject (@ObjectNameFull varchar(255))
as
	/*
		Author: Jonathan Bairstow
		Created: 13/05/2018
		Description:
		Produces datasets that describe the supplied object. Currently supports:
			* Tables
			* Views
			* Scalar functions
			* Table valued functions
			* Inline Table Valued functions
			* Synonyms
			* Sequences
			* Triggers

		Usage:
		exec [dbo].[usp_DescribeObject] '[SchemaName].[TableName]'
	*/


-- Gather Object Metadata
	Declare	@ObjectName varchar(128),
			@ObjectSchema varchar(128),
			@ObjectID int,
			@SchemaID int,
			@ObjectType varchar(250),
			@ObjectSubType varchar(250),
			@CreatedDTS datetime,
			@ModifiedDTS datetime
	;

	Select	@ObjectID = object_id(@ObjectNameFull)

	if @ObjectID is null
	begin
		-- Database Triggers
		Select	@ObjectID = object_id,
				@ObjectName = parsename(@ObjectNameFull, 1),
				@ObjectSchema = null,
				@CreatedDTS = create_date,
				@ModifiedDTS = modify_date,
				@ObjectType = 'SQL_TRIGGER'
		from	sys.triggers
		where	name = parsename(@ObjectNameFull, 1)
		and		parent_class = 0

	end
	else 
	begin
		Select	@ObjectName = parsename(@ObjectNameFull, 1),
				@ObjectSchema = isnull(parsename(@ObjectNameFull, 2), SCHEMA_NAME()), -- Default to connected users default schema
				@ObjectID = object_id(@ObjectNameFull),
				@SchemaID = schema_id(isnull(parsename(@ObjectNameFull, 2), SCHEMA_NAME()))

		Select	@ObjectType = [type_desc],
				@CreatedDTS = create_date,
				@ModifiedDTS = modify_date
		from	sys.objects
		where	OBJECT_ID = @ObjectID
	end




-- ObjectSubType	

	if @ObjectType = 'USER_TABLE'
	begin
		Select	@ObjectSubType = case t.temporal_type	when 0 then 'Non-Temporal Table'
														when 1 then 'History Table for ' + schema_name(s.schema_id) + '.' + OBJECT_NAME(s.object_id)
														when 2 then 'Temporal Table - History Table ' + schema_name(h.schema_id) + '.' + OBJECT_NAME(h.object_id)
								 end 
		from	sys.tables t
		left join sys.tables h	on	h.object_id = t.history_table_id
		left join sys.tables s	on	s.history_table_id = t.object_id
		where	t.object_id = @ObjectID
	end 

	if @ObjectType = 'SQL_TRIGGER'
	begin
		Select	@ObjectSubType = case	when parent_class = 0 then 'Database'
										when t.type = 'TA' then 'CLR'
										when t.type = 'TR' then 'SQL'
								 end 
		from	sys.triggers t
		where	t.object_id = @ObjectID
	end 


-- Summary Level
	Select '******* Object Summary *******' [Description]
	;

	Select	isnull(@ObjectSchema + '.','') + @ObjectName ObjectName,	
			case	@ObjectType		when 'USER_TABLE' then 'Table'
									when 'VIEW' then 'View'
									when 'SQL_STORED_PROCEDURE' then 'Stored Procedure'
									when 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'Function - Inline Table'
									when 'SQL_TABLE_VALUED_FUNCTION' then 'Function - Table'
									when 'SQL_SCALAR_FUNCTION' then 'Function - Scalar'
									when 'SYNONYM' then 'Synonym'
									when 'SEQUENCE_OBJECT' then 'Sequence'
									when 'SQL_TRIGGER' then 'Trigger - DML'
			end	ObjectType,
			@ObjectSubType ObjectSubType, 
			@CreatedDTS CreatedDate,
			@ModifiedDTS ModifiedDate

-- Columns

	if @ObjectType in ('USER_TABLE','VIEW')
	begin
		Select '******* Columns *******' [Description]
		;

		Select	c.ordinal_position Position,
				c.Column_Name ColumnName,
				upper(case when Data_Type in ('tinyint','smallint','int','bigint','date','time','datetime','datetime2','xml','bit','money','float') then Data_Type
					when CHARACTER_MAXIMUM_LENGTH = -1 then Data_Type + '(max)'
					else Data_Type + '(' + cast(ISNULL(CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION) as varchar(10)) + ISNULL(',' + CAST(numeric_Scale as varchar(10)) + ')',')')
				end) + ' ' + case when c.IS_Nullable = 'YES' then 'NULL' else 'NOT NULL' end DataType,
				case when ic.name is not null then 'Identity' + isnull('(' + cast(ic.seed_value as varchar(4)) + ',' + CAST(ic.increment_value as varchar(4)) + ')', '') else isnull(COLUMN_DEFAULT,'') end [Default],
				isnull(cast(kc.ORDINAL_POSITION as varchar(3)),'') PrimaryKeyField,
				isnull(de.value, '') ColumnDescription
		from	INFORMATION_SCHEMA.COLUMNS c
		left join INFORMATION_SCHEMA.KEY_COLUMN_USAGE kc	on	c.TABLE_NAME = kc.TABLE_NAME
															and c.TABLE_SCHEMA = kc.TABLE_SCHEMA
															and c.COLUMN_NAME = kc.COLUMN_NAME
		left join INFORMATION_SCHEMA.TABLE_CONSTRAINTS cn	on	c.TABLE_NAME = cn.TABLE_NAME
															and c.TABLE_SCHEMA = cn.TABLE_SCHEMA
															and kc.CONSTRAINT_NAME = cn.CONSTRAINT_NAME
															and	cn.CONSTRAINT_TYPE = 'PRIMARY KEY'
		left join sys.extended_properties de				on	de.major_id = @ObjectID
															and COL_NAME (de.major_id, de.minor_id) = c.Column_Name
															and de.name = 'Description'
		left join sys.identity_columns ic					on	ic.object_id = @ObjectID
															and c.COLUMN_NAME = ic.[name]
		where	c.TABLE_SCHEMA = @ObjectSchema
		and		c.TABLE_NAME = @ObjectName
		order by c.ORDINAL_POSITION
		;
	end

-- Indexes

	if @ObjectType in ('USER_TABLE','VIEW')
	begin
		Select '******* Indexes *******' [Description]
		;

		Select	name IndexName,
				case when is_unique = 1 then 'Unique ' else '' end +
				case type_desc when 'CLUSTERED' then 'Clustered ' when 'NONCLUSTERED' then 'Non-Clustered ' end + 
				case when is_primary_key = 1 then 'Primary Key ' else 'Index ' end IndexType,
				STUFF(
					CAST((	Select	', ' + COL_NAME(object_id, column_id) [data()]
							from	[sys].[index_columns]
							where	object_id = i.object_id
							and		index_id = i.index_id
							and		is_included_column = 0
							order by index_id
							For XML path(''), Type
							) as varchar(8000)
					), 1, 2, '') KeyColumns,
						isnull(
							STUFF(
								CAST((	Select	', ' + COL_NAME(object_id, column_id) [data()]
									from	[sys].[index_columns]
									where	object_id = i.object_id
									and		index_id = i.index_id
									and		is_included_column = 1
									order by index_id
									For XML path(''), Type
									) as varchar(8000)
						), 1, 2, '')
					, '') IncludedColumns
		from [sys].[indexes] i
		where	object_id = @ObjectID
		and		index_id > 0
		order by index_id
	end

-- Table File Groups

	if @ObjectType in ('USER_TABLE')
	begin
		Select '******* File Group Usage *******' [Description]
		;

		SELECT	fg.name AS [Filegroup]
				, ceiling(sum(((s.max_record_size_in_bytes * s.record_count) / 1024.00) / 1024.00)) SizeMB
		FROM sys.indexes i  
		JOIN sys.partitions p	ON	i.object_id = p.object_id 
								AND i.index_id = p.index_id
		cross apply sys.dm_db_index_physical_stats (	DB_ID(db_name()), 
													i.object_id, 
													i.index_id, 
													NULL , 
													'DETAILED') s
		LEFT JOIN sys.partition_schemes ps ON i.data_space_id=ps.data_space_id
		LEFT JOIN sys.destination_data_spaces dds ON ps.data_space_id=dds.partition_scheme_id AND p.partition_number=dds.destination_id
		JOIN	sys.filegroups fg ON COALESCE(dds.data_space_id, i.data_space_id)=fg.data_space_id
		where	i.object_id = 1362103893
		and		i.index_id in (0,1)
		group by	fg.name
	end

-- Parameters

	if @ObjectType in ('SQL_STORED_PROCEDURE','SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION','SQL_SCALAR_FUNCTION')
	begin
		Select  '******* Parameters *******' [Description]
		;
		
		Select	PARAMETER_NAME,
				 upper(case when Data_Type in ('tinyint','smallint','int','bigint','date','time','datetime','datetime2','xml','bit','money','float') then Data_Type
						when CHARACTER_MAXIMUM_LENGTH = -1 then Data_Type + '(max)'
						else Data_Type + '(' + cast(ISNULL(CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION) as varchar(10)) + ISNULL(',' + CAST(numeric_Scale as varchar(10)) + ')',')')
					end) DataType,
				PARAMETER_MODE Direction,
				'' Comments
		from	[INFORMATION_SCHEMA].[PARAMETERS]
		where	Specific_SCHEMA = @ObjectSchema
		and		Specific_NAME = @ObjectName
		order by ORDINAL_POSITION
	end

-- Table Function Columns

	if @ObjectType in ('SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION')
	begin
		Select '******* Output Columns *******' [Description]
		;

		Select	COLUMN_NAME,
				 upper(case when Data_Type in ('tinyint','smallint','int','bigint','date','time','datetime','datetime2','xml','bit','money','float') then Data_Type
						when CHARACTER_MAXIMUM_LENGTH = -1 then Data_Type + '(max)'
						else Data_Type + '(' + cast(ISNULL(CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION) as varchar(10)) + ISNULL(',' + CAST(numeric_Scale as varchar(10)) + ')',')')
					end) + case when IS_NULLABLE = 'YES' then ' NULL' else '' end DataType,
				isnull(COLUMN_DEFAULT,'') [Default]
		from	[INFORMATION_SCHEMA].[ROUTINE_COLUMNS]
		where	TABLE_SCHEMA = @ObjectSchema
		and		TABLE_NAME = @ObjectName
		order by ORDINAL_POSITION
	end

-- Sequence

	if @ObjectType in ('SEQUENCE_OBJECT')
	begin
		Select '******* Sequence Parameters *******' [Description]
		;
		
		Select case when Data_Type in ('tinyint','smallint','int','bigint') then Data_Type
					else Data_Type + '(' + cast(NUMERIC_PRECISION as varchar(10)) + ISNULL(',' + CAST(numeric_Scale as varchar(10)) + ')',')')
				end DataType
				, START_VALUE StartType
				, MINIMUM_VALUE MinimumValue
				, MAXIMUM_VALUE MaximumValue
				, INCREMENT Increment
				, CYCLE_OPTION CycleOption
		from	[INFORMATION_SCHEMA].[SEQUENCES]
		where	SEQUENCE_NAME = @ObjectName
		and		SEQUENCE_SCHEMA = @ObjectSchema
	end

-- Trigger Details
	if @ObjectType in ('SQL_TRIGGER')
	begin
		Select '******* Trigger Details *******' [Description]
		;

		Select	case when parent_id = 0 then db_name() else schema_name(o.schema_id) + '.' + OBJECT_NAME(o.object_id) end TriggerObject
				, case	when parent_id = 0 then 'Database'
						when o.[type_desc] = 'USER_TABLE' then 'Table'
						when o.[type_desc] = 'VIEW' then 'View'
						when o.[type_desc] = 'SQL_STORED_PROCEDURE' then 'Stored Procedure'
						when o.[type_desc] = 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'Function - Inline Table'
						when o.[type_desc] = 'SQL_TABLE_VALUED_FUNCTION' then 'Function - Table'
						when o.[type_desc] = 'SQL_SCALAR_FUNCTION' then 'Function - Scalar'
						when o.[type_desc] = 'SYNONYM' then 'Synonym'
						when o.[type_desc] = 'SEQUENCE_OBJECT' then 'Sequence'
						when o.[type_desc] = 'SQL_TRIGGER' then 'Trigger - DML'
					end TriggerObjectType
				, case when is_disabled = 0 then 'Yes' else 'No' end IsEnabled
				, case when is_instead_of_trigger = 1 then 'INSTEAD OF' else 'AFTER' end TriggerType
				, cast((Select type_Desc + ',' [data()] from sys.trigger_events where object_id = t.object_id for xml path(''), Type) as varchar(250)) TriggerEvents
		from	sys.triggers t
		left join	sys.objects o on o.object_id = t.parent_id
		where	t.object_id = @ObjectID
	end 

-- References
	Select '******* Objects referenced by this object *******' [Description]
	;

	With ref as 
	(
		Select	e.referenced_id,
				referenced_database_name,
				referenced_schema_name,
				referenced_Entity_name,
				referenced_Minor_name,
				o.type_desc
		from	sys.dm_sql_referenced_entities(@ObjectSchema + '.' + @ObjectName, 'OBJECT') e
		join	sys.all_objects o on e.referenced_id = o.object_id
	)
	Select	distinct isnull(referenced_database_name + '.','') + referenced_schema_name + '.' + referenced_Entity_name ReferencedItem,
			case when referenced_database_name is not null then 'Yes' else 'No' end CrossDatabase,
			case	[type_desc]		when 'USER_TABLE' then 'Table'
									when 'VIEW' then 'View'
									when 'SQL_STORED_PROCEDURE' then 'Stored Procedure'
									when 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'Function - Inline Table'
									when 'SQL_TABLE_VALUED_FUNCTION' then 'Function - Table'
									when 'SQL_SCALAR_FUNCTION' then 'Function - Scalar'
									when 'SYNONYM' then 'Synonym'
									when 'SEQUENCE_OBJECT' then 'Sequence'
									when 'SQL_TRIGGER' then 'Trigger - DML'
			end	ReferencedObjectType,
			cast((Select referenced_Minor_name + ',' [data()] from ref where referenced_id = a.referenced_id for xml path(''), Type) as varchar(8000)) ReferencedMinor
	from	ref a
	union
	Select	base_object_name,
			case when parsename(base_object_name, 3) <> db_name() then 'Yes' else 'No' end CrossDatabase,
			case	o.[type_desc]	when 'USER_TABLE' then 'Table'
									when 'VIEW' then 'View'
									when 'SQL_STORED_PROCEDURE' then 'Stored Procedure'
									when 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'Function - Inline Table'
									when 'SQL_TABLE_VALUED_FUNCTION' then 'Function - Table'
									when 'SQL_SCALAR_FUNCTION' then 'Function - Scalar'
									when 'SYNONYM' then 'Synonym'
									when 'SEQUENCE_OBJECT' then 'Sequence'
									when 'SQL_TRIGGER' then 'Trigger - DML'
									else ''
			end ReferencedObjectType,
			'' ReferencedMinor
	from	[sys].[synonyms] s
	left join	sys.objects o	on	parsename(base_object_name, 3) = db_name()
								and o.object_id = object_id(parsename(base_object_name, 2) + '.' + parsename(base_object_name, 1))
	where	s.object_id = @ObjectID
	order by ReferencedItem
	;

	Select '******* Objects that reference this object *******' [Description]
	;

	Select	distinct 
			referencing_schema_name + '.' + referencing_Entity_name ReferencingItem
			, o.type_desc
	from	sys.dm_sql_referencing_entities(@ObjectSchema + '.' + @ObjectName, 'OBJECT') e
	left join	sys.all_objects o on e.referencing_id = o.object_id

	Select '******* Objects Permissions *******' [Description]
	;	

	select	pri.name GranteeName,
			per.state_desc GranteeType, 
			per.permission_name PermissionName
	From	sys.objects as p
	join	sys.database_permissions as per on p.object_id = per.major_id
	join	sys.database_principals as pri on per.grantee_principal_id = pri.principal_id
	where	p.object_id = @ObjectID
go
