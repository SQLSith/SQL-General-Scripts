Create   proc [dbo].[usp_GenerateTableVariableFromTable] (@TableName varchar(255))
as
	/*
		Author: Jonathan Bairstow
		Created: 05/03/2019

		Description:
		Creates a table variable definition to match a source table. This is useful when writing staging procedures with
		table value type inputs.

		Usage:
		exec [dbo].[usp_GenerateTableVariableFromTable] '[SchemaName].[TableName]'

	*/

	Set nocount on
	;


	Declare @SQLCreateTableVar varchar(max)

	Declare	@Metadata table
	(
	ColumnName varchar(128),
	ORDINALPOSITION smallint,
	DeclareScript varchar(500),
	KeyPosition tinyint
	)

	insert @Metadata (ColumnName, ORDINALPOSITION, DeclareScript, KeyPosition)
	Select	c.Column_Name,
			c.ORDINAL_POSITION,
			case when c.ORDINAL_POSITION > 1 then char(10) + ',' else '' end
			+ quotename(c.Column_Name) + ' ' 
				+ data_Type + case	when data_Type in ('tinyint','smallint','int','bigint','date','smalldatetime','datetime','datetime2','bit','time','text') then ''
					else '(' + cast(isnull(Character_Maximum_length, Numeric_Precision) as varchar(10)) + isnull(',' + cast(Numeric_Scale as varchar(10)) + ')',')')
				end
				+ case when Is_Nullable = 'NO' then ' NOT NULL' else ' NULL' end,
			case when tc.CONSTRAINT_TYPE = 'Primary Key' then kc.ORDINAL_POSITION else null end KeyPosition		
	from	INFORMATION_SCHEMA.columns c
	left join	INFORMATION_SCHEMA.KEY_COLUMN_USAGE kc	on	c.TABLE_CATALOG = kc.TABLE_CATALOG
						AND	c.TABLE_SCHEMA = kc.TABLE_SCHEMA
						AND	c.TABLE_NAME = kc.TABLE_NAME
						AND	c.COLUMN_NAME = kc.COLUMN_NAME
	left join	INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc	ON	tc.CONSTRAINT_NAME = kc.CONSTRAINT_NAME							
	where	c.table_name =  parsename(@TableName, 1)
	and		c.TABLE_SCHEMA = parsename(@TableName, 2)

	Select	@SQLCreateTableVar = 'Declare @Source table (' + char(10)
		+ cast((Select DeclareScript [data()] from @Metadata order by ORDINALPOSITION for XML path(''), type) as varchar(max))
		+ case when exists (Select * from @Metadata where KeyPosition is not null) 
			then char(10) + ', Primary Key Clustered (' + cast((Select case when KeyPosition > 1 then char(10) + ', ' else '' end + quotename(ColumnName) [data()] from @Metadata where KeyPosition is not null order by KeyPosition for XML path(''), type) as varchar(max)) + ')'
			else ''
		  end 
		+ ')'

	print @SQLCreateTableVar
GO


