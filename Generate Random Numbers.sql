/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 03/03/2019

		Description:
		Creating random numbers can be useful at times, and the closest function supplier by Microsoft (Rand())
		will generate the same value for every record in the batch. The below code will generate a different value 
		for every record within a predefined range.

*/



	Declare	@MaximumValue int = 100

	select	(abs(cast(cast(newid() as varbinary) as int)) % @MaximumValue) + 1
	from	sys.all_objects

