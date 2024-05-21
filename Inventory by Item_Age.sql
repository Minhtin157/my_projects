--- Tuổi hàng vào tháng 04/2024
 SELECT [ItemNo]
      ,[FirstDateInputWH]
      ,CASE
WHEN LEFT([ItemNo],2) <> '10' then N'6. Nhóm tồn cũ lâu năm'
WHEN DATEDIFF(DAY, FirstDateInputWH, '2024-04-01') > 540 then N'5. Nhóm hàng trên 18 tháng tuổi'
WHEN DATEDIFF(DAY, FirstDateInputWH, '2024-04-01') > 360 then N'4. Nhóm hàng 12-18 tháng tuổi'
WHEN DATEDIFF(DAY, FirstDateInputWH, '2024-04-01') > 180 then N'3. Nhóm hàng 6-12 tháng tuổi'
WHEN DATEDIFF(DAY, FirstDateInputWH, '2024-04-01') > 90 then N'2. Nhóm hàng 3-6 tháng tuổi'
WHEN DATEDIFF(DAY, FirstDateInputWH, '2024-04-01') > 0 then N'1. Nhóm hàng 0-3 tháng tuổi' end as Item_Age
-- INTO [DW_IMPORT].[dbo].[FirstPostingDate_0424]
  FROM [DW].[dbo].[FistDateInputItem]
  WHERE LEFT([Category],2) = '10' and FirstDateInputWH is not null

--- #temp_Location 
 SELECT distinct [Location Code]
 INTO  #temp_Location
 FROM DW_IMPORT.dbo.[Inventory] 
 WHERE ([Location Code] like 'R%' or [Location Code] in ('ONLINE', 'WH31', 'WH11')) and [Location Code] not like 'R%L'

---- Tạo bảng gốc tồn kho hàng tháng
SELECT DISTINCT
       T3.Item_Age,
       T3.[FirstDateInputWH]
       ,T1.No_ AS ItemNo
       ,T1.[Attrib 1 Code] Season, 
       T1.[Item Category Code], 
       T1.[Product Group Code], 
       T2.ValueName_VN,
       1 as Month,
       2024 as Year
-- INTO   DW_IMPORT.dbo.Inventory_Tin
FROM DW.dbo.[HO$Item] T1 
        --INNER JOIN [Fact.Inventory] T2 ON T1.No_ = T2.[Item No_] 
INNER JOIN [DW_IMPORT].[dbo].[FirstPostingDate_0124] T3 WITH(NOLOCK) on T1.No_ = T3.[ItemNo] 
FULL OUTER JOIN  DW.dbo.[Dim.TonKhoValueName] T2 ON 1=1
WHERE Item_Age is not null
ORDER BY ItemNo,
 [FirstDateInputWH] desc


--Tồn đầu tháng
DECLARE @Month int = 2, @Year int = 2024, @Startdate date, @Enddate date
SET @Startdate = DATEFROMPARTS(@Year, @Month, 1)
-- SET @Enddate = EOMONTH(@Startdate)
UPDATE T1 SET T1.[Value] = A
FROM DW_IMPORT.dbo.Inventory_Tin T1
INNER JOIN (
    SELECT I1.[Item No_], SUM(Quantity) A 
    FROM DW_IMPORT.dbo.[Inventory] I1 
    INNER JOIN  #temp_Location L ON I1.[Location Code] = L.[Location Code] 
    WHERE  [Posting Date] < @Startdate 
    GROUP BY  I1.[Item No_]) T2 ON T1.ItemNo = T2.[Item No_]  AND T1.ValueName_VN = N'Tồn đầu tháng' AND T1.[Month] = @Month AND T1.[Year] = @Year

--- Tổng  xuất
DECLARE @Month int = 1, @Year int = 2024, @Startdate date, @Enddate date
SET @Startdate = DATEFROMPARTS(@Year, @Month, 1)
SET @Enddate = EOMONTH(@Startdate)
UPDATE T1 SET T1.[Value] = A
FROM DW_IMPORT.dbo.Inventory_Tin T1
INNER JOIN (
    SELECT [Item No_], SUM(Quantity) A 
    FROM DW_IMPORT.dbo.[Inventory] I1 
    INNER JOIN  #temp_Location L ON I1.[Location Code] = L.[Location Code] 
    WHERE  ([Posting Date] BETWEEN @Startdate and @Enddate)
    AND ( ([Document Type] = 1 AND [Entry Type] = 1) OR ([Document Type] = ''AND [Entry Type] = 1)) 
    GROUP BY  [Item No_]) T2 ON T1.ItemNo = T2.[Item No_] 
    WHERE T1.ValueName_VN = N'Tổng xuất bán' AND T1.[Month] = @Month AND T1.[Year] = @Year

--- Tổng  nhập
DECLARE @Month int = 3, @Year int = 2024, @Startdate date, @Enddate date
SET @Startdate = DATEFROMPARTS(@Year, @Month, 1)
SET @Enddate = EOMONTH(@Startdate)
UPDATE T1 SET T1.[Value] = A
FROM DW_IMPORT.dbo.Inventory_Tin T1
INNER JOIN (
    SELECT [Item No_], SUM(Quantity) A 
    FROM DW_IMPORT.dbo.[Inventory] I1 
    INNER JOIN  #temp_Location L ON I1.[Location Code] = L.[Location Code] 
    WHERE  ([Posting Date] BETWEEN @Startdate and @Enddate)
    AND (([Document Type] = 3 AND [Entry Type] = 1) OR ([Document Type] = 14 AND [Entry Type] = 9) OR [Entry Type] = 2) 
    GROUP BY  [Item No_]) T2 ON T1.ItemNo = T2.[Item No_] 
    WHERE T1.ValueName_VN = N'Tổng nhập khác' AND T1.[Month] = @Month AND T1.[Year] = @Year

--- Retail / Cost Price
DECLARE @Month int = 2, @Year int = 2024, @Startdate date, @Enddate date
SET @Startdate = DATEFROMPARTS(@Year, @Month, 1)
UPDATE T1 SET T1.[Value] = TotalInput
FROM DW_IMPORT.dbo.Inventory_Tin T1
INNER JOIN (
    SELECT DISTINCT No_, [Unit Price] TotalInput 
    FROM DW.dbo.[HO$Item] 
    -- WHERE  [Posting Date] < CONCAT(@Year,'-',@Month,'-01') GROUP BY  [Item No_]
    ) T2 ON T1.ItemNo = T2.[No_] 
    WHERE T1.ValueName_VN = N'Retail Price' AND T1.[Month] = @Month AND T1.[Year] = @Year

--- Giá trị tồn
DECLARE @Month int = 4, @Year int = 2024, @Startdate date, @Enddate date
SET @Startdate = DATEFROMPARTS(@Year, @Month, 1)
UPDATE T1 SET T1.[Value] = TotalInput
FROM DW_IMPORT.dbo.Inventory_Tin T1
INNER JOIN (
    SELECT DISTINCT No_, [Value], [Unit Price], [Value]*[Unit Price] TotalInput 
    FROM DW.dbo.[Dim.Item] T2
    INNER JOIN DW_IMPORT.dbo.Inventory_Tin T1 ON T1.ItemNo = T2.[No_]
    WHERE  T1.ValueName_VN = N'Tồn đầu tháng' 
    ) T2 ON T1.ItemNo = T2.[No_] 
    WHERE T1.ValueName_VN = N'Giá trị tồn by Retail Price' AND T1.[Month] = @Month AND T1.[Year] = @Year

-- Gender Item
UPDATE T1 SET T1.[Gender] = A
FROM DW_IMPORT.dbo.Inventory_Tin T1
INNER JOIN (
  SELECT [No_], CASE WHEN [Description] like N'%nữ%' then N'Nữ' else N'Nam' end as A
 FROM [DW].[dbo].[HO$Item]) T2 ON T1.ItemNo = T2.[No_] 


-- Run nháp
SELECT * FROM DW_IMPORT.dbo.Inventory_Tin T1
WHERe ItemNo = '10F20DPA103CR1'
ORDER BY Month
 [FirstDateInputWH] desc

--- Stored Procedure
ALTER PROC [dbo].[Inventory_Tin]
    @Month      NVARCHAR(MAX),
    @Year       NVARCHAR(MAX),
    @Category   NVARCHAR(MAX),
    @PGCode     NVARCHAR(MAX),
    @Collection NVARCHAR(MAX),
    @Gender     NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [Item_Age],
I.[ItemNo],
[Season],
Gender,
FirstDateInputWH,
I.[Item Category Code],
I.[Product Group Code],
[Month],
C.Collection,
[Year],
I.[ValueName_VN],
[Value]
    FROM DW_IMPORT.dbo.Inventory_Tin I WITH(NOLOCK)
    LEFT JOIN [DW].[dbo].[Dim.Collection] C ON I.ItemNo = C.ItemNo
    LEFT JOIN [Dim.TonKhoValueName] N ON I.[ValueName_VN] = N.[ValueName_VN]
    WHERE Month <= @Month and Year = @Year 
    AND I.[Item Category Code] IN (Select value from string_split(@Category,',') where RTRIM(value)<>'')
    AND I.[Product Group Code] IN (Select value from string_split(@PGCode,',') where RTRIM(value)<>'') 
    AND C.Collection IN (Select value from string_split(@Collection,',') where RTRIM(value)<>'')
    AND Gender IN (Select value from string_split(@Gender,',') where RTRIM(value)<>'')
    ORDER BY Month, Item_Age, FirstDateInputWH, ItemNo, N.ID
END
GO


