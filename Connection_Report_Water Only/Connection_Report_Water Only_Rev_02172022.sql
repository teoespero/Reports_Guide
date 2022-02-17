-------------------------------------------------------------------------------
-- Conservation Water Connections Report
-- Date written: 02/17/2022
-- By Teo Espero (IT Administrator, MCWD)
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- PRE-REQUISITES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Water service codes
--	These are the service rate codes that are attached to a water concection 
--	account...
-------------------------------------------------------------------------------
select 
distinct
	SUBSTRING(service_code,1,2) as ServicePrefix,
	[description]
from ub_service
where
	bill_type like 'Water'
order by
	[description]

-------------------------------------------------------------------------------
-- select service rates that we will be using
-- all water excluding:
--		- Cap S/Chg
--		- Recycled Water
--		- TA
-------------------------------------------------------------------------------
select 
distinct
	service_code,
	[description]
from ub_service
where
	bill_type like 'Water'
	and service_code not like 'WC%'
	and service_code not like 'RW%'
	and service_code not like 'TA%'



-------------------------------------------------------------------------------
-- 1 generate a list of accounts that are water only
-------------------------------------------------------------------------------
select 
	distinct
	replicate('0', 6 - len(srv.cust_no)) + cast (srv.cust_no as varchar)+ '-'+replicate('0', 3 - len(srv.cust_sequence)) + cast (srv.cust_sequence as varchar) as AccountNum
	into #water01
from ub_service_rate srv
where
	service_code in (
	select distinct
		service_code
	from ub_service
	where
		bill_type like 'Water'
		and service_code not like 'WC%'
		and service_code not like 'RW%'
		and service_code not like 'TA%'
	)
order by
	replicate('0', 6 - len(srv.cust_no)) + cast (srv.cust_no as varchar)+ '-'+replicate('0', 3 - len(srv.cust_sequence)) + cast (srv.cust_sequence as varchar)

select *
from #water01

-------------------------------------------------------------------------------
-- 2 using the list of accounts, generate a table that contains their lot no
-------------------------------------------------------------------------------
select 
	distinct
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) as accountnum,
	mast.connect_date,
	mast.final_date,
	mast.lot_no
	into #water02
from ub_master mast
where
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) in (
	select AccountNum from #water01
	)
order by
	mast.lot_no

select *
from #water02

-------------------------------------------------------------------------------
-- 3 gather rows that are connected before EOY 2021
-- filter between
--		connect date < 12/31/2021
--		final date is null or 
--		FinalDate >= '01/01/2021' and FinalDate <= '12/31/2021'
-------------------------------------------------------------------------------
select *
into #water03
from #water02
where
	connect_date <= '12/31/2021' 
	and ((final_date >= '01/01/2021' and final_date <= '12/31/2021') or final_date is null)
order by
	lot_no

select *
from #water03
order by
	lot_no,
	connect_date,
	final_date

-------------------------------------------------------------------------------
-- 4 get the latest lot connectdate
-- note that a series of lot may have several accounts attached to it
-- but we will only get the account that is the latest for that lot no
-------------------------------------------------------------------------------
select 
	t.accountnum,
	t.connect_date,
	t.final_date,
	t.lot_no
	into #water04
from #water03 t
inner join (
	select lot_no, 
	max(connect_date) as MaxDate
	--max(transaction_id) as MaxTrans
    from #water03
    group by lot_no
) tm 
on 
	t.lot_no = tm.lot_no
	--and t.tran_date = tm.MaxDate 
	and t.connect_date=tm.MaxDate
--and t.AccountNum = '017226-000'
order by
	t.lot_no,
	t.connect_date

select *
from #water04
order by lot_no

-------------------------------------------------------------------------------
-- 5 generate our final table
--		Note that only the main account for Bay View is listed
-------------------------------------------------------------------------------
select 
	lot.misc_2 as STCategory,
	lot.misc_1 as Boundary,
	lot.misc_5 as Subdvision,
	lot.misc_16 as Irrigation,
	lot.lot_no,
	w.accountnum,
	CONVERT(varchar(10),w.connect_date,101) as connect_date,
	CONVERT(varchar(10),w.final_date,101) as final_date,
	lot.lot_status,
	lot.street_number + lot.street_name + lot.addr_2+lot.description as [Other info about connection]
from #water04 w
inner join lot
	on lot.lot_no=w.lot_no
	and (w.final_date between '01/01/2021' and '12/31/2021' or w.final_date is null)
	and lot.misc_5 <> 'Bay View'
union
select 
	lot.misc_2 as STCategory,
	lot.misc_1 as Boundary,
	lot.misc_5 as Subdvision,
	lot.misc_16 as Irrigation,
	lot.lot_no,
	w.accountnum,
	CONVERT(varchar(10),w.connect_date,101) as connect_date,
	CONVERT(varchar(10),w.final_date,101) as final_date,
	lot.lot_status,
	lot.street_number + lot.street_name + lot.addr_2+lot.description as [Other info about connection]
from #water04 w
inner join lot
	on lot.lot_no=w.lot_no
	and (w.final_date between '01/01/2021' and '12/31/2021' or w.final_date is null)
	and accountnum='000990-000'
order by
	lot.misc_2
	


-------------------------------------------------------------------------------
-- Temporary Table Cleanup
-------------------------------------------------------------------------------
drop table #water01
drop table #water02
drop table #water03
drop table #water04
-------------------------------------------------------------------------------