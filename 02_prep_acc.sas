/* cas mySess; */
/* caslib _all_ assign; */

/* create a new data working and renaming the countries names */
data casuser.wk00;
set covid.covid;
country = propcase(tranwrd("countriesAndTerritories"n,'_',' '));
run;

/* joining the current data with the old one to insert the new country var */
proc fedsql sessref=mysess;
create table wk01 {options replace=true} as select
	coalesce(b.country, a.country) as country_std,
	a.*
from wk00 as a
left join covid.lookup_countries as b
on a.country = b.country1;
quit;

/* creating the data with the new variable and droping the wrong country var */
data casuser.wk02(replace=yes);
set casuser.wk01(drop=country);
rename country_std = COUNTRY;
run;

/* creating the pandemic var and joining the tables */
proc fedsql sessref=mySess;
create table wk03 {options replace=true} as select
	a.country as country,
	b.country as country2,
	a.daterep - b.datefirst + 1 as cycleday,
	a.daterep as fulldate,
	a.year as year,
	a.month as month,
	a.day as day,
	a.cases as cases,
	a.deaths as deaths
from wk02 as a
left join (
	select 
		country,
		min(daterep) as datefirst
	from wk02
	where cases > 0
	group by country
) as b
on
	a.country = b.country
where
	a.daterep >= b.datefirst;
select sum(1) from wk03;
quit;

/* creating the data with the accumulative vars */
proc fedsql sessref=mysess;
create table wk04 {options replace=true} as select
	country,
	cycleday,
	fulldate,
	year,
	month,
	day,
	sum(cases) as cases,
	sum(deaths) as deaths
from wk03
group by
	country,
	cycleday,
	fulldate,
	year,
	month,
	day;
select sum(1) from wk04;
quit;

/* creating the new data with the percents of cases and deaths */
data casuser.wk05(replace=yes);
set casuser.wk04;
fulldate = fulldate - 1;
by country cycleday;
if first.country then do;
	acc_cases = 0;
	acc_deaths = 0;
	rat_cases = 0;
	rat_deaths = 0;
end;
acc_cases + cases;
acc_deaths + deaths;
lcases = lag1(cases);
if lcases ne . and lcases ne 0 then
	rat_cases = cases/lcases - 1;
else
	rat_cases = 0;
ldeaths = lag1(deaths);
if ldeaths ne . and ldeaths ne 0 then
	rat_deaths = cases/ldeaths - 1;
else
	rat_deaths = 0;
drop lcases ldeaths;
run;

/* saving the data and loading to cas */
proc casutil;
droptable incaslib=covid casdata='covid_acc'
		  quiet;
promote incaslib=casuser casdata='wk05'
		outcaslib=covid casout='covid_acc'
		keep;
save incaslib=covid casdata='covid_acc'
	 outcaslib=covid casout='covid_acc'
	 replace;
quit;