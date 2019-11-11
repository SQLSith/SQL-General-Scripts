/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 10/11/2019

		Description:
		This script creates test data for use with the K-means and k-median data clustering demos. 
		The intention is to create a set of X,Y data points in the range of 0 to 100 on each axis. 
		The data points are allocated such that there are 6 dense clusters and a small number of random
		outliers.


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


-- Cluster in 0-20, 80-100 region
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, rand(checksum(newID())) * 20
			, 80 + rand(checksum(newID())) * 20
			, 1
	go 500 

-- Cluster in 10-30, 10-30 region
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, 10 + rand(checksum(newID())) * 20
			, 10 + rand(checksum(newID())) * 20
			, 2
	go 500 

-- Cluster in 30-50, 60-80 region
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, 30 + rand(checksum(newID())) * 20
			, 60 + rand(checksum(newID())) * 20
			, 3
	go 500 

-- Cluster in 60-80, 80-100 region
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, 60 + rand(checksum(newID())) * 20
			, 80 + rand(checksum(newID())) * 20
			, 4
	go 500 

-- Cluster in 70-90, 30-50 region
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, 70 + rand(checksum(newID())) * 20
			, 30 + rand(checksum(newID())) * 20
			, 5
	go 500 

-- Cluster in 80-100, 60-80 region
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, 80 + rand(checksum(newID())) * 20
			, 60 + rand(checksum(newID())) * 20
			, 6
	go 500 

-- Add Noise
/* 
	insert	dbo.Events (GroupID, EventNumberX, EventNumberY, ExpectedCluster)
	Select	1
			, rand(checksum(newID())) * 100
			, rand(checksum(newID())) * 100
			, 0
	go 10
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


