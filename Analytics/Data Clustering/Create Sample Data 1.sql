/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 10/11/2019

		Description:
		This script creates test data for use with the K-means and k-median data clustering demos. 
		This data is designed to stress/performance test a clustering process rather than mimicking real world data.
		The intention is to create a set of X,Y data points in the range of 0 to 100 on each axis. 
		The data points are allocated to 4 narrowly seperated quadrants, creating 4 distinct clusters.
		The data is separated in to 3 groups, allowing 50k (GroupID 1), 500k (GroupID 1&2) and 
		5 million (GroupID 1,2&3) data points. 

*/




Set nocount on
go


/* Create Events table */
	Drop table if exists dbo.Events

	Create table dbo.Events
	(
	EventID	int identity(1,1) primary Key,
	GroupID	int,
	EventNumberX	decimal(9,6),
	EventNumberY	decimal(9,6),
	EventPoint Geometry,
	ExpectedCluster int,
	ClosestCentroid	int,
	ClosestCentroidDist decimal(9,6)
	)
	go

	Create spatial index SInd0 on dbo.Events (EventPoint) WITH ( BOUNDING_BOX = ( 0, 0, 100, 100 ) )
	go


-- Quadrant 1
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, rand(checksum(newID())) * 45
			, rand(checksum(newID())) * 45
			, 1
	go 10000 

/* -- Uncomment this section to create group 2 
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	2
			, rand(checksum(newID())) * 45
			, rand(checksum(newID())) * 45
			, 1
	go 90000 
*/

/* -- Uncomment this section to create group 3
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	3
			, rand(checksum(newID())) * 45
			, rand(checksum(newID())) * 45
			, 1
	go 900000 
*/


-- Quadrant 2
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, 55 + rand(checksum(newID())) * 45
			, rand(checksum(newID())) * 45
			, 2
	go 15000 

/* -- Uncomment this section to create group 2 
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	2
			, 55 + rand(checksum(newID())) * 45
			, rand(checksum(newID())) * 45
			, 2
	go 135000
*/

/* -- Uncomment this section to create group 3
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	3
			, 55 + rand(checksum(newID())) * 45
			, rand(checksum(newID())) * 45
			, 2
	go 1350000 
*/

-- Quadrant 3
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, 55 + rand(checksum(newID())) * 45
			, 55 + rand(checksum(newID())) * 45
			, 3
	go 12500 

/* -- Uncomment this section to create group 2 
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	2
			, 55 + rand(checksum(newID())) * 45
			, 55 + rand(checksum(newID())) * 45
			, 3
	go 112500 
*/

/* -- Uncomment this section to create group 3
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	3
			, 55 + rand(checksum(newID())) * 45
			, 55 + rand(checksum(newID())) * 45
			, 3
	go 1125000 
*/

-- Quadrant 4
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, rand(checksum(newID())) * 45
			, 55 + rand(checksum(newID())) * 45
			, 4
	go 12500 

/* -- Uncomment this section to create group 2 
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	2
			, rand(checksum(newID())) * 45
			, 55 + rand(checksum(newID())) * 45
			, 4
	go 112500 
*/

/* -- Uncomment this section to create group 3
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	3
			, rand(checksum(newID())) * 45
			, 55 + rand(checksum(newID())) * 45
			, 4
	go 1125000 
*/

-- calculate geometric data point
	Update	dbo.Events
	Set		EventPoint = geometry::Point(EventNumberX, EventNumberY, 0)
	go

-- Visualise data points
	Select	top 5000
			EventPoint
	from	dbo.Events
	order by newid()