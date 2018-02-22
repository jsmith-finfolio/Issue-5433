USE JAG
GO

------------------------------
-- All_Securities
------------------------------
; WITH All_Securities (
	SecurityID
	, CurrentPriceID
	, [Security]
) AS (
	SELECT 
		S.ID
		, CurrentPriceID
		, SortName AS [Security]
	FROM [Security] AS S WITH (NOLOCK)
	LEFT JOIN s_Position Position WITH (NOLOCK) ON Position.AssetID = S.ID
	WHERE S.SubType NOT LIKE 'SECNP%'
	GROUP BY 
		S.ID
		, CurrentPriceID
		, SortName
	HAVING SUM(ISNULL(Position.SimpleValue, 0)) <> 0
)

------------------------------
-- Current_Prices
------------------------------
, Current_Prices (
	SecurityID
	, CurrentClosePrice
	, CurrentEffectiveDate
) AS (
	SELECT
		S.SecurityID
		, (
			SELECT TOP(1)
				ClosePrice
			FROM Price WITH (NOLOCK)
			WHERE ID = S.CurrentPriceID
			--AND dbo.DateOnly(EffectiveDate) <= 'Feb 13 2017 12:00AM'
			ORDER BY EffectiveDate DESC
		) AS CurrentClosePrice
		, (
			SELECT TOP(1)
				EffectiveDate
			FROM Price WITH (NOLOCK)
			WHERE ID = S.CurrentPriceID
			--AND dbo.DateOnly(EffectiveDate) <= 'Feb 13 2017 12:00AM'
			ORDER BY EffectiveDate DESC
		) AS CurrentEffectiveDate
	FROM All_Securities AS S WITH (NOLOCK)
)

------------------------------
-- Prior_Prices
------------------------------
, Prior_Prices (
	SecurityID
	, PriorClosePrice
	, PriorEffectiveDate
) AS (
	SELECT
		S.SecurityID
		, (
			SELECT TOP(1)
				P.ClosePrice
			FROM Price P WITH (NOLOCK)
			WHERE P.SecurityID = S.SecurityID 
			AND S.CurrentPriceID != P.ID
			AND P.EffectiveDate < 'Feb 13 2017 12:00AM'
			ORDER BY P.EffectiveDate DESC
		) AS PriorClosePrice
		, (
			SELECT TOP(1)
				P.EffectiveDate
			FROM Price P WITH (NOLOCK)
			WHERE P.SecurityID = S.SecurityID 
			AND S.CurrentPriceID != P.ID
			AND P.EffectiveDate < 'Feb 13 2017 12:00AM'
			ORDER BY P.EffectiveDate DESC
		) AS PriorEffectiveDate
	FROM All_Securities S WITH (NOLOCK)
)

------------------------------
-- Filtered_Securities 
------------------------------
, Filtered_Securities (
	SecurityID
	, [Security]
	, PctChange
	, CurrentEffectiveDate
	, CurrentClosePrice
	, PriorEffectiveDate
	, PriorClosePrice
) AS (
	SELECT
		S.SecurityID
		, S.[Security]
		, PctChange = 
			CASE 
				WHEN ISNULL(CurrentClosePrice, 0) = 0 THEN NULL 
				WHEN ISNULL(PriorClosePrice, 0) = 0 THEN NULL 
				ELSE (CurrentClosePrice - PriorClosePrice) / PriorClosePrice
			END
		, CurrentEffectiveDate
		, CurrentClosePrice
		, PriorEffectiveDate
		, PriorClosePrice
	FROM All_Securities S WITH (NOLOCK)
	INNER JOIN Current_Prices CP WITH (NOLOCK) ON CP.SecurityID = S.SecurityID
	INNER JOIN Prior_Prices PP WITH (NOLOCK) ON PP.SecurityID = S.SecurityID
	--ORDER BY PctChange DESC
)

--SELECT COUNT(*) FROM All_Securities
--SELECT COUNT(*) FROM Current_Prices
--SELECT COUNT(*) FROM Prior_Prices
--SELECT COUNT(*) FROM Filtered_Securities

--SELECT * FROM All_Securities
--SELECT * FROM Current_Prices
--SELECT * FROM Prior_Prices

SELECT top(100)
	* 
FROM Filtered_Securities
--where SecurityID = 'A7778FBF-382C-4C31-B0D5-0A5566D4D932'
--ORDER BY PctChange DESC

-- PROC
EXEC dbo.DashboardSecurityHeatMap @TopX=100, @Sort=1, @Recent=5, @AdditionalField=0




SELECT TOP(1)
	ClosePrice
FROM Price WITH (NOLOCK)
WHERE ID = '13E30F3B-0018-E811-81D9-9EB0DD226ABE'
--AND EffectiveDate <= 'Feb 13 2017 12:00AM'