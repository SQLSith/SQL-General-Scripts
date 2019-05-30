Create or alter   proc dbo.usp_GenerateDBDiagramFromDatabase 
as
	/*
		Author: Jonathan Bairstow
		Created: 13/05/2019
		Description:
		Creates table definitions compatible with https://dbdiagram.io/ database diagrams
		for the current database

		Usage:
		exec [dbo].[usp_GenerateDBDiagramFromDatabase] 
	*/


Set nocount on
;

Declare	@TableName sysname,
		@SchemaName sysname,
		@SQLCreateTableVar varchar(max),
		@KeyDefinition varchar(max)

Declare	@Metadata table
	(
	ColumnName varchar(128),
	ORDINALPOSITION smallint,
	DeclareScript varchar(500),
	KeyPosition tinyint
	)

-- Tables

	Declare		tables Cursor local forward_only
	for
	Select name TableName, schema_name(schema_id) SchemaName
	from sys.tables

	Open tables

	Fetch next from tables into @TableName, @SchemaName

	while @@Fetch_Status = 0
	begin
	
		Delete	@Metadata
		;

		insert @Metadata (ColumnName, ORDINALPOSITION, DeclareScript, KeyPosition)
		Select	c.Column_Name,
				c.ORDINAL_POSITION,
				case when c.ORDINAL_POSITION > 1 then char(10) else '' end
				+ c.Column_Name + ' ' 
					+ data_Type + case	when data_Type in ('tinyint','smallint','int','bigint','date','smalldatetime','datetime','datetime2','bit','time','text') then ''
						else '(' + cast(isnull(Character_Maximum_length, Numeric_Precision) as varchar(10)) + isnull(',' + cast(Numeric_Scale as varchar(10)) + ')',')')
					end
					+ case when Is_Nullable = 'NO' then ' [NOT NULL]' else ' [NULL]' end,
				case when tc.CONSTRAINT_TYPE = 'Primary Key' then kc.ORDINAL_POSITION else null end KeyPosition		
		from	INFORMATION_SCHEMA.columns c
		left join	INFORMATION_SCHEMA.KEY_COLUMN_USAGE kc	on	c.TABLE_CATALOG = kc.TABLE_CATALOG
							AND	c.TABLE_SCHEMA = kc.TABLE_SCHEMA
							AND	c.TABLE_NAME = kc.TABLE_NAME
							AND	c.COLUMN_NAME = kc.COLUMN_NAME
		left join	INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc	ON	tc.CONSTRAINT_NAME = kc.CONSTRAINT_NAME							
		where	c.table_name =  @TableName
		and		c.TABLE_SCHEMA = @SchemaName

		Select	@SQLCreateTableVar = 'Table "' + @SchemaName + '.' + @TableName + '" {' + char(10)
			+ cast((Select rtrim(DeclareScript) from @Metadata order by ORDINALPOSITION for XML path(''), type) as varchar(max))
			+ char(10) + '}' + char(10)

		print @SQLCreateTableVar
		;



		Fetch next from tables into @TableName, @SchemaName
	end

	Close tables
	Deallocate tables

-- Foreign Keys

	Declare		keys Cursor local forward_only
	for 
	SELECT  'Ref: "' + Schema_name(tab2.schema_id) + '.' + tab2.name  + '"."' + col2.name + '" < "'  + Schema_name(tab1.schema_id) + '.' + tab1.name  + '"."' + col1.name + '"'
	FROM sys.foreign_key_columns fkc
	JOIN sys.objects obj	ON	obj.object_id = fkc.constraint_object_id
	JOIN sys.tables tab1	ON	tab1.object_id = fkc.parent_object_id
	JOIN sys.columns col1	ON	col1.column_id = parent_column_id 
							AND col1.object_id = tab1.object_id
	JOIN sys.tables tab2	ON	tab2.object_id = fkc.referenced_object_id
	JOIN sys.columns col2	ON	col2.column_id = referenced_column_id 
							AND col2.object_id = tab2.object_id

	open keys

	Fetch next from keys into @KeyDefinition

	while @@FETCH_STATUS = 0
	begin

		Print @KeyDefinition + char(10)
		;

		Fetch next from keys into @KeyDefinition

	end 
