/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 10/11/2019

		Description:
		This script demostrates k-means clustering using standard SQL and batch processing.

		This demo is designed to work with sample data create with 'Create Sample Data 1.sql'


*/

Set nocount on
go

/* Reset Event data from previous clustering runs  */

	Update	dbo.Events
	Set		[ClosestCentroid] = null,
			[ClosestCentroidDist] = null
	go

/* Create the tables required for the clustering */
	Drop table if exists dbo.Centroid

	Create table dbo.Centroid
	(
	CentroidID int identity(1,1),
	CentroidX	decimal(9,6),
	CentroidY	decimal(9,6)
	)
	go

	Drop table if exists dbo.CentroidAssignment

	Create table dbo.CentroidAssignment
	(
	EventID	int,
	CentroidID int,
	CentroidDistance decimal(9,6),
	CentroidPriority int,
	Primary key (EventID, CentroidID, CentroidPriority)
	)
	go



/* Randomly place 4 data points to be our starting points for cluster centers */

	insert	dbo.Centroid (CentroidX, CentroidY)
	Select	min(EventNumberX) + (rand(checksum(newID())) * (max(EventNumberX) - min(EventNumberX))),
			min(EventNumberY) + (rand(checksum(newID())) * (max(EventNumberY) - min(EventNumberY)))
	from dbo.Events
	go 4




/* Create process variables anc configurations */
	Declare @MaximumIterations int = 10, -- How many iterations to perform. Decreasing this number
										-- will cap the number of iterations that are attempted. 
										-- The lower the number; the faster the completion but the lower the accuracy.
										-- The higher the number; the longer the process may run, but teh higher the potential accuracy.

			@Iteration int = 0,			-- The iteration counter

			@Unchanged bit = 0			-- Whether or not the cluster centres have moved since the prior iteration.

	-- Table variable to hold the position of the cluster centres from the prior iteration
	Declare @PreviousCentroids table (CentroidID int, CentroidX	decimal(9,6),CentroidY	decimal(9,6))


/* Refine the location of the cluster centres. This is an iterative process which involves identifying the closest
   cluster centre for each event, and then moving the cluster to the average location of all linked events.
   The process continues until the maximum number of iterations have been performed, or no refinements were made by 
   the latest iteration.
*/


	While @Iteration <= @MaximumIterations and @Unchanged = 0
	begin

		Select @Iteration = @Iteration + 1

	-- Identify the distance of each event from each cluster centre.
		insert	dbo.CentroidAssignment
		Select	e.EventID, 
				c.CentroidID, 
				sqrt(square(EventNumberX - CentroidX) + square(EventNumberY - CentroidY)),
				row_number() over (partition by EventID order by sqrt(square(EventNumberX - CentroidX) + square(EventNumberY - CentroidY))) rw
		from	dbo.Events e
		cross join	dbo.Centroid c

	-- Assign each event to its closest cluster centre
		Update e
		Set		ClosestCentroid = a.CentroidID,
				ClosestCentroidDist = a.CentroidDistance
		from	dbo.Events e
		join	dbo.CentroidAssignment a	on	e.EventID = a.EventID
										and a.CentroidPriority = 1

	-- Capture the prior cluster centre loacations
		Delete @PreviousCentroids
		insert @PreviousCentroids Select CentroidID, CentroidX, CentroidY from dbo.Centroid

		Truncate table dbo.Centroid
		Truncate table dbo.CentroidAssignment

	-- Move the cluster centres to the average location of linked events
		insert dbo.Centroid (CentroidX, CentroidY)
		Select	avg(EventNumberX * 1.00),
				avg(EventNumberY * 1.00)
		from	dbo.Events
		group by ClosestCentroid
		order by avg(EventNumberX * 1.00),
				avg(EventNumberY * 1.00)
		;

	-- Determine whether any cluster centres have moved
		if not exists (	Select *
						from	dbo.Centroid c
						join	@PreviousCentroids p	on	c.CentroidID = p.CentroidID
						where	c.CentroidX <> p.CentroidX
						or		c.CentroidY <> p.CentroidY
						)
		begin
			Set @Unchanged = 1
		end

	end 

/* Summarise clusters */

-- Display the number of completed iterations, including a possible final iteration to determine whether furster refinement possible.
	Select @Iteration IterationsCompleted

-- Display the X,Y range of each cluster.
-- This should return 4 records if the clustering was successful

-- Based on the sample data these should be roughly (0-45, 0-45), (0-45, 55-100), (55-100, 0-45), (55-100, 55-100)
	Select	ClosestCentroid, 
			min(EventNumberX) MinX, 
			max(EventNumberX) MaxX, 
			min(EventNumberY) MinY, 
			max(EventNumberY) MaxY 
	from	dbo.Events 
	group by ClosestCentroid 
	order by 1

-- Summarise the identified cluster distribution to the expected distribution.
-- This should return 4 records if the clustering was successful
-- Failed runs are possible depending on random starting points
	Select	ClosestCentroid, 
			ExpectedCluster, 
			count(*) 
	from	dbo.Events 
	group by ClosestCentroid, 
			ExpectedCluster 
