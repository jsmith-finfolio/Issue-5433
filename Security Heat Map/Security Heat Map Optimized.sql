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
	SELECT @prior = CASE WHEN @Recent = 0 THEN ISNULL((SELECT CAST(CAST(MAX(Price.EffectiveDate) AS date) AS datetime) FROM Price WITH (NOLOCK) WHERE Price.EffectiveDate < @current AND DATEDIFF(dd, Price.EffectiveDate, @current) < 7), @current) -- Day (look for the most recent day with a price, this skips holidays, weekends, etc.)
						 WHEN @Recent = 1 THEN DATEADD(week, -1, @current) -- Week
						 WHEN @Recent = 2 THEN DATEADD(mm, -1, @current) -- Month
						 WHEN @Recent = 3 THEN DATEADD(mm, -3, @current) -- 3 Month
						 WHEN @Recent = 4 THEN DATEADD(mm, -6, @current) -- 6 Month
						 WHEN @Recent = 5 THEN DATEADD(year, -1, @current) -- 1 Year
						 WHEN @Recent = 6 THEN DATEADD(year, -3, @current) -- 3 Year
						 WHEN @Recent = 7 THEN DATEADD(year, -5, @current) -- 5 Year
						 ELSE @current
						 END
	DECLARE @additionalFieldSelect nvarchar(max) = '';
	DECLARE @additionalFieldColumn NVARCHAR(MAX) = '';
	DECLARE @additionalFieldFrom nvarchar(max) = '';
	DECLARE @additionalFieldGroupBy nvarchar(max) = '';
	IF @AdditionalField = 1 BEGIN
		-- AssetClass
		SET @additionalFieldSelect = ', AdditionalField = Class.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntityClass (NOLOCK) ON Security.ID = EntityClass.EntityID LEFT JOIN Class (NOLOCK) ON EntityClass.ClassID = Class.ID';
		SET @additionalFieldGroupBy = ', Class.DisplayValue';
	END
	IF @AdditionalField = 2 BEGIN
		-- Classification
		SET @additionalFieldSelect = ', AdditionalField = Classification.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntityClassification (NOLOCK) ON Security.ID = EntityClassification.EntityID LEFT JOIN Classification (NOLOCK) ON EntityClassification.ClassificationID = Classification.ID';
		SET @additionalFieldGroupBy = ', Classification.DisplayValue';
	END
	IF @AdditionalField = 3 BEGIN
		-- Country
		SET @additionalFieldSelect = ', AdditionalField = ISNULL(CountryCode.Name, CountryCode.AlphabeticCode)';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN CountryCode (NOLOCK) ON CountryCode.NumericCode = ISNULL(Security.CountryCode,840)';
		SET @additionalFieldGroupBy = ', ISNULL(CountryCode.Name, CountryCode.AlphabeticCode)';
	END
	IF @AdditionalField = 4 BEGIN
		-- Currency
		SET @additionalFieldSelect = ', AdditionalField = ISNULL(CurrencyCode.Name, CurrencyCode.AlphabeticCode)';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN CurrencyCode (NOLOCK) ON CurrencyCode.NumericCode = ISNULL(Security.LocalCurrency,840)';
		SET @additionalFieldGroupBy = ', ISNULL(CurrencyCode.Name, CurrencyCode.AlphabeticCode)';
	END
	IF @AdditionalField = 5 BEGIN
		-- Group1
		SET @additionalFieldSelect = ', AdditionalField = Group1.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN Group1 (NOLOCK) ON Security.Group1ID = Group1.ID';
		SET @additionalFieldGroupBy = ', Group1.DisplayValue';
	END
	IF @AdditionalField = 6 BEGIN
		-- Group2
		SET @additionalFieldSelect = ', AdditionalField = Group2.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN Group2 (NOLOCK) ON Security.Group2ID = Group2.ID';
		SET @additionalFieldGroupBy = ', Group2.DisplayValue';
	END
	IF @AdditionalField = 7 BEGIN
		-- Group3
		SET @additionalFieldSelect = ', AdditionalField = Group3.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN Group3 (NOLOCK) ON Security.Group3ID = Group3.ID';
		SET @additionalFieldGroupBy = ', Group3.DisplayValue';
	END
	IF @AdditionalField = 8 BEGIN
		-- Industry
		SET @additionalFieldSelect = ', AdditionalField = Industry.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntityIndustry (NOLOCK) ON Security.ID = EntityIndustry.EntityID LEFT JOIN Industry (NOLOCK) ON EntityIndustry.IndustryID = Industry.ID';
		SET @additionalFieldGroupBy = ', Industry.DisplayValue';
	END
	IF @AdditionalField = 9 BEGIN
		-- Sector
		SET @additionalFieldSelect = ', AdditionalField = Sector.DisplayValue';
		SET @additionalFieldColumn = ', AdditionalField';
		SET @additionalFieldFrom = 'LEFT JOIN EntitySector (NOLOCK) ON Security.ID = EntitySector.EntityID LEFT JOIN Sector (NOLOCK) ON EntitySector.SectorID = Sector.ID';
		SET @additionalFieldGroupBy = ', Sector.DisplayValue';
	END
	IF @AdditionalField = 10 BEGIN
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
	IF @AdditionalField = 11 BEGIN
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
		, @Parameters
		, @FilterHouseholdIDs
		, @FilterClientIDs
		, @FilterAccountIDs
		, @FilterAccountSubTypes 
		, @FilterCustodianIDs
		, @FilterManagerIDs	
		, @FilterFeeScheduleIDs
		, @FilterTargetModelIDs
		, @FilterSecurityIDs
		, @FilterSimpleSecurityTypes
		, @FilterSecuritySubTypes
		, @FilterSecurityCountries
		, @FilterSecurityCurrencies
		, @FilterClassIDs
		, @FilterClassificationIDs
		, @FilterSectorIDs
		, @FilterIndustryIDs
		, @FilterGroup1IDs
		, @FilterGroup2IDs
		, @FilterGroup3IDs
		, @FilterClientTenures
		, @FilterClientAges
		, @FilterClientStates
		, @FilterClientCountries
		, @FilterHouseholdGroupIDs
		, @FilterClientGroupIDs
		, @FilterAccountGroupIDs
		, @FilterSecurityGroupIDs
		, @FilterClientBirthdays
		, @FilterFolioIDs
	)

	
	---- 4. EXECUTE sql
	--IF(@Troubleshoot >= 2) PRINT 'Sql:' + @sql

	------------------------------------
	-- MODIFIED
	------------------------------------

	-- PARAMS THAT WILL BE DYNAMICALLY PASSED IN
	DECLARE @sql_cte_params NVARCHAR(MAX) = '
		  @Parameters nvarchar(max)
		, @FilterHouseholdIDs nvarchar(max)
		, @FilterClientIDs nvarchar(max)
		, @FilterAccountIDs nvarchar(max)
		, @FilterAccountSubTypes nvarchar(max)
		, @FilterCustodianIDs nvarchar(max)
		, @FilterManagerIDs nvarchar(max)
		, @FilterFeeScheduleIDs nvarchar(max)
		, @FilterTargetModelIDs nvarchar(max)
		, @FilterSecurityIDs nvarchar(max)
		, @FilterSimpleSecurityTypes nvarchar(max)
		, @FilterSecuritySubTypes nvarchar(max)
		, @FilterSecurityCountries nvarchar(max)
		, @FilterSecurityCurrencies nvarchar(max)
		, @FilterClassIDs nvarchar(max)
		, @FilterClassificationIDs nvarchar(max)
		, @FilterSectorIDs nvarchar(max)
		, @FilterIndustryIDs nvarchar(max)
		, @FilterGroup1IDs nvarchar(max)
		, @FilterGroup2IDs nvarchar(max)
		, @FilterGroup3IDs nvarchar(max)
		, @FilterClientTenures nvarchar(max)
		, @FilterClientAges nvarchar(max)
		, @FilterClientStates nvarchar(max)
		, @FilterClientCountries nvarchar(max)
		, @FilterHouseholdGroupIDs nvarchar(max)
		, @FilterClientGroupIDs nvarchar(max)
		, @FilterAccountGroupIDs nvarchar(max)
		, @FilterSecurityGroupIDs nvarchar(max)
		, @FilterClientBirthdays nvarchar(max)
		, @FilterFolioIDs nvarchar(max)
	';

	-- STATEMENT THAT WILL BE EXECUTED
	DECLARE @sql_cte_statement NVARCHAR(MAX) = '
	
	; WITH With_Securities (
		SecurityID
		, [Security]
		, Symbol
		, CUSIP
		, SimpleValue
		, WebPage
		, CurrentPriceID
		' + @additionalFieldColumn + '
	) AS (
		SELECT TOP (' + CAST(@TopX AS VARCHAR(255)) + ')
			[Security].ID AS SecurityID
			, [Security].SortName AS [Security]
			, [Security].Symbol
			, [Security].CUSIP
			, ' + @simpleValue + ' AS SimpleValue
			, [Security].WebPage
			, [Security].CurrentPriceID
			' + @additionalFieldSelect + '
		FROM [Security] WITH (NOLOCK)
		LEFT JOIN s_Position Position WITH (NOLOCK) ON Position.AssetID = [Security].ID
		INNER JOIN Price AS P ON P.ID = [Security].CurrentPriceID
		' + @additionalFieldFrom + '
		WHERE [Security].SubType NOT LIKE ''SECNP%''
		[POSITIONWHERE]
		GROUP BY 
			[Security].ID
			, [Security].SortName
			, [Security].Symbol
			, [Security].CUSIP
			, [Security].WebPage
			, [Security].CurrentPriceID
			, P.EffectiveDate
			' + @additionalFieldGroupBy + ' 
		HAVING ' + @simpleValue + ' <> 0
		ORDER BY 
			P.EffectiveDate DESC
			, ' + @simpleValue + ' DESC
		
	)

	
	, With_CurrentPrice (
		SecurityID
		, [Security]
		, Symbol
		, CUSIP
		, SimpleValue
		, WebPage
		, CurrentPriceID
		' + @additionalFieldColumn + '
		, CurrentEffectiveDate
		, CurrentClosePrice
	) AS (
		SELECT
			S.*
			, (
				SELECT TOP(1)
					P.EffectiveDate
				FROM Price P WITH (NOLOCK)
				WHERE P.ID = S.CurrentPriceID
				AND dbo.DateOnly(P.EffectiveDate) <= ''' + CAST(@current AS VARCHAR(255)) + '''
				ORDER BY P.EffectiveDate DESC
			) AS CurrentEffectiveDate
			, (
				SELECT TOP(1)
					P.ClosePrice
				FROM Price P WITH (NOLOCK)
				WHERE P.ID = S.CurrentPriceID
				AND dbo.DateOnly(P.EffectiveDate) <= ''' + CAST(@current AS VARCHAR(255)) + '''
				ORDER BY P.EffectiveDate DESC
			) AS CurrentClosePrice
		FROM With_Securities S
	)

	
	, With_PriorPrice (
		SecurityID
		, [Security]
		, Symbol
		, CUSIP
		, SimpleValue
		, WebPage
		, CurrentPriceID
		' + @additionalFieldColumn + '
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
				AND P.EffectiveDate < ''' + CAST(@prior AS VARCHAR(255)) + '''
				ORDER BY P.EffectiveDate DESC
			) AS PriorEffectiveDate
			, (
				SELECT TOP(1)
					P.ClosePrice
				FROM Price P
				WHERE P.SecurityID = CP.SecurityID
				AND P.EffectiveDate < ''' + + CAST(@prior AS VARCHAR(255)) + '''
				ORDER BY P.EffectiveDate DESC
			) AS PriorClosePrice
		FROM With_CurrentPrice CP
	)
	
	SELECT 
		SecurityID
		, [Security]
		, Symbol
		, CUSIP
		, SimpleValue
		, WebPage
		' + @additionalFieldColumn + '
		, CurrentEffectiveDate
		, CurrentClosePrice
		, PriorEffectiveDate
		, PriorClosePrice 
		, ISNULL(CurrentClosePrice, 0) - ISNULL(PriorClosePrice, 0) AS Change
		, ' + @pctChange + '  AS PctChange
	FROM With_PriorPrice
	';

	-- DYNAMICALLY ADD WHERE CLAUSES
	SELECT @sql_cte_statement = REPLACE(@sql_cte_statement, '[POSITIONWHERE]', @where)

	-- DYNAMICALLY ADD ORDER BY CLAUSES
	IF (@Sort = 0) -- TopHoldings
	BEGIN
		SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY SimpleValue DESC'
	END
	
	ELSE IF (@Sort = 1) -- Best
	BEGIN
		SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY ' + @pctchange + ' DESC'
	END
	
	ELSE IF (@Sort = 2) -- Worst
	BEGIN
		SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY ' + @pctchange + ' ASC'
	END
	
	ELSE IF (@Sort = 3) -- Best/Worst
	BEGIN
		SELECT @sql_cte_statement = @sql_cte_statement + CHAR(13) + CHAR(10) + 'ORDER BY ABS(' + @pctchange + ') DESC'
	END

	-- RUN STAEMENT
	EXEC sp_executesql 
		@sql_cte_statement
		, @sql_cte_params
		, @Parameters = @Parameters
		, @FilterHouseholdIDs=@FilterHouseholdIDs
		, @FilterClientIDs=@FilterClientIDs
		, @FilterAccountIDs=@FilterAccountIDs
		, @FilterAccountSubTypes=@FilterAccountSubTypes
		, @FilterCustodianIDs=@FilterCustodianIDs
		, @FilterManagerIDs=@FilterManagerIDs
		, @FilterFeeScheduleIDs=@FilterFeeScheduleIDs
		, @FilterTargetModelIDs=@FilterTargetModelIDs
		, @FilterSecurityIDs=@FilterSecurityIDs
		, @FilterSimpleSecurityTypes=@FilterSimpleSecurityTypes
		, @FilterSecuritySubTypes=@FilterSecuritySubTypes
		, @FilterSecurityCountries=@FilterSecurityCountries
		, @FilterSecurityCurrencies=@FilterSecurityCurrencies
		, @FilterClassIDs=@FilterClassIDs
		, @FilterClassificationIDs=@FilterClassificationIDs
		, @FilterSectorIDs=@FilterSectorIDs
		, @FilterIndustryIDs=@FilterIndustryIDs
		, @FilterGroup1IDs=@FilterGroup1IDs
		, @FilterGroup2IDs=@FilterGroup2IDs
		, @FilterGroup3IDs=@FilterGroup3IDs
		, @FilterClientTenures=@FilterClientTenures
		, @FilterClientAges=@FilterClientAges
		, @FilterClientStates=@FilterClientStates
		, @FilterClientCountries=@FilterClientCountries
		, @FilterHouseholdGroupIDs=@FilterHouseholdGroupIDs
		, @FilterClientGroupIDs=@FilterClientGroupIDs
		, @FilterAccountGroupIDs=@FilterAccountGroupIDs
		, @FilterSecurityGroupIDs=@FilterSecurityGroupIDs
		, @FilterClientBirthdays=@FilterClientBirthdays
		, @FilterFolioIDs=@FilterFolioIDs

	
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