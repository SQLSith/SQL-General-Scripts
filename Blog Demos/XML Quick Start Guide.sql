/*
	Author: Jonathan Bairstow (Bulltech Solutions Ltd)
	Created: 22/05/2018

	Blog Post: https://sql-sith.weebly.com/sql-sith-blog/xml-quick-start-guide
	
*/



--XML as a variable

	Declare	@Squads xml

	Select	@Squads = 
	'<teams>
		<team name="Bradford Bulls">
			<Players>
				<Player number="1">
					<name>Lee Smith</name>
					<position>Centre</position>
				</Player>
				<Player number="2">
					<name>Ethan Ryan</name>
					<position>Winger</position>
				</Player>
			</Players>
		</team>
		<team name="Keighley Cougars">
			<Players>
				<Player number="1">
					<name>Ritchie Hawkyard</name>
					<position>Fullback</position>
				</Player>
				<Player number="2">
					<name>Andy Gabriel</name>
					<position>Winger</position>
				</Player>
			</Players>
		</team>
	</teams>
	'

-- Returning XMl Data
	Select	@Squads

-- Addressing values by address and ordinal position

	Select	@Squads.value('(teams/team/Players/Player/@number)[1]', 'int') SquadNumber,
			@Squads.value('(teams/team/Players/Player/name)[1]', 'varchar(50)') PlayerName,
			@Squads.value('(teams/team/Players/Player/position)[1]', 'varchar(50)') Position

	Select	@Squads.value('(teams/team/Players/Player/@number)[2]', 'int') SquadNumber,
			@Squads.value('(teams/team/Players/Player/name)[2]', 'varchar(50)') PlayerName,
			@Squads.value('(teams/team/Players/Player/position)[2]', 'varchar(50)') Position

-- Addressing collections

	Select	player.value('(../../@name)[1]', 'varchar(50)'), -- up 2 levels
			player.value('(@number)[1]', 'int'),
			player.value('(name)[1]', 'varchar(50)'),
			player.value('(position)[1]', 'varchar(50)')
	from	@Squads.nodes('/teams/team/Players/Player') players(player) -- result table and field of XML type

	-- multiple collections
	Select	team.value('(@name)[1]', 'varchar(50)'),
			player.value('(@number)[1]', 'int'),
			player.value('(name)[1]', 'varchar(50)'),
			player.value('(position)[1]', 'varchar(50)')
	from	@Squads.nodes('/teams/team') teams(team)
	cross apply team.nodes('Players/Player') players(player)

-- From Field in table

	Declare	@SquadsTable table ( TestXML xml)

	insert @SquadsTable (TestXML)
	values ('<teams><team name="Bradford Bulls"><Players><Player number="1"><name>Lee Smith</name><position>Centre</position></Player><Player number="2"><name>Ethan Ryan</name><position>Winger</position></Player></Players></team><team name="Keighley Cougars"><Players><Player number="1"><name>Ritchie Hawkyard</name><position>Fullback</position></Player><Player number="2"><name>Andy Gabriel</name><position>Winger</position></Player></Players></team></teams>')

	Select	team.value('(@name)[1]', 'varchar(50)'),
			player.value('(@number)[1]', 'int'),
			player.value('(name)[1]', 'varchar(50)'),
			player.value('(position)[1]', 'varchar(50)')
	from	@SquadsTable
	cross apply TestXML.nodes('/teams/team') teams(team)
	cross apply team.nodes('Players/Player') players(player)



-- Creating XML

	Create table #Squad
	(
	TeamName		varchar(50),
	SquadNumber	int,
	PlayerName	varchar(50),
	Position		varchar(50)
	)

	insert	#Squad
	values	('Bradford Bulls',1,'Lee Smith','Centre'),
			('Bradford Bulls',2,'Ethan Ryan','Winger'),
			('Keighley Cougars',1,'Ritchie Hawkyard','Fullback'),
			('Keighley Cougars',2,'Andy Gabriel','Winger')

	Select	*
	from	#Squad

	-- Simple

	Select	distinct TeamName as '@name',
			SquadNumber as 'Players/Player/@number',
			PlayerName as 'Players/Player/name',
			Position as 'Players/Player/position'
	from	#Squad
	for XML Path('team'), Root('teams')

	-- Nested

	Select	TeamName as '@name',
		(	Select	SquadNumber as '@number',
				(	Select	PlayerName as 'name',
						Position as 'position'
					from	#Squad
					where	TeamName = p.TeamName
					and	SquadNumber = p.SquadNumber
					For XML Path (''), Type
				)
			from	#Squad p
			where	TeamName = s.TeamName
			for XML Path('Player'), Root('Players'), Type
		)
	from	(
		Select	distinct  TeamName
		from	#Squad
		) s
	for XML Path('team'), Root('teams')