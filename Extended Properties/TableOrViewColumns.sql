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



CREATE  Trigger [ExtendedProperties].[TableOrViewColumnsAdd]
	on [ExtendedProperties].TableOrViewColumns
	Instead of Insert
	as
		/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 16/06/2019
		Description:
		Extend Properties can be very useful for self documenting databases, but also to drive automated processes.
		Unfortunately viewing and manipulating them is far from user friendly. This is the first of a number of scripts
		which present extended properties as views, with triggers allowing changes to be applied directly to the view.
		*/

		Set Nocount on
		;

		Declare	@RowCount int,
				@RowCurrent int = 1,
				@ObjectID bigint,
				@ObjectType0 varchar(100) = 'Schema',
				@ObjectType1 varchar(100),
				@ObjectType2 varchar(100) = 'Column',
				@value sql_variant,
				@Name nvarchar(128),
				@ObjectTypeName0 nvarchar(128),
				@ObjectTypeName1 nvarchar(128),
				@ObjectTypeName2 nvarchar(128)

		Declare	@Rows table 
		(
			RowID int identity(1,1),
			SchemaName nvarchar(128),
			ObjectName nvarchar(128),
			ColumnName nvarchar(128),
			ObjectID bigint,
			ObjectType varchar(50),
			[name] nvarchar(128),
			[value] sql_variant
		)

		insert	@Rows (SchemaName, ObjectName, ColumnName, [name], [value])
		Select	SchemaName, 
				ObjectName, 
				ColumnName,
				[PropertyName], 
				[PropertyValue]
		from	Inserted
		;

		Update	r
		Set		ObjectID = o.object_id,
				ObjectType = case when [type_Desc] in ('USER_TABLE','SYSTEM_TABLE') then 'TABLE'
										when [type_Desc] in ('VIEW','SYNONYM') then [type_Desc]
									end
		from	@Rows r
		join	sys.objects	o	on	r.ObjectName = o.name
								and o.schema_id = schema_id(r.SchemaName)

		Select	@RowCount = @@Rowcount
		;

		if @RowCount = 0
			Return
		;

		while @RowCurrent <= @RowCount
		begin

			Select	@ObjectTypeName0 = [SchemaName],
					@ObjectType1 = ObjectType,
					@ObjectTypeName1 = [ObjectName],
					@ObjectTypeName2 = ColumnName,
					@Name = [name],
					@value = [value]
			from	@Rows
			where	RowID = @RowCurrent
			;	


			EXEC	sys.sp_addextendedproperty  @name=@Name, 
												@value=@value, 
												@level0type=@ObjectType0,
												@level0name=@ObjectTypeName0, 
												@level1type=@ObjectType1,
												@level1name=@ObjectTypeName1, 
												@level2type=@ObjectType2,
												@level2name=@ObjectTypeName2
			;

			Select	@RowCurrent = @RowCurrent + 1
			;

		end

	GO
