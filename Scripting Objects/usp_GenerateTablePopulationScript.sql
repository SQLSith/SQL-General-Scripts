Create   proc [dbo].[usp_GenerateTablePopulationScript] (@TableName varchar(255))
as
	/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 29/02/2019

		Description:
		Whilst there are a lot of tools for source controlling and promoting code, 
		it is much more difficult to do the same with reference data. This procedure 
		generates a script which builds a table variable representing the named table, and 
		scripts inserts based on the data in that table. If the named table has a primary key
		then a Merge statement is generated too to maintain that table based on the 
		data in the table variable. The generated scripts can be source controlled and,
		if a merge statement is included, run as post deployment script to maintain reference
		data.

		Usage:
		exec [dbo].[usp_GenerateTablePopulationScript] '[SchemaName].[TableName]'

	*/
	
	Set nocount on
	;

	Declare @SQLCreateTableVar nvarchar(max)
	Declare @SQLInsert nvarchar(max)
	Declare @SQLGetValues nvarchar(max)
	Declare @SQLValues nvarchar(max)
	Declare	@SQLMerge nvarchar(max)
	Declare @SQLIdentInsertON varchar(1000)
	Declare @SQLIdentInsertOFF varchar(1000)
	Declare @InsertStatements table (SQLInsert nvarchar(max))
	Declare @HasIdentity bit

	Declare	@Metadata table
	(
	ColumnName varchar(128),
	ORDINALPOSITION smallint,
	BaseType	varchar(50),
	DeclareScript varchar(500),
	KeyPosition tinyint,
	NonKeyPosition tinyint,
	IsIdentity bit,
	SuppressInsert bit
	)

-- Identify table Metadata

	insert @Metadata (ColumnName, ORDINALPOSITION, BaseType, DeclareScript, KeyPosition, NonKeyPosition, IsIdentity, SuppressInsert)
	Select	c.Column_Name,
			c.ORDINAL_POSITION,
			data_Type BaseType,
			case when c.ORDINAL_POSITION > 1 then char(10) + ',' else '' end
			+ quotename(c.Column_Name) + ' ' 
				+ data_Type + case	when data_Type in ('tinyint','smallint','int','bigint','date','smalldatetime','datetime','datetime2','bit','time','text') then ''
					else '(' + cast(isnull(Character_Maximum_length, Numeric_Precision) as varchar(10)) + isnull(',' + cast(Numeric_Scale as varchar(10)) + ')',')')
				end
				+ case when Is_Nullable = 'NO' then ' NOT NULL' else ' NULL' end,
			case when tc.CONSTRAINT_TYPE = 'Primary Key' then kc.ORDINAL_POSITION else null end KeyPosition,
			case when isnull(tc.CONSTRAINT_TYPE,'') != 'Primary Key' then Rank() over (partition by case when isnull(tc.CONSTRAINT_TYPE,'') != 'Primary Key' then 1 else 2 end order by c.ORDINAL_POSITION) else null end NonKeyPosition,
			COLUMNPROPERTY( OBJECT_ID(@TableName),c.Column_Name,'IsIdentity') IsIdentity, 
			case when	COLUMNPROPERTY( OBJECT_ID(@TableName),c.Column_Name,'IsComputed') = 1
					then 1
					else 0
			end SuppressInsert
	from	INFORMATION_SCHEMA.columns c
	left join	INFORMATION_SCHEMA.KEY_COLUMN_USAGE kc	on	c.TABLE_CATALOG = kc.TABLE_CATALOG
						AND	c.TABLE_SCHEMA = kc.TABLE_SCHEMA
						AND	c.TABLE_NAME = kc.TABLE_NAME
						AND	c.COLUMN_NAME = kc.COLUMN_NAME
	left join	INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc	ON	tc.CONSTRAINT_NAME = kc.CONSTRAINT_NAME							
	where	c.table_name =  parsename(@TableName, 1)
	and		c.TABLE_SCHEMA = parsename(@TableName, 2)
	;

-- Identify whether there is an identity field
	Select	@HasIdentity = case when exists (Select * from @Metadata where IsIdentity = 1) then 1 else 0 end

	if 	@HasIdentity = 1
	begin
		Select	@SQLIdentInsertON = 'SET IDENTITY_INSERT ' + + QUOTENAME(parsename(@TableName, 2)) + '.' + QUOTENAME(parsename(@TableName, 1)) + ' ON;',
				@SQLIdentInsertOFF = 'SET IDENTITY_INSERT ' + + QUOTENAME(parsename(@TableName, 2)) + '.' + QUOTENAME(parsename(@TableName, 1)) + ' OFF;'
	end 

-- Generate Table variable creation

	Select	@SQLCreateTableVar = 'Declare @Source table (' + char(10)
		+ cast((Select DeclareScript [data()] from @Metadata order by ORDINALPOSITION for XML path(''), type) as varchar(max))
		+ case when exists (Select * from @Metadata where KeyPosition is not null) 
			then char(10) + ', Primary Key Clustered (' + cast((Select case when KeyPosition > 1 then char(10) + ', ' else '' end + quotename(ColumnName) [data()] from @Metadata where KeyPosition is not null order by KeyPosition for XML path(''), type) as varchar(max)) + ')'
			else ''
		  end 
		+ ');'

-- Create insert fields statement
	
	Select @SQLInsert = 'Insert @Source (' + cast((Select case when ORDINALPOSITION > 1 then ', ' else '' end + quotename(ColumnName) [data()] from @Metadata where SuppressInsert = 0 order by ORDINALPOSITION for XML path(''), type) as varchar(max)) + ')'

-- Generate a query which will build a values list
	Select @SQLGetValues = 'Select ' + quotename('Values (', CHAR(39)) + ' + '
							+ cast((Select	case when ORDINALPOSITION > 1 then char(10) + ' + '','' + ' else '' end 
												+ 'case when ' + quotename(ColumnName) + ' is null then ''NULL'' else ' + 
														case	when BaseType in ('datetime','datetime2') then 'quotename(convert(varchar, ' + quotename(ColumnName) + ', 121), char(39))'
																else 'quotename(cast(' + quotename(ColumnName) + ' as varchar(max)), char(39))'
														end
														+ ' end'
											[data()] 
									from @Metadata 
									where SuppressInsert = 0 
									order by ORDINALPOSITION 
									for XML path(''), type
								) as varchar(max)
								)
							+ ' + ' + quotename(')', CHAR(39))
							+ char(10) + 'From ' + QUOTENAME(parsename(@TableName, 2)) + '.' + QUOTENAME(parsename(@TableName, 1))

-- Capture values lists for each table

	insert	@InsertStatements
	exec	sp_executesql @SQLGetValues

-- convert insert and values lists in to a string
	
	Select	@SQLValues = cast((Select	@SQLInsert + ' ' + SQLInsert + ';' +  CHAR(10) [data()] 
								from	@InsertStatements 
								For XML path(''), type)
							as nvarchar(max))
	

-- Generate Merge Statement

	Select	@SQLMerge = 'Merge ' + QUOTENAME(parsename(@TableName, 2)) + '.' + QUOTENAME(parsename(@TableName, 1)) + ' as tgt' 
							+ CHAR(10) + 'using @Source as src'
							+ CHAR(10) + char(9) + 'ON ' + cast((Select case when KeyPosition > 1 then char(10) + 'and ' else '' end + 'tgt.' + quotename(ColumnName) + ' = src.' + quotename(ColumnName) [data()] from @Metadata where KeyPosition is not null order by KeyPosition for XML path(''), type) as varchar(max))
							+ CHAR(10) + 'WHEN Matched and (' + cast((Select case when NonKeyPosition > 1 then char(10) + char(9) + 'or ' else '' end + 'tgt.' + quotename(ColumnName) + ' != src.' + quotename(ColumnName) [data()] from @Metadata where KeyPosition is null order by ORDINALPOSITION for XML path(''), type) as varchar(max)) + ')'
							+ CHAR(10) + 'Then Update Set ' + cast((Select case when NonKeyPosition > 1 then char(10) + char(9) + ', ' else '' end + 'tgt.' + quotename(ColumnName) + ' = src.' + quotename(ColumnName) [data()] from @Metadata where KeyPosition is null order by ORDINALPOSITION for XML path(''), type) as varchar(max))
							+ CHAR(10) + 'When Not Matched By Source then Delete'
							+ CHAR(10) + 'WHEN NOT MATCHED BY TARGET THEN'
							+ CHAR(10) + char(9) + 'Insert (' + cast((Select case when ORDINALPOSITION > 1 then ', ' else '' end + quotename(ColumnName) [data()] from @Metadata where SuppressInsert = 0 order by ORDINALPOSITION for XML path(''), type) as varchar(max)) + ')'
							+ CHAR(10) + char(9) + 'values (' + cast((Select case when ORDINALPOSITION > 1 then ', ' else '' end + 'src. ' + quotename(ColumnName) [data()] from @Metadata where SuppressInsert = 0 order by ORDINALPOSITION for XML path(''), type) as varchar(max)) + ')'
							+ CHAR(10) + ';'
	
	
-- Print statements
	print @SQLCreateTableVar
	print ''
	print @SQLValues
	print ''
	if 	@HasIdentity = 1
	begin
		print @SQLIdentInsertON
		print ''
	end
	Print @SQLMerge
	if 	@HasIdentity = 1
	begin
		print ''
		print @SQLIdentInsertOFF
	end