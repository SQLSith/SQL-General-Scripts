/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 16/06/2019

		Description:
		Extend Properties can be very useful for self documenting databases, but also to drive automated processes.
		Unfortunately viewing and manipulating them is far from user friendly. This is the first of a number of scripts
		which present extended properties as views, with triggers allowing changes to be applied directly to the view.

		Usage:
		exec [dbo].[usp_GenerateTablePopulationScript] '[SchemaName].[TableName]'

	*/

-- Create Schema if not present
	if not exists (Select * from information_Schema.SCHEMATA where Schema_name = 'ExtendedProperties')
		exec('Create Schema ExtendedProperties')
	go

-- Create View representing database objects
	Create   View [ExtendedProperties].[DatabaseObjects]
	as
	Select	OBJECT_SCHEMA_NAME(major_id, db_id()) SchemaName,
			object_name(major_id) ObjectName,
			o.type_desc ObjectType,
			p.[name] PropertyName,
			p.[value] PropertyValue
	from	sys.extended_properties p
	join	sys.all_objects o	on	p.major_id = o.object_id
	where	class = 1 
	and		minor_id = 0
	and		o.type_desc in ('USER_TABLE','SYSTEM_TABLE','VIEW','SYNONYM','EXTENDED_STORED_PROCEDURE','SQL_STORED_PROCEDURE','SQL_SCALAR_FUNCTION','SQL_TABLE_VALUED_FUNCTION','SQL_INLINE_TABLE_VALUED_FUNCTION')
	GO



-- Create Trigger of inserts

	CREATE  Trigger [ExtendedProperties].[EPDatabaseObjectsAdd]
	on [ExtendedProperties].[DatabaseObjects]
	Instead of Insert
	as

		Declare	@RowCount int,
				@RowCurrent int = 1,
				@ObjectID bigint,
				@ObjectType0 varchar(100) = 'Schema',
				@ObjectType1 varchar(100),
				@value sql_variant,
				@Name nvarchar(128),
				@ObjectTypeName0 nvarchar(128),
				@ObjectTypeName1 nvarchar(128)

		Declare	@Rows table 
		(
			RowID int identity(1,1),
			SchemaName nvarchar(128),
			ObjectName nvarchar(128),
			ObjectID bigint,
			ObjectType varchar(50),
			[name] nvarchar(128),
			[value] sql_variant
		)

		insert	@Rows (SchemaName, ObjectName, [name], [value])
		Select	SchemaName, 
				ObjectName, 
				[PropertyName], 
				[PropertyValue]
		from	Inserted
		;

		Update	r
		Set		ObjectID = o.object_id,
				ObjectType = case when [type_Desc] in ('USER_TABLE','SYSTEM_TABLE') then 'TABLE'
										when [type_Desc] in ('VIEW','SYNONYM') then [type_Desc]
										when [type_Desc] in ('EXTENDED_STORED_PROCEDURE','SQL_STORED_PROCEDURE') then 'Procedure'
										when [type_Desc] in ('SQL_SCALAR_FUNCTION','SQL_TABLE_VALUED_FUNCTION','SQL_INLINE_TABLE_VALUED_FUNCTION') then 'Function'
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
												@level1name=@ObjectTypeName1
			;

			Select	@RowCurrent = @RowCurrent + 1
			;

		end

	GO


-- Create Trigger for Updates

	Create  Trigger [ExtendedProperties].[EPDatabaseObjectsUpdate]
	on [ExtendedProperties].[DatabaseObjects]
	Instead of Update
	as

		Declare	@RowCount int,
				@RowCurrent int = 1,
				@ObjectID bigint,
				@ObjectType0 varchar(100) = 'Schema',
				@ObjectType1 varchar(100),
				@value sql_variant,
				@Name nvarchar(128),
				@ObjectTypeName0 nvarchar(128),
				@ObjectTypeName1 nvarchar(128)

		Declare	@Rows table 
		(
			RowID int identity(1,1),
			SchemaName nvarchar(128),
			ObjectName nvarchar(128),
			ObjectID bigint,
			ObjectType varchar(50),
			[name] nvarchar(128),
			[value] sql_variant
		)

		insert	@Rows (SchemaName, ObjectName, [name], [value])
		Select	SchemaName, 
				ObjectName, 
				[PropertyName], 
				[PropertyValue]
		from	Inserted
		;

		Update	r
		Set		ObjectID = o.object_id,
				ObjectType = case when [type_Desc] in ('USER_TABLE','SYSTEM_TABLE') then 'TABLE'
										when [type_Desc] in ('VIEW','SYNONYM') then [type_Desc]
										when [type_Desc] in ('EXTENDED_STORED_PROCEDURE','SQL_STORED_PROCEDURE') then 'Procedure'
										when [type_Desc] in ('SQL_SCALAR_FUNCTION','SQL_TABLE_VALUED_FUNCTION','SQL_INLINE_TABLE_VALUED_FUNCTION') then 'Function'
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
					@Name = [name],
					@value = [value]
			from	@Rows
			where	RowID = @RowCurrent
			;	


			EXEC	sys.sp_updateextendedproperty  @name=@Name, 
												@value=@value, 
												@level0type=@ObjectType0,
												@level0name=@ObjectTypeName0, 
												@level1type=@ObjectType1,
												@level1name=@ObjectTypeName1
			;

			Select	@RowCurrent = @RowCurrent + 1
			;

		end

	GO




-- Create Trigger for Deletes

	CREATE  Trigger [ExtendedProperties].[EPDatabaseObjectsDrop]
	on [ExtendedProperties].[DatabaseObjects]
	Instead of Delete
	as

		Declare	@RowCount int,
				@RowCurrent int = 1,
				@ObjectID bigint,
				@ObjectType0 varchar(100) = 'Schema',
				@ObjectType1 varchar(100),
				@Name nvarchar(128),
				@ObjectTypeName0 nvarchar(128),
				@ObjectTypeName1 nvarchar(128)

		Declare	@Rows table 
		(
			RowID int identity(1,1),
			SchemaName nvarchar(128),
			ObjectName nvarchar(128),
			ObjectID bigint,
			ObjectType varchar(50),
			[name] nvarchar(128),
			[value] sql_variant
		)

		insert	@Rows (SchemaName, ObjectName, [name], [value])
		Select	SchemaName, 
				ObjectName, 
				[PropertyName], 
				[PropertyValue]
		from	Deleted
		;

		Update	r
		Set		ObjectID = o.object_id,
				ObjectType = case when [type_Desc] in ('USER_TABLE','SYSTEM_TABLE') then 'TABLE'
										when [type_Desc] in ('VIEW','SYNONYM') then [type_Desc]
										when [type_Desc] in ('EXTENDED_STORED_PROCEDURE','SQL_STORED_PROCEDURE') then 'Procedure'
										when [type_Desc] in ('SQL_SCALAR_FUNCTION','SQL_TABLE_VALUED_FUNCTION','SQL_INLINE_TABLE_VALUED_FUNCTION') then 'Function'
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
					@Name = [name]
			from	@Rows
			where	RowID = @RowCurrent
			;	


			EXEC	sys.sp_dropextendedproperty  @name=@Name, 
												@level0type=@ObjectType0,
												@level0name=@ObjectTypeName0, 
												@level1type=@ObjectType1,
												@level1name=@ObjectTypeName1
			;

			Select	@RowCurrent = @RowCurrent + 1
			;

		end

	GO



