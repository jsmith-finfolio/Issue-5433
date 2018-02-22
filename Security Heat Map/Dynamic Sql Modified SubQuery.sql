USE JAG
GO


SELECT TOP (100)
		S.ID AS SecurityId
		, S.SortName AS [Security]
		, S.Symbol
		, S.CUSIP
		, SUM(ISNULL(P.SimpleValue, 0)) AS SimpleValue
		, S.WebPage
	FROM [Security] S WITH (NOLOCK)
	LEFT JOIN s_Position P WITH (NOLOCK) ON P.AssetID = S.ID
	WHERE S.SubType NOT LIKE 'SECNP%'
	GROUP BY 
		S.ID
		, S.SortName
		, S.Symbol
		, S.CUSIP
		, S.WebPage