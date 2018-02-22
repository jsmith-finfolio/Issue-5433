use JAG
go

DECLARE @TestingTopX INT = 100
DECLARE @TestingSort INT = 1
DECLARE @TestingRecent INT = 5
DECLARE @TestingAdditionalField INT = 0

exec dbo.DashboardSecurityHeatMap_Optimized 
	  @TopX=@TestingTopX
	, @Sort=@TestingSort
	, @Recent=@TestingRecent
	, @AdditionalField=@TestingAdditionalField

exec dbo.DashboardSecurityHeatMap 
	  @TopX=@TestingTopX
	, @Sort=@TestingSort
	, @Recent=@TestingRecent
	, @AdditionalField=@TestingAdditionalField
