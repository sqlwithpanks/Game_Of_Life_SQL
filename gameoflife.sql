--https://sqlwithpanks.wordpress.com/2016/06/14/conways-game-of-life-in-tsql/
--Visit my blog for other interesting stuff at https://sqlwithpanks.wordpress.com/
SET XACT_ABORT ON;
DECLARE @GridSize TINYINT=8, @NumCycles TINYINT =15, @CycleId TINYINT=1;
DECLARE @Game TABLE 
(
	CycleId TINYINT NOT NULL,
	X TINYINT NOT NULL,
	Y TINYINT NOT NULL,
	Life TINYINT DEFAULT 0,
	HowCome VARCHAR(50) DEFAULT ''
		PRIMARY KEY(CycleId,X,Y)
);
;WITH Nums(Num,R) AS/*Recursive CTE to generate Numbers and some random Number*/
(
	SELECT 1 Num, CAST(CAST(NEWID() as BINARY(10)) AS INT)/100 as R 
		UNION ALL	
	SELECT Num+1, CAST(CAST(NEWID() as BINARY(10)) AS INT)/100 as R FROM Nums 
	WHERE Num< @GridSize
)
INSERT INTO @Game(CycleId, X, Y, Life, HowCome)/*This is the seed life, created by chance*/
SELECT 	@CycleId, N1.Num, N2.Num, Life, CASE WHEN Life=1 THEN 'Luck By Chance' ELSE '' END 
FROM Nums N1 CROSS JOIN Nums N2 
CROSS APPLY (SELECT CASE WHEN (N1.R)%2=0 AND (N1.R+N2.R)%3=0 THEN 1 ELSE 0 END as Life )X

WHILE( @CycleId <= @NumCycles )/*Iterate based on NumCycles, decifer next life and render the next cycle*/
BEGIN
	/*Lets render the current cycle*/
	SELECT CycleId, X, Y, Life, HowCome, RenderLife 
	FROM @Game G
		OUTER APPLY
		(SELECT Geometry::STPointFromText('Point('+CAST(X-0.5 as VARCHAR)+' '
											      +CAST(Y-0.5 as VARCHAR)+')',0).STBuffer(Life/2.8).STEnvelope() as RenderLife
		) X
	WHERE CycleId =@CycleId;
	
	INSERT INTO @Game(CycleId,X,Y,Life,HowCome)/*Next Cycle based on previous cycle and rules of life*/
	SELECT 	@CycleId+1,X,Y,CASE WHEN HowCome IN('Survives','New Life') THEN 1 ELSE 0 END, HowCome
	FROM
	(
		SELECT G1.X, G1.Y, MAX(G1.Life) IsLive, SUM(CASE WHEN G1.X=G2.X AND G1.Y=G2.Y THEN 0 ELSE  G2.Life END) LifeAround
		FROM @Game G1 
			JOIN @GAME G2 ON G2.X BETWEEN G1.X-1 AND G1.X+1 AND G2.Y BETWEEN G1.Y-1 AND G1.Y+1 AND G1.CycleId = G2.CycleId
		WHERE G1.CycleId = @CycleId
		GROUP BY G1.X,G1.Y
	)X
	CROSS APPLY
	(
		SELECT CASE WHEN IsLive=1 THEN CASE LifeAround 
										WHEN 0 THEN 'Loneliness Kills' WHEN 1 THEN 'Loneliness Kills' 
										WHEN 2 THEN 'Survives' WHEN 3 THEN 'Survives' 
										ELSE 'Crowding Kills' END 
								  ELSE CASE LifeAround WHEN 3 THEN 'New Life' ELSE '' END END as HowCome
	)Y

	SET @CycleId = @CycleId + 1
END
