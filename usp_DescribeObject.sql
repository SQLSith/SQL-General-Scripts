Create or alter procedure usp_DescribeObject (@ObjectNameFull varchar(255))
as
--Declare	@ObjectNameFull varchar(255) = '[Bulltech].[Databases]'

-- Gather Objact Metadata
	Declare	@ObjectName varchar(128),
			@ObjectSchema varchar(128),
			@ObjectID int,
			@SchemaID int,
			@ObjectType varchar(50),
			@CreatedDTS datetime,
			@ModifiedDTS datetime
	;

	Select	@ObjectName = parsename(@ObjectNameFull, 1),
			@ObjectSchema = isnull(parsename(@ObjectNameFull, 2), SCHEMA_NAME()), -- Default to connected users default schema
			@ObjectID = object_id(@ObjectNameFull),
			@SchemaID = schema_id(isnull(parsename(@ObjectNameFull, 2), SCHEMA_NAME()))
		
	Select	@ObjectType = [type_desc],
			@CreatedDTS = create_date,
			@ModifiedDTS = modify_date
	from	sys.objects
	where	OBJECT_ID = @ObjectID

-- Summary Level
	Select 'Object Summary' Description

	if @ObjectType in ('USER_TABLE','VIEW')
	begin
			Select	@ObjectID ObjectID,
					case	@ObjectType		when 'USER_TABLE' then 'Table'
											when 'VIEW' then 'View'
					end	ObjectType,
					@ObjectSchema SchemaName,
					@ObjectName TableName,
					@CreatedDTS CreatedDate,
					@ModifiedDTS ModifiedDate,
					case t.temporal_type	when 0 then 'Non-Temporal Table'
											when 1 then 'History Table for ' + schema_name(s.schema_id) + '.' + OBJECT_NAME(s.object_id)
											when 2 then 'Temporal Table - History Table ' + schema_name(h.schema_id) + '.' + OBJECT_NAME(h.object_id)
					end TemporalType
			from	sys.tables t
			left join sys.tables h	on	h.object_id = t.history_table_id
			left join sys.tables s	on	s.history_table_id = t.object_id
			where	t.object_id = @ObjectID
	end
	else if @ObjectType in ('SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_STORED_PROCEDURE','SQL_TABLE_VALUED_FUNCTION')
	begin
			Select	@ObjectID ObjectID,
					case	@ObjectType		when 'SQL_STORED_PROCEDURE' then 'Stored Procedure'
											when 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'Function - Inline Table'
											when 'SQL_TABLE_VALUED_FUNCTION' then 'Function - Table'
											when 'SQL_SCALAR_FUNCTION' then 'Function - Scalar'
					end	ObjectType,
					@ObjectSchema SchemaName,
					@ObjectName TableName,
					@CreatedDTS CreatedDate,
					@ModifiedDTS ModifiedDate
	end

-- Tables and Views

	if @ObjectType in ('USER_TABLE','VIEW')
	begin


		Select 'Columns' Description

		Select	c.ordinal_position Position,
				c.Column_Name ColumnName,
				upper(case when Data_Type in ('tinyint','smallint','int','bigint','date','time','datetime','datetime2','xml','bit','money','float') then Data_Type
					when CHARACTER_MAXIMUM_LENGTH = -1 then Data_Type + '(max)'
					else Data_Type + '(' + cast(ISNULL(CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION) as varchar(10)) + ISNULL(',' + CAST(numeric_Scale as varchar(10)) + ')',')')
				end) + ' ' + case when c.IS_Nullable = 'YES' then 'NULL' else 'NOT NULL' end DataType,
				case when ic.name is not null then 'Identity' + isnull('(' + cast(ic.seed_value as varchar(4)) + ',' + CAST(ic.increment_value as varchar(4)) + ')', '') else isnull(COLUMN_DEFAULT,'') end [Default],
				isnull(cast(kc.ORDINAL_POSITION as varchar(3)),'') PrimaryKeyField,
				isnull(de.value, '') Comments
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




		Select 'Indexes' Description

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
		and		index_id >0
		order by index_id
	end




-- References
	Select 'Objects referenced by this object' Description
	;

	Select	distinct 
			isnull(referenced_database_name + '.','') + referenced_schema_name + '.' + referenced_Entity_name ReferencedItem,
			case when referenced_database_name is not null then 'Yes' else 'No' end CrossDatabase
			, o.type_desc
	from	sys.dm_sql_referenced_entities(@ObjectSchema + '.' + @ObjectName, 'OBJECT') e
	left join	sys.all_objects o on e.referenced_id = o.object_id
	;

	Select 'Objects that reference this object' Description
	;

	Select	distinct 
			referencing_schema_name + '.' + referencing_Entity_name ReferencingItem
			, o.type_desc
	from	sys.dm_sql_referencing_entities(@ObjectSchema + '.' + @ObjectName, 'OBJECT') e
	left join	sys.all_objects o on e.referencing_id = o.object_id

go

exec usp_DescribeObject '[Bulltech].[Databases]'
--exec usp_DescribeObject '[Bulltech].[usp_Maintain_Database]'
--exec usp_DescribeObject '[Bulltech].[ufn_Get_DatabaseRoleMembership]'

SELECT * from [INFORMATION_SCHEMA].[PARAMETERS]