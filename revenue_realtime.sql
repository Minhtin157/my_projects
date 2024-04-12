SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER Proc [dbo].[exercise] 
        @fromdate    DATE,
           @todate      DATE,
        @StoreNo            NVARCHAR(10),
        @Category            NVARCHAR(MAX),
        @Product            NVARCHAR(MAX),
        @Season             NVARCHAR(MAX),
        @Invoice            NVARCHAR(50)
AS
BEGIN 

SET NOCOUNT ON;
    DECLARE @StoreTable AS TABLE (LocationCode nvarchar(10),_value nvarchar(500),StartDate date, EndDate date,StoreNo nvarchar(10))
    INSERT INTO @StoreTable
    SELECT LocationCode,value, T2.StartDate, T2.EndDate, T2.StoreNo
    FROM string_split(@StoreNo,',') T1
        INNER JOIN DW.dbo.AllStore T2 ON T2.Company = 'Routine' AND T1.[value] = T2.StoreNo COLLATE DATABASE_DEFAULT

Select * From (
            SELECT
                ISNULL(ISNULL( H1.No_, H2.No_),H3.No_) as 'Post Invoice No_',
                SalesHeader.[Store No_],
                SalesHeader.[No_] as 'Bill/SO/RSO',
                SalesLine.[Item Category Code] as 'Category',
                SalesLine.[No_] as 'Item No',
                SalesLine.[Variant Code] as 'Variant Code',
                ItemVariant.[Item No_],
                ItemVariant.[Variant],
                ItemVariant.[Variant Dimension 1] as 'Color',
                ItemVariant.[Variant Dimension 2] as 'Size',
                SalesLine.Quantity as 'Quantity',
                CASE WHEN SalesHeader.No_ LIKE 'SR%' THEN  -1* SalesLine.[Amount] ELSE SalesLine.[Amount]  END as 'Net Amount',
                CASE WHEN SalesHeader.No_ LIKE 'SR%' THEN  -1* SalesLine.[Amount Including VAT] ELSE SalesLine.[Amount Including VAT] END as 'Gross Amount',
                CASE WHEN SalesHeader.No_ LIKE 'SR%' THEN  -1*SalesLine.[Line Discount Amount] ELSE SalesLine.[Line Discount Amount] END 'Discount Amount'
                
            FROM ([DW].[dbo].[HO$Sales Header] as SalesHeader WITH(NOLOCK)
                INNER JOIN [DW].[dbo].[HO$Sales Line] as SalesLine WITH(NOLOCK) on SalesHeader.No_ = SalesLine.[Document No_]
                INNER JOIN @StoreTable ST ON SalesHeader.[Location Code] = ST.LocationCode AND SalesHeader.[Posting Date] BETWEEN ST.StartDate AND ST.EndDate
                INNER JOIN [DW].[dbo].[HO$Item] as Item WITH(NOLOCK) on SalesLine.No_ = Item.No_
                INNER JOIN [DW].[dbo].[HO$Item Variant Registration] as ItemVariant WITH(NOLOCK) on SalesLine.[No_] =  ItemVariant.[Item No_] 
                                                                                    and SalesLine.[Variant Code] = ItemVariant.[Variant]
                LEFT JOIN (
                        SELECT No_, [Order No_] FROM DW.dbo.[HO$Sales Invoice Header] WITH(NOLOCK)
                        UNION ALL
                        SELECT No_, [Return Order No_] FROM DW.dbo.[HO$Sales Cr_Memo Header] WITH(NOLOCK)
                    ) H1 ON H1.[Order No_] = SalesHeader.No_
                    LEFT JOIN (SELECT No_, [Return Order No_],[External Document No_],[Sell-to Customer No_]
                                FROM DW.dbo.[HO$Sales Cr_Memo Header]  WITH(NOLOCK)
                                WHERE [Return Order No_] = '' AND ISNUMERIC([External Document No_]) = 0 
                            ) H2 ON SalesHeader.[External Document No_] = H2.[External Document No_]       
                    LEFT JOIN (
                            SELECT No_, [Return Order No_],[External Document No_],[Sell-to Customer No_]
                            FROM DW.dbo.[HO$Sales Cr_Memo Header]  WITH(NOLOCK)
                            WHERE [Return Order No_] = ''AND ISNUMERIC([External Document No_]) = 1
                    ) H3 ON SalesHeader.[Magento Order ID] = H3.[External Document No_] )) Q1
        WHERE Q1.[Store No_]  IN (Select value from string_split(@StoreNo,',') where RTRIM(value)<>'')
        AND ((@Invoice = 'Posted'AND [Post Invoice No_] IS NOT NULL)
            OR (@Invoice = 'NonePosted' AND [Post Invoice No_] IS NULL)
            OR (@Invoice = 'All' AND 1=1))
            END