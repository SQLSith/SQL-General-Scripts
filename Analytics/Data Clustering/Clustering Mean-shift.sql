/*
		Author: Jonathan Bairstow (Bulltech Solutions Ltd)
		Created: 10/11/2019

		Description:
		This script demostrates k-means clustering using standard SQL, spatial datatypes and batch processing.

		This demo is designed to work with sample data create with 'Create Sample Data 2.sql'
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
	CentroidPoint Geometry,
	CentroidX	decimal(9,6),
	CentroidY	decimal(9,6),
	DataPoints	int,
	OverridingCentroidID int
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



/* Seed centroids accross the entire X,Y Range */
	insert	dbo.Centroid (CentroidPoint, CentroidX, CentroidY)
	Select	geometry::Point(x, y, 0),
			x,
			y
	from	(values(10),(20),(30),(40),(50),(60),(70),(80),(90)) X(x)
	cross join (values(10),(20),(30),(40),(50),(60),(70),(80),(90)) Y(y)
	go

	

/* Create process variables anc configurations */
	Declare @Radius int =  14,			-- The radius around each point in which to look for events
	
			@MaximumIterations int = 50, -- How many iterations to perform. Decreasing this number
										-- will cap the number of iterations that are attempted. 
										-- The lower the number; the faster the completion but the lower the accuracy.
										-- The higher the number; the longer the process may run, but teh higher the potential accuracy.

			@Iteration int = 0,			-- The iteration counter

			@Unchanged bit = 0			-- Whether or not the cluster centres have moved since the prior iteration.

	-- Table variable to hold the position of the cluster centres from the prior iteration
	Declare @PreviousCentroids table (CentroidID int, CentroidPoint Geometry)


-- Determine the number of events within the radius of any centroid
	insert	dbo.CentroidAssignment ([EventID], [CentroidID], [CentroidDistance], [CentroidPriority])
	Select	e.EventID, 
			c.CentroidID, 
			EventPoint.STDistance(c.CentroidPoint),
			row_number() over (partition by EventID order by EventPoint.STDistance(c.CentroidPoint)) rw
	from	dbo.Events e
	cross join	dbo.Centroid c
	where	EventPoint.STDistance(c.CentroidPoint) <= @Radius

-- Eliminate any centroid with 0 events
	Delete	c
	from	dbo.Centroid c
	left join	dbo.CentroidAssignment a	on	c.CentroidID = a.CentroidID
	where	a.CentroidID is null
	;


/* Refine the location of the cluster centres. This is an iterative process which involves moving the centre of each
   cluster to a higher density of events by moving the cluster to the average location of all linked events.
   The process continues until the maximum number of iterations have been performed, or no refinements were made by 
   the latest iteration. Where cluster centers match duplicates are eliminated.
*/


	While @Iteration <= @MaximumIterations and @Unchanged = 0
	begin

		Select @Iteration = @Iteration + 1

	-- Capture the prior cluster centre loacations
		Delete @PreviousCentroids
		insert @PreviousCentroids Select CentroidID, CentroidPoint from dbo.Centroid

		Truncate table dbo.Centroid

	-- Move the cluster centres to the average location of linked events, eliminatng duplicates
		insert dbo.Centroid (CentroidX, CentroidY)
		Select	distinct		
				avg(EventNumberX),
				avg(EventNumberY)
		from	dbo.CentroidAssignment a
		join	dbo.Events e	on	a.EventID = e.EventID
		group by a.CentroidID
		order by avg(EventNumberX),
				avg(EventNumberY)
		;

		Update	dbo.Centroid
		Set		CentroidPoint = geometry::Point(CentroidX, CentroidY, 0)
		;


	-- Determine the number of events within the radius of any centroid

		Truncate table dbo.CentroidAssignment

		insert	dbo.CentroidAssignment ([EventID], [CentroidID], [CentroidDistance], [CentroidPriority])
		Select	e.EventID, 
				c.CentroidID, 
				EventPoint.STDistance(c.CentroidPoint),
				row_number() over (partition by EventID order by EventPoint.STDistance(c.CentroidPoint)) rw
		from	dbo.Events e
		cross join	dbo.Centroid c
		where	EventPoint.STDistance(c.CentroidPoint) <= @Radius


	-- Determine whether any cluster centres have moved
		if not exists (	Select *
						from	dbo.Centroid c
						join	@PreviousCentroids p	on	c.CentroidID = p.CentroidID
						where	c.CentroidPoint.STDistance(p.CentroidPoint)> 0
						)
		begin
			Set @Unchanged = 1
		end

	end 

-- Calculate datapoints per cluster
	; With DataPoints as
	(
	Select	CentroidID,
			count(*) DataPoints
	from	dbo.CentroidAssignment
	group by CentroidID
	)
	Update	c
	Set		[DataPoints] = d.DataPoints
	from	[dbo].[Centroid] c
	join	DataPoints d	on	c.CentroidID = d.CentroidID
	;

	--Identify Overlaps
	;With Overlaps as
	(
	Select	o.CentroidID CentroidID_Old, 
			c.CentroidID CentroidID_New,  
			row_number() over (partition by o.CentroidID order by c.DataPoints desc) OverridePriority
	from	[dbo].[Centroid] c
	join	[dbo].[Centroid] o	on	c.[CentroidPoint].STBuffer(@Radius).STIntersects(o.[CentroidPoint].STBuffer(@Radius)) = 1
	where	c.DataPoints >= o.DataPoints
	and		c.CentroidID <> o.CentroidID
	)
	Update	c
	Set		c.[OverridingCentroidID] = o.CentroidID_New
	from	[dbo].[Centroid] c
	join	Overlaps o	on	c.CentroidID = o.CentroidID_Old
	where	OverridePriority = 1
	;

-- Assign each event to its closest cluster centre
	Update e
	Set		ClosestCentroid = a.CentroidID,
			ClosestCentroidDist = a.CentroidDistance
	from	dbo.Events e
	join	dbo.CentroidAssignment a	on	e.EventID = a.EventID
										and a.CentroidPriority = 1


/* Summarise clusters */

-- Display the number of completed iterations, including a possible final iteration to determine whether furster refinement possible.
	Select @Iteration IterationsCompleted


-- Visualise the clusters
	; With Selection as (
	Select top 4900 [EventPoint] from [dbo].[Events] order by newid()
	)
	Select [EventPoint] from Selection
	union all
	Select [CentroidPoint].STBuffer(@Radius) from [dbo].[Centroid] where OverridingCentroidID is null
	
	
	
