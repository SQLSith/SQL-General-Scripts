Create   View [ExtendedProperties].[TableOrViewColumns]
as
Select	OBJECT_SCHEMA_NAME(major_id, db_id()) SchemaName,
		object_name(major_id) ObjectName,
		o.type_desc ObjectType,
		c.name ColumnName,
		p.[name] PropertyName,
		p.[value] PropertyValue
from	sys.extended_properties p
join	sys.all_objects o	on	p.major_id = o.object_id
join	sys.all_columns c	on	c.object_id = p.major_id
							and c.column_id = p.minor_id
where	p.class = 1 
and		o.type_desc in ('USER_TABLE','SYSTEM_TABLE','VIEW')
GO
