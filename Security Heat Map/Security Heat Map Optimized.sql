USE [JAG]
GO

IF EXISTS (SELECT * FROM sys.procedures where object_id = OBJECT_ID('dbo.DashboardSecurityHeatMap_Optimized'))
BEGIN
	PRINT 'DROPPING [dbo].[DashboardSecurityHeatMap_Optimized]'
	DROP PROCEDURE [dbo].[DashboardSecurityHeatMap_Optimized]
END
GO

CREATE PROCEDURE [dbo].[DashboardSecurityHeatMap_Optimized]
	@TopX int = 0
	, @Sort int = 0 -- 0=TopHoldings, 1=Best, 2=Worst, 3=BestWorst
	, @Recent int = 0 -- 0=Day, 1=Week, 2=Month, 3=3Month, 4=6Month, 5=1Year, 6=3Year, 7=5Year
	, @AdditionalField int = 0 -- 0=None, 1=AssetClass, 2=Classification, 3=Country, 4=Currency, 5=Group1, 6=Group2, 7=Group3, 8=Industry, 9=Sector, 10=SecuritySimpleType, 11=SecurityType
	, @Parameters nvarchar(max) = '' -- Reserved for future use (for "hints" in case we need some backdoor extensibility)
	, @FilterHouseholdIDs nvarchar(max) = ''		-- 1 View: Household
	, @FilterClientIDs nvarchar(max) = ''			-- 2 ... View: Client
	, @FilterAccountIDs nvarchar(max) = ''			-- 3 ... View: Account
	, @FilterAccountSubTypes nvarchar(max) = ''		-- 4 ... Table: AccountType
	, @FilterCustodianIDs nvarchar(max) = ''		-- 5 ... View: Custodian
	, @FilterManagerIDs nvarchar(max) = ''			-- 6 ... View: Manager
	, @FilterFeeScheduleIDs nvarchar(max) = ''		-- 7 ... View: FeeSchedule
	, @FilterTargetModelIDs nvarchar(max) = ''		-- 8 ... View: Model
	, @FilterSecurityIDs nvarchar(max) = ''			-- 9 ... View: Security
	, @FilterSimpleSecurityTypes nvarchar(max) = '' -- 10 ... Example: 'M,S' ... List: U - Other, B - Bonds, O - Options, M - Mutual Funds, S - Stocks, C - Cash/MM, U - Other
	, @FilterSecuritySubTypes nvarchar(max) = ''	-- 11 ... Example: 'SECNPCA, SECSTK' ... Table: SecurityType
	, @FilterSecurityCountries nvarchar(max) = ''	-- 12 ... Example: 'AUT, BHS' ... Table: CountryCode
	, @FilterSecurityCurrencies nvarchar(max) = ''	-- 13 ... Example: 'USD, CLP' ... Table: CurrencyCode
	, @FilterClassIDs nvarchar(max) = ''			-- 14 ... Table: Class
	, @FilterClassificationIDs nvarchar(max) = ''	-- 15 ... Table: Classification
	, @FilterSectorIDs nvarchar(max) = ''			-- 16 ... Table: Sector
	, @FilterIndustryIDs nvarchar(max) = ''			-- 17 ... Table: Industry
	, @FilterGroup1IDs nvarchar(max) = ''			-- 18 ... Table: Group1
	, @FilterGroup2IDs nvarchar(max) = ''			-- 19 ... Table: Group2
	, @FilterGroup3IDs nvarchar(max) = ''			-- 20 ... Table: Group3
	, @FilterClientTenures nvarchar(max) = ''		-- 21 ... Example: 0,1,2 ... List: <1, 1-2, 3-5, 6-10, 11-15, 15-25, 26+
	, @FilterClientAges nvarchar(max) = ''			-- 22 ... Example: 31,32,33,34,35,36,37,38,39,40 ... List: 0-18, 19-30, 31-40, 41-50, 51-60, 61-70, 71-80, 81+
	, @FilterClientStates nvarchar(max) = ''		-- 23 ... Example: 'AL,AK' ... List: AL - Alabama, AK - ALaska, AZ - Arizona, ...
	, @FilterClientCountries nvarchar(max) = ''		-- 24 ... Example: 'AUT, BHS' ... Table: CountryCode
	, @FilterHouseholdGroupIDs nvarchar(max) = ''	-- 25 ... View: ColorGroup
	, @FilterClientGroupIDs nvarchar(max) = ''		-- 26 ... View: ColorGroup
	, @FilterAccountGroupIDs nvarchar(max) = ''		-- 27 ... View: ColorGroup
	, @FilterSecurityGroupIDs nvarchar(max) = ''	-- 28 ... View: ColorGroup
	, @FilterClientBirthdays nvarchar(max) = ''	    -- 29 ... Example: 3/4/16,3/5/16,3/6/16 ... (year will be ignored)
	, @FilterFolioIDs nvarchar(max) = ''	    	-- 30 ... View: Folio
AS
BEGIN TRY
	DECLARE @TopX_Local int
	DECLARE @Sort_Local int
	DECLARE @Recent_Local int
	DECLARE @AdditionalField_Local int
	DECLARE @Parameters_Local nvarchar(max)
	DECLARE @FilterHouseholdIDs_Local nvarchar(max)
	DECLARE @FilterClientIDs_Local nvarchar(max)
	DECLARE @FilterAccountIDs_Local nvarchar(max)
	DECLARE @FilterAccountSubTypes_Local nvarchar(max)
	DECLARE @FilterCustodianIDs_Local nvarchar(max)
	DECLARE @FilterManagerIDs_Local nvarchar(max)
	DECLARE @FilterFeeScheduleIDs_Local nvarchar(max)
	DECLARE @FilterTargetModelIDs_Local nvarchar(max)
	DECLARE @FilterSecurityIDs_Local nvarchar(max)
	DECLARE @FilterSimpleSecurityTypes_Local nvarchar(max)
	DECLARE @FilterSecuritySubTypes_Local nvarchar(max)
	DECLARE @FilterSecurityCountries_Local nvarchar(max)
	DECLARE @FilterSecurityCurrencies_Local nvarchar(max)
	DECLARE @FilterClassIDs_Local nvarchar(max)
	DECLARE @FilterClassificationIDs_Local nvarchar(max)
	DECLARE @FilterSectorIDs_Local nvarchar(max)
	DECLARE @FilterIndustryIDs_Local nvarchar(max)
	DECLARE @FilterGroup1IDs_Local nvarchar(max)
	DECLARE @FilterGroup2IDs_Local nvarchar(max)
	DECLARE @FilterGroup3IDs_Local nvarchar(max)
	DECLARE @FilterClientTenures_Local nvarchar(max)
	DECLARE @FilterClientStates_Local nvarchar(max)
	DECLARE @FilterClientAges_Local nvarchar(max)
	DECLARE @FilterClientCountries_Local nvarchar(max)
	DECLARE @FilterHouseholdGroupIDs_Local nvarchar(max)
	DECLARE @FilterClientGroupIDs_Local nvarchar(max)
	DECLARE @FilterAccountGroupIDs_Local nvarchar(max)
	DECLARE @FilterSecurityGroupIDs_Local nvarchar(max)
	DECLARE @FilterClientBirthdays_Local nvarchar(max)
	DECLARE @FilterFolioIDs_Local nvarchar(max)
	
	SET @TopX_Local = @TopX
	SET @Sort_Local = @Sort
	SET @Recent_Local = @Recent
	SET @AdditionalField_Local = @AdditionalField
	SET @Parameters_Local = @Parameters
	SET @FilterHouseholdIDs_Local = @FilterHouseholdIDs
	SET @FilterClientIDs_Local = @FilterClientIds
	SET @FilterAccountIDs_Local = @FilterAccountIDs
	SET @FilterAccountSubTypes_Local = @FilterAccountSubTypes
	SET @FilterCustodianIDs_Local = @FilterCustodianIDs
	SET @FilterManagerIDs_Local = @FilterManagerIDs
	SET @FilterFeeScheduleIDs_Local = @FilterFeeScheduleIDs
	SET @FilterTargetModelIDs_Local = @FilterTargetModelIDs
	SET @FilterSecurityIDs_Local = @FilterSecurityIDs
	SET @FilterSimpleSecurityTypes_Local = @FilterSimpleSecurityTypes
	SET @FilterSecuritySubTypes_Local = @FilterSecuritySubTypes
	SET @FilterSecurityCountries_Local = @FilterSecurityCountries
	SET @FilterSecurityCurrencies_Local = @FilterSecurityCurrencies
	SET @FilterClassIDs_Local = @FilterClassIDs
	SET @FilterClassificationIDs_Local = @FilterClassificationIDs
	SET @FilterSectorIDs_Local = @FilterSectorIDs
	SET @FilterIndustryIDs_Local = @FilterIndustryIDs
	SET @FilterGroup1IDs_Local = @FilterGroup1IDs
	SET @FilterGroup2IDs_Local = @FilterGroup2IDs
	SET @FilterGroup3IDs_Local = @FilterGroup3IDs
	SET @FilterClientTenures_Local = @FilterClientTenures
	SET @FilterClientStates_Local = @FilterClientStates
	SET @FilterClientAges_Local = @FilterClientAges
	SET @FilterClientCountries_Local = @FilterClientCountries
	SET @FilterHouseholdGroupIDs_Local = @FilterHouseholdGroupIDs
	SET @FilterClientGroupIDs_Local = @FilterClientGroupIDs
	SET @FilterAccountGroupIDs_Local = @FilterAccountGroupIDs
	SET @FilterSecurityGroupIDs_Local = @FilterSecurityGroupIDs
	SET @FilterClientBirthdays_Local = @FilterClientBirthdays
	SET @FilterFolioIDs_Local = @FilterFolioIDs
	

	DECLARE @Troubleshoot int
	SELECT @Troubleshoot = 2
	DECLARE @Start datetime
	IF(@Troubleshoot >= 1) SELECT @Start = GETDATE()
	DECLARE @StartInterim datetime
	IF(@Troubleshoot = 2) SELECT @StartInterim = GETDATE()
	IF(@Troubleshoot >= 1) PRINT SPACE(5*@@NestLevel) + 'DashboardSecurityHeatMap E ' + RTRIM(CAST(@@NestLevel AS varchar(50))) --+ ' ' + RTRIM(CONVERT(varchar(20), @Start, 14))
	SET NOCOUNT ON 
	-- 1. SQL 
	-- 1a. Find our most recent price date
	DECLARE @current datetime
	SELECT @current = CAST(CAST(MAX(Price.EffectiveDate) AS date) AS datetime)
	FROM Price WITH (NOLOCK) 
	WHERE Price.EffectiveDate <= GETDATE()
	
	-- 1b. Find our comparison date
	DECLARE @prior datetime
	SELECT @prior = CASE WHEN @Recent_Local = 0 THEN ISNULL((SELECT CAST(CAST(MAX(Price.EffectiveDate) AS date) AS datetime) FROM Price WITH (NOLOCK) WHERE Price.EffectiveDate < @current AND DATEDIFF(dd, Price.EffectiveDate, @current) < 7), @current) -- Day (look for the most recent day with a price, this skips holidays, weekends, etc.)
						 WHEN @Recent_Local = 1 THEN DATEADD(week, -1, @current) -- Week
						 WHEN @Recent_Local = 2 THEN DATEADD(mm, -1, @current) -- Month
						 WHEN @Recent_Local = 3 THEN DATEADD(mm, -3, @current) -- 3 Month
						 WHEN @Recent_Local = 4 THEN DATEADD(mm, -6, @current) -- 6 Month
						 WHEN @Recent_Local = 5 THEN DATEADD(year, -1, @current) -- 1 Year
						 WHEN @Recent_Local = 6 THEN DATEADD(year, -3, @current) -- 3 Year
						 WHEN @Recent_Local = 7 THEN DATEADD(year, -5, @current) -- 5 Year
						 ELSE @current
						 END
	DECLARE @additionalFieldSelect nvarchar(max) = '';
	DECLARE @additionalFieldColumn NVARCHAR(MAX) = '';
	DECLARE @additionalFieldFrom nvarchar(max) = '';
	DECLARE @additionalFieldGroupBy nvarchar(max) = '';
	IF @AdditionalField_Local = 1 BEGIN
		-- AssetClass
		SET @additionalFieldSelect = ', AdditionalField = Class.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntityClass (NOLOCK) ON Security.ID = EntityClass.EntityID LEFT JOIN Class (NOLOCK) ON EntityClass.ClassID = Class.ID';
		SET @additionalFieldGroupBy = ', Class.DisplayValue';
	END
	IF @AdditionalField_Local = 2 BEGIN
		-- Classification
		SET @additionalFieldSelect = ', AdditionalField = Classification.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntityClassification (NOLOCK) ON Security.ID = EntityClassification.EntityID LEFT JOIN Classification (NOLOCK) ON EntityClassification.ClassificationID = Classification.ID';
		SET @additionalFieldGroupBy = ', Classification.DisplayValue';
	END
	IF @AdditionalField_Local = 3 BEGIN
		-- Country
		SET @additionalFieldSelect = ', AdditionalField = ISNULL(CountryCode.Name, CountryCode.AlphabeticCode)';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN CountryCode (NOLOCK) ON CountryCode.NumericCode = ISNULL(Security.CountryCode,840)';
		SET @additionalFieldGroupBy = ', ISNULL(CountryCode.Name, CountryCode.AlphabeticCode)';
	END
	IF @AdditionalField_Local = 4 BEGIN
		-- Currency
		SET @additionalFieldSelect = ', AdditionalField = ISNULL(CurrencyCode.Name, CurrencyCode.AlphabeticCode)';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN CurrencyCode (NOLOCK) ON CurrencyCode.NumericCode = ISNULL(Security.LocalCurrency,840)';
		SET @additionalFieldGroupBy = ', ISNULL(CurrencyCode.Name, CurrencyCode.AlphabeticCode)';
	END
	IF @AdditionalField_Local = 5 BEGIN
		-- Group1
		SET @additionalFieldSelect = ', AdditionalField = Group1.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN Group1 (NOLOCK) ON Security.Group1ID = Group1.ID';
		SET @additionalFieldGroupBy = ', Group1.DisplayValue';
	END
	IF @AdditionalField_Local = 6 BEGIN
		-- Group2
		SET @additionalFieldSelect = ', AdditionalField = Group2.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN Group2 (NOLOCK) ON Security.Group2ID = Group2.ID';
		SET @additionalFieldGroupBy = ', Group2.DisplayValue';
	END
	IF @AdditionalField_Local = 7 BEGIN
		-- Group3
		SET @additionalFieldSelect = ', AdditionalField = Group3.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN Group3 (NOLOCK) ON Security.Group3ID = Group3.ID';
		SET @additionalFieldGroupBy = ', Group3.DisplayValue';
	END
	IF @AdditionalField_Local = 8 BEGIN
		-- Industry
		SET @additionalFieldSelect = ', AdditionalField = Industry.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntityIndustry (NOLOCK) ON Security.ID = EntityIndustry.EntityID LEFT JOIN Industry (NOLOCK) ON EntityIndustry.IndustryID = Industry.ID';
		SET @additionalFieldGroupBy = ', Industry.DisplayValue';
	END
	IF @AdditionalField_Local = 9 BEGIN
		-- Sector
		SET @additionalFieldSelect = ', AdditionalField = Sector.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntitySector (NOLOCK) ON Security.ID = EntitySector.EntityID LEFT JOIN Sector (NOLOCK) ON EntitySector.SectorID = Sector.ID';
		SET @additionalFieldGroupBy = ', Sector.DisplayValue';
	END
	IF @AdditionalField_Local = 10 BEGIN
		-- SecuritySimpleType
		SET @additionalFieldSelect = ', AdditionalField = 
			CASE 
			WHEN SimpleSecurityType = ''U'' THEN ''Other''
            WHEN SimpleSecurityType = ''B'' THEN ''Fixed Income''
            WHEN SimpleSecurityType = ''O'' THEN ''Option''
            WHEN SimpleSecurityType = ''M'' THEN ''Mutual Fund''
            WHEN SimpleSecurityType = ''S'' THEN ''Stock''
            WHEN SimpleSecurityType = ''C'' THEN ''Cash & Equivalent''
			END';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = '';
		SET @additionalFieldGroupBy = ', CASE 
			WHEN SimpleSecurityType = ''U'' THEN ''Other''
            WHEN SimpleSecurityType = ''B'' THEN ''Fixed Income''
            WHEN SimpleSecurityType = ''O'' THEN ''Option''
            WHEN SimpleSecurityType = ''M'' THEN ''Mutual Fund''
            WHEN SimpleSecurityType = ''S'' THEN ''Stock''
            WHEN SimpleSecurityType = ''C'' THEN ''Cash & Equivalent''
			END';
	END
	IF @AdditionalField_Local = 11 BEGIN
		-- SecurityType
		SET @additionalFieldSelect = ', AdditionalField = SecurityType.Name';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN SecurityType (NOLOCK) ON Security.SubType = SecurityType.SubType';
		SET @additionalFieldGroupBy = ', SecurityType.Name';
	END
	
	IF(@Troubleshoot > 1) PRINT 'Current=' + CAST(@current AS varchar(255))
	IF(@Troubleshoot > 1) PRINT 'Prior=' + CAST(@prior AS varchar(255))
	DECLARE @pctchange nvarchar(max) = '
	CASE 
		WHEN ISNULL(CurrentClosePrice, 0) = 0 THEN NULL
		WHEN ISNULL(PriorClosePrice, 0) = 0 THEN NULL
		ELSE (CurrentClosePrice - PriorClosePrice) / PriorClosePrice
	END';
	DECLARE @simplevalue nvarchar(max) = 'SUM(ISNULL(Position.SimpleValue, 0))';
	
	DECLARE @where nvarchar(max)
	SELECT @where = dbo.Get_SqlWhere_Position(
		9
		, @Parameters_Local
		, @FilterHouseholdIDs_Local
		, @FilterClientIDs_Local
		, @FilterAccountIDs_Local
		, @FilterAccountSubTypes_Local 
		, @FilterCustodianIDs_Local
		, @FilterManagerIDs_Local	
		, @FilterFeeScheduleIDs_Local
		, @FilterTargetModelIDs_Local
		, @FilterSecurityIDs_Local
		, @FilterSimpleSecurityTypes_Local
		, @FilterSecuritySubTypes_Local
		, @FilterSecurityCountries_Local
		, @FilterSecurityCurrencies_Local
		, @FilterClassIDs_Local
		, @FilterClassificationIDs_Local
		, @FilterSectorIDs_Local
		, @FilterIndustryIDs_Local
		, @FilterGroup1IDs_Local
		, @FilterGroup2IDs_Local
		, @FilterGroup3IDs_Local
		, @FilterClientTenures_Local
		, @FilterClientAges_Local
		, @FilterClientStates_Local
		, @FilterClientCountries_Local
		, @FilterHouseholdGroupIDs_Local
		, @FilterClientGroupIDs_Local
		, @FilterAccountGroupIDs_Local
		, @FilterSecurityGroupIDs_Local
		, @FilterClientBirthdays_Local
		, @FilterFolioIDs_Local
	)

	
	---- 4. EXECUTE sql
	--IF(@Troubleshoot >= 2) PRINT 'Sql:' + @sql

	------------------------------------
	-- MODIFIED
	------------------------------------

	-- PARAMS THAT WILL BE DYNAMICALLY PASSED IN
	DECLARE @sql_cte_params NVARCHAR(MAX) = '
		  @Parameters_Local nvarchar(max)
		, @FilterHouseholdIDs_Local nvarchar(max)
		, @FilterClientIDs_Local nvarchar(max)
		, @FilterAccountIDs_Local nvarchar(max)
		, @FilterAccountSubTypes_Local nvarchar(max)
		, @FilterCustodianIDs_Local nvarchar(max)
		, @FilterManagerIDs_Local nvarchar(max)
		, @FilterFeeScheduleIDs_Local nvarchar(max)
		, @FilterTargetModelIDs_Local nvarchar(max)
		, @FilterSecurityIDs_Local nvarchar(max)
		, @FilterSimpleSecurityTypes_Local nvarchar(max)
		, @FilterSecuritySubTypes_Local nvarchar(max)
		, @FilterSecurityCountries_Local nvarchar(max)
		, @FilterSecurityCurrencies_Local nvarchar(max)
		, @FilterClassIDs_Local nvarchar(max)
		, @FilterClassificationIDs_Local nvarchar(max)
		, @FilterSectorIDs_Local nvarchar(max)
		, @FilterIndustryIDs_Local nvarchar(max)
		, @FilterGroup1IDs_Local nvarchar(max)
		, @FilterGroup2IDs_Local nvarchar(max)
		, @FilterGroup3IDs_Local nvarchar(max)
		, @FilterClientTenures_Local nvarchar(max)
		, @FilterClientAges_Local nvarchar(max)
		, @FilterClientStates_Local nvarchar(max)
		, @FilterClientCountries_Local nvarchar(max)
		, @FilterHouseholdGroupIDs_Local nvarchar(max)
		, @FilterClientGroupIDs_Local nvarchar(max)
		, @FilterAccountGroupIDs_Local nvarchar(max)
		, @FilterSecurityGroupIDs_Local nvarchar(max)
		, @FilterClientBirthdays_Local nvarchar(max)
		, @FilterFolioIDs_Local nvarchar(max)
	';

	-- STATEMENT THAT WILL BE EXECUTED
	DECLARE @sql_cte_statement NVARCHAR(MAX) = '
	------------------------------
	-- All_Securities
	------------------------------
	; WITH All_Securities (
		SecurityID
		, CurrentPriceID
		, [Security]
		, Symbol
		, CUSIP
		, SimpleValue
		, WebPage
		' + @additionalFieldColumn + '
	) AS (
		SELECT 
			S.ID
			, CurrentPriceID
			, SortName AS [Security]
			, Symbol
			, CUSIP
			, SUM(ISNULL(Position.SimpleValue, 0)) AS SimpleValue
			, WebPage
			' + @additionalFieldSelect + '
		FROM [Security] AS S WITH (NOLOCK)
		LEFT JOIN s_Position Position WITH (NOLOCK) ON Position.AssetID = S.ID
		' + @additionalFieldFrom + '
		WHERE S.SubType NOT LIKE ''SECNP%''
		[POSITIONWHERE]
		GROUP BY 
			S.ID
			, CurrentPriceID
			, SortName
			, Symbol
			, CUSIP
			, WebPage
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
					P.ClosePrice
				FROM Price P WITH (NOLOCK)
				WHERE P.ID = S.CurrentPriceID
				AND dbo.DateOnly(P.EffectiveDate) <= ''' + CAST(@current AS VARCHAR(255)) + '''
				ORDER BY P.EffectiveDate DESC
			) AS CurrentClosePrice
			, (
				SELECT TOP(1)
					P.EffectiveDate
				FROM Price P WITH (NOLOCK)
				WHERE P.ID = S.CurrentPriceID
				AND dbo.DateOnly(P.EffectiveDate) <= ''' + CAST(@current AS VARCHAR(255)) + '''
				ORDER BY P.EffectiveDate DESC
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
				--AND S.CurrentPriceID != P.ID
				AND P.EffectiveDate < ''' + CAST(@prior AS VARCHAR(255)) + '''
				ORDER BY P.EffectiveDate DESC
			) AS PriorClosePrice
			, (
				SELECT TOP(1)
					P.EffectiveDate
				FROM Price P WITH (NOLOCK)
				WHERE P.SecurityID = S.SecurityID 
				--AND S.CurrentPriceID != P.ID
				AND P.EffectiveDate < ''' + CAST(@prior AS VARCHAR(255)) + '''
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
		, Symbol
		, CUSIP
		, SimpleValue
		, WebPage
		, Change
		--, PctChange
		, CurrentEffectiveDate
		, CurrentClosePrice
		, PriorEffectiveDate
		, PriorClosePrice
		' + @additionalFieldColumn + '
	) AS (
		SELECT
			S.SecurityID
			, S.[Security]
			, S.Symbol
			, S.CUSIP
			, S.SimpleValue
			, S.WebPage
			, Change = ISNULL(CurrentClosePrice, 0) - ISNULL(PriorClosePrice, 0)
			--, PctChange = 
			--	CASE 
			--		WHEN ISNULL(CurrentClosePrice, 0) = 0 THEN NULL 
			--		WHEN ISNULL(PriorClosePrice, 0) = 0 THEN NULL 
			--		ELSE (CurrentClosePrice - PriorClosePrice) / PriorClosePrice
			--	END
			, CurrentEffectiveDate
			, CurrentClosePrice
			, PriorEffectiveDate
			, PriorClosePrice
			' + @additionalFieldColumn + '
		FROM All_Securities S WITH (NOLOCK)
		INNER JOIN Current_Prices CP WITH (NOLOCK) ON CP.SecurityID = S.SecurityID
		INNER JOIN Prior_Prices PP WITH (NOLOCK) ON PP.SecurityID = S.SecurityID
		WHERE CurrentEffectiveDate <> PriorEffectiveDate
	)


	SELECT TOP(' + CAST(@TopX_Local AS VARCHAR(255)) + ')
		SecurityID
		, [Security]
		, Symbol
		, CUSIP
		, SimpleValue
		, WebPage
		, CurrentEffectiveDate
		, CurrentClosePrice
		, PriorEffectiveDate
		, PriorClosePrice
		, Change
		--, PctChange
		, PctChange = 
			CASE 
				WHEN ISNULL(CurrentClosePrice, 0) = 0 THEN NULL 
				WHEN ISNULL(PriorClosePrice, 0) = 0 THEN NULL 
				ELSE (CurrentClosePrice - PriorClosePrice) / PriorClosePrice
			END
		' + @additionalFieldColumn + '
	FROM Filtered_Securities
	ORDER BY
		CASE 
			WHEN ISNULL(CurrentClosePrice, 0) = 0 THEN NULL 
			WHEN ISNULL(PriorClosePrice, 0) = 0 THEN NULL 
			ELSE (CurrentClosePrice - PriorClosePrice) / PriorClosePrice
		END ASC
		, PriorEffectiveDate DESC
	';

	-- DYNAMICALLY ADD WHERE CLAUSES
	SELECT @sql_cte_statement = REPLACE(@sql_cte_statement, '[POSITIONWHERE]', @where)

	-- DYNAMICALLY ADD ORDER BY CLAUSES
	--IF (@Sort_Local = 0) -- TopHoldings
	--BEGIN
	--	SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY SimpleValue DESC, CurrentEffectiveDate DESC'
	--END
	
	--ELSE IF (@Sort_Local = 1) -- Best
	--BEGIN
	--	SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY PctChange DESC, PriorEffectiveDate DESC, CurrentEffectiveDate DESC'
	--END
	
	--ELSE IF (@Sort_Local = 2) -- Worst
	--BEGIN
	--	SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY PctChange ASC, PriorEffectiveDate DESC, CurrentEffectiveDate DESC'
	--END
	
	--ELSE IF (@Sort_Local = 3) -- Best/Wors
	--BEGIN
	--	SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY ABS(PctChange) DESC'
	--END

	-- RUN STAEMENT
	EXEC sp_executesql 
		@sql_cte_statement
		, @sql_cte_params
		, @Parameters_Local = @Parameters_Local
		, @FilterHouseholdIDs_Local = @FilterHouseholdIDs_Local
		, @FilterClientIDs_Local = @FilterClientIDs_Local
		, @FilterAccountIDs_Local = @FilterAccountIDs_Local
		, @FilterAccountSubTypes_Local = @FilterAccountSubTypes_Local
		, @FilterCustodianIDs_Local = @FilterCustodianIDs_Local
		, @FilterManagerIDs_Local = @FilterManagerIDs_Local
		, @FilterFeeScheduleIDs_Local = @FilterFeeScheduleIDs_Local
		, @FilterTargetModelIDs_Local = @FilterTargetModelIDs_Local
		, @FilterSecurityIDs_Local = @FilterSecurityIDs_Local
		, @FilterSimpleSecurityTypes_Local = @FilterSimpleSecurityTypes_Local
		, @FilterSecuritySubTypes_Local = @FilterSecuritySubTypes_Local
		, @FilterSecurityCountries_Local = @FilterSecurityCountries_Local
		, @FilterSecurityCurrencies_Local = @FilterSecurityCurrencies_Local
		, @FilterClassIDs_Local = @FilterClassIDs_Local
		, @FilterClassificationIDs_Local = @FilterClassificationIDs_Local
		, @FilterSectorIDs_Local = @FilterSectorIDs_Local
		, @FilterIndustryIDs_Local = @FilterIndustryIDs_Local
		, @FilterGroup1IDs_Local = @FilterGroup1IDs_Local
		, @FilterGroup2IDs_Local = @FilterGroup2IDs_Local
		, @FilterGroup3IDs_Local = @FilterGroup3IDs_Local
		, @FilterClientTenures_Local = @FilterClientTenures_Local
		, @FilterClientAges_Local = @FilterClientAges_Local
		, @FilterClientStates_Local = @FilterClientStates_Local
		, @FilterClientCountries_Local = @FilterClientCountries_Local
		, @FilterHouseholdGroupIDs_Local = @FilterHouseholdGroupIDs_Local
		, @FilterClientGroupIDs_Local = @FilterClientGroupIDs_Local
		, @FilterAccountGroupIDs_Local = @FilterAccountGroupIDs_Local
		, @FilterSecurityGroupIDs_Local = @FilterSecurityGroupIDs_Local
		, @FilterClientBirthdays_Local = @FilterClientBirthdays_Local
		, @FilterFolioIDs_Local = @FilterFolioIDs_Local

	
	------------------------------------
	-- END MODIFIED
	------------------------------------

	SET NOCOUNT OFF
	IF(@Troubleshoot >= 1) PRINT SPACE(5*@@NestLevel) + 'TopClients X ' + RTRIM(CAST(@@NestLevel AS varchar(50))) + ' ' + CAST(DATEDIFF(ms, @Start, GETDATE()) as varchar(200)) + 'ms'
END TRY
BEGIN CATCH
	
	-- Throw the error
	DECLARE @error int, @message varchar(4000), @xstate int;
	SELECT @error = ERROR_NUMBER(), @message = ERROR_MESSAGE()
	RAISERROR ('DashboardSecurityHeatMap: %d: %s', 16, 1, @error, @message);
	
END CATCH 

PRINT 'CREATED [dbo].[DashboardSecurityHeatMap_Optimized]'
GO
