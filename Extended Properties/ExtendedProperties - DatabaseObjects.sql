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
	;

-- Create View representing database objects




-- Create Trigger of inserts




-- Create Trigger for Updates




-- Create Trigger for Deletes



