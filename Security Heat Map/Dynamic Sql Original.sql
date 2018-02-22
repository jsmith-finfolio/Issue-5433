------------------------------------
-- ORIGINAL 
------------------------------------

SELECT TOP (100) Security.ID AS SecurityID
	,Security.SortName AS Security
	,Security.Symbol
	,Security.CUSIP
	,SUM(ISNULL(Position.SimpleValue, 0)) AS SimpleValue
	,Security.WebPage
	,CurrentPrice.EffectiveDate AS CurrentEffectiveDate
	,CurrentPrice.ClosePrice AS CurrentClosePrice
	,PriorPrice.EffectiveDate AS PriorEffectiveDate
	,PriorPrice.ClosePrice AS PriorClosePrice
	,Change = ISNULL(CurrentPrice.ClosePrice, 0) - ISNULL(PriorPrice.ClosePrice, 0)
	,PctChange = CASE 
		WHEN ISNULL(CurrentPrice.ClosePrice, 0) = 0
			THEN NULL
		WHEN ISNULL(PriorPrice.ClosePrice, 0) = 0
			THEN NULL
		ELSE (CurrentPrice.ClosePrice - PriorPrice.ClosePrice) / PriorPrice.ClosePrice
		END
FROM Security WITH (NOLOCK)
LEFT JOIN s_Position Position WITH (NOLOCK) ON Position.AssetID = Security.ID
CROSS APPLY (
	SELECT TOP 1 p.ID
		,p.EffectiveDate
		,p.ClosePrice
	FROM Security S WITH (NOLOCK)
	INNER JOIN Price P WITH (NOLOCK) ON Security.CurrentPriceID = P.ID
	WHERE S.ID = Security.ID
		AND dbo.DateOnly(P.EffectiveDate) <= 'Feb 13 2018 12:00AM'
	ORDER BY P.EffectiveDate DESC
	) CurrentPrice
CROSS APPLY (
	SELECT TOP 1 p.ID
		,p.EffectiveDate
		,p.ClosePrice
	FROM Price P WITH (NOLOCK)
	WHERE P.SecurityID = Security.ID
		AND P.EffectiveDate < 'Feb 13 2017 12:00AM'
	ORDER BY P.EffectiveDate DESC
	) PriorPrice
WHERE Security.SubType NOT LIKE 'SECNP%' -- No cash/mm    AND CurrentPrice.EffectiveDate <> PriorPrice.EffectiveDate          GROUP BY Security.ID, Security.SortName, Security.Symbol, Security.CUSIP, CurrentPrice.EffectiveDate, CurrentPrice.ClosePrice, PriorPrice.EffectiveDate, PriorPrice.ClosePrice, Security.WebPage      HAVING SUM(ISNULL(Position.SimpleValue, 0)) <> 0 -- Only owned securities  ORDER BY SUM(ISNULL(Position.SimpleValue, 0)) DESC
GROUP BY 
		Security.ID
		, Security.SortName
		, Security.Symbol
		, Security.CUSIP
		, Security.WebPage
		, CurrentPrice.EffectiveDate
		, CurrentPrice.ClosePrice
		, PriorPrice.EffectiveDate
		, PriorPrice.ClosePrice