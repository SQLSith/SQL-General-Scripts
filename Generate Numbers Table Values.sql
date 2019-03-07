/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 05/03/2019

		Description:
		Creates values for populating a numbers table. The number of records being returned can be increased (by a factor of 100) 
		but adding additional cross joins, or reduced by removing cross joins or adding a Top X clause.


*/



; With Numbers as
(
Select	num.CurNum
from (values (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) num (CurNum)
cross join (values (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) num2 (CurNum)
)
Select	--top 50
		row_number() over (order by n1.CurNum) CurrentNumber,
		row_number() over (order by n1.CurNum) - 1 PreviousCurrentNumber,
		row_number() over (order by n1.CurNum) + 1 NextCurrentNumber
from	Numbers n1 -- 100 Records
--cross join Numbers n2 -- 10000 Records
--cross join Numbers n3 -- 1000000 Records