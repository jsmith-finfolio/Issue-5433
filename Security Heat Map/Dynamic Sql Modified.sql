------------------------------------
-- MODIFIED
------------------------------------

DECLARE @TopX INT = 100
DECLARE @Prior DATETIME
DECLARE @Current DATETIME

------------------------------------
-- With_Securities 
------------------------------------
; WITH With_Securities (
	SecurityID
	, [Security]
	, Symbol
	, CUSIP
	, SimpleValue
	, WebPage
	, CurrentPriceID
) AS (
	SELECT TOP (@TopX)
		S.ID AS SecurityId
		, S.SortName AS [Security]
		, S.Symbol
		, S.CUSIP
		, SUM(ISNULL(sP.SimpleValue, 0)) AS SimpleValue
		, S.WebPage
		, S.CurrentPriceID
	FROM [Security] S WITH (NOLOCK)
	LEFT JOIN s_Position sP WITH (NOLOCK) ON sP.AssetID = S.ID
	INNER JOIN Price P ON P.ID = S.CurrentPriceID
	WHERE S.SubType NOT LIKE 'SECNP%'
	GROUP BY 
		S.ID
		, S.SortName
		, S.Symbol
		, S.CUSIP
		, S.WebPage
		, S.CurrentPriceID
)

------------------------------------
-- With_CurrentPrice 
------------------------------------
, With_CurrentPrice (
	SecurityID
	, [Security]
	, Symbol
	, CUSIP
	, SimpleValue
	, WebPage
	, CurrentPriceID
	, CurrentEffectiveDate
	, CurrentClosePrice
) AS (
	SELECT
		*
		, (
			SELECT TOP(1)
				P.EffectiveDate
			FROM Price P WITH (NOLOCK)
			WHERE P.ID = CurrentPriceID
			AND dbo.DateOnly(P.EffectiveDate) <= 'Feb 13 2018 12:00AM' /** PARAMETERIZE THIS */
		) AS CurrentEffectiveDate
		, (
			SELECT TOP(1)
				P.ClosePrice
			FROM Price P WITH (NOLOCK)
			WHERE P.ID = CurrentPriceID
			AND dbo.DateOnly(P.EffectiveDate) <= 'Feb 13 2018 12:00AM' /** PARAMETERIZE THIS */
		) AS CurrentClosePrice
	FROM With_Securities
)

------------------------------------
-- With_PriorPrice 
------------------------------------
, With_PriorPrice (
	SecurityID
	, [Security]
	, Symbol
	, CUSIP
	, SimpleValue
	, WebPage
	, CurrentPriceID
	, CurrentEffectiveDate
	, CurrentClosePrice
	, PriorEffectiveDate
	, PriorClosePrice
) AS (
	SELECT
		CP.*
		, (
			SELECT TOP(1)
				P.EffectiveDate
			FROM Price P
			WHERE P.SecurityID = CP.SecurityID
			AND P.EffectiveDate < 'Feb 13 2017 12:00AM'
		) AS PriorEffectiveDate
		, (
			SELECT TOP(1)
				P.ClosePrice
			FROM Price P
			WHERE P.SecurityID = CP.SecurityID
			AND P.EffectiveDate < 'Feb 13 2017 12:00AM'
			ORDER BY P.EffectiveDate DESC
		) AS PriorClosePrice
	FROM With_CurrentPrice CP
)

SELECT 
	SecurityId
	, [Security]
	, Symbol
	, CUSIP
	, SimpleValue
	, WebPage
	, CurrentEffectiveDate
	, CurrentClosePrice
	, PriorEffectiveDate
	, PriorClosePrice
	, Change = ISNULL(CurrentClosePrice, 0) - ISNULL(PriorClosePrice, 0)
	, CASE 
		WHEN ISNULL(CurrentClosePrice, 0) = 0
			THEN NULL
		WHEN ISNULL(PriorClosePrice, 0) = 0
			THEN NULL
		ELSE (CurrentClosePrice - PriorClosePrice) / PriorClosePrice
		END AS PctChange
FROM With_PriorPrice