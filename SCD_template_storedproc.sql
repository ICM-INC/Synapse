CREATE  PROC [dbo].[storedproc1_scd]
AS
begin transaction
  DECLARE @MaxSK BIGINT;  -- Declare variable to store the maximum DimID
  DECLARE @newdate varchar(10); -- Declare the date for the updated records
  -- Assign the maximum SK to the variable
  SELECT @MaxSK = MAX(DimFoodId) FROM dbo.Dimfood;
  -- now we use @MaxSK within the procedure body

-- SCD2 Insert the new records which do not exist

insert into dbo.Dimfood
  
    select 
    ROW_NUMBER() OVER(ORDER BY FoodNaturalId) + @MaxSK  AS DimFoodId,
        stage.*,
        CAST(CAST(getdate() as DATE) as VARCHAR(20)) as begindate,
        '9999-12-31' as enddate
    from dbo.Stagingfood as stage 
    where not exists 
   (select * from  dbo.Dimfood dim where dim.FoodNaturalId = stage.FoodNaturalId);

-- SCD2 Close off existing records that have changed
    SELECT @newdate = CAST(CAST(getdate() as DATE) as VARCHAR(10))

    update dbo.Dimfood
    set enddate = @newdate
    from dbo.Dimfood d 
    inner join dbo.Stagingfood stage on d.FoodNaturalId = stage.FoodNaturalId
    where (d.enddate = '9999-12-31' and (stage.FoodName <> d.FoodName or stage.FoodCategory <> d.FoodCategory) );

 -- SCD2 Insert the new updated records
 SELECT @MaxSK = MAX(DimFoodId) FROM dbo.Dimfood

    insert into dbo.Dimfood
    select 
    ROW_NUMBER() OVER(ORDER BY stage.FoodNaturalId) + @MaxSK  AS DimFoodId,
    stage.*,
    @newdate as begindate,
    '9999-12-31' as enddate
from dbo.Stagingfood stage 
inner join dbo.Dimfood d2
on d2.FoodNaturalId = stage.FoodNaturalId
and d2.enddate = @newdate;

commit transaction;