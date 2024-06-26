SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[InventorybyItem]
    @ItemNo NVARCHAR(MAX),
    @Variant NVARCHAR(MAX),
    @LocationCode NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        I.[Item No_],
        I.[Location Code], 
        I.[Variant Code], 
        Item.SIZE,
        Item.[Unit Price],
        Item.[COLOR],
        V.Barcode,
        Item.[Description],
        Item.[Product Group Code],
        SUM(I.Quantity) as Quantity
    FROM 
        [Fact.Inventory] AS I WITH(NOLOCK) 
    LEFT JOIN 
        [Dim.Item] AS Item WITH(NOLOCK) ON Item.SKU = I.SKU
    LEFT JOIN 
        [Dim.Variant] AS V WITH(NOLOCK) ON V.Variant = Item.[Variant Code] AND V.[Item No_] = I.[Item No_]
    WHERE 
        I.[Item No_] IN (Select value from string_split(@ItemNo,',') where LTRIM(RTRIM(value))<>'')
        AND I.[Location Code] IN (Select value from string_split(@LocationCode,',') where LTRIM(RTRIM(value))<>'')
        AND (@Variant IS NULL OR I.[Variant Code] IN (Select value from string_split(@Variant,',') where LTRIM(RTRIM(value))<>''))
    GROUP BY
        I.[Item No_],
        I.[Location Code], 
        I.[Variant Code],
        Item.SIZE,
        Item.[Unit Price],
        Item.[COLOR],
        V.Barcode,
        Item.[Description],
        Item.[Product Group Code]
    HAVING SUM(Quantity) <> 0
    ORDER BY I.[Variant Code], i.[Location Code]
END;
GO