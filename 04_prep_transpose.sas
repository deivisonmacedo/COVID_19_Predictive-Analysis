cas mysess;
caslib _all_ assign;

/* creating the tranposed by country and cycle day */
proc transpose data=covid.covid_acc out=wk00(replace=yes);
	by country cycleday;
	var cases deaths acc_cases acc_deaths
		pct_cases pct_deaths pct_acc_cases pct_acc_deaths
		rat_cases rat_deaths;
run;

/* sorting the data by country */
proc transpose data=wk00 out=wk01(replace=yes);
	by country notsorted;
	id _name_ cycleday;
	var col1;
run;

/* creating a new lib and saving the data locally*/
libname sprecov '/sasdata/covid';
data sprecov.wk01(replace=yes);
set wk01(drop=_name_);
run;

/* droping the old data, saving the new one and loading to cas */
proc casutil;
droptable incaslib=casuser casdata='wk01'
		  quiet;
load file="/sasdata/covid/wk01.sas7bdat" 
	 outcaslib=casuser casout="wk01";
run;

/* creating the vars of desinty and avg_age of each country */
proc fedsql sessref=mysess;
create table wk02 {options replace=true} as select
	a.*,
	b.population as population,
	b.density as density,
	b.avgage as avg_age,
	b.urbanpop as urban_pop
from wk01 as a
left join covid.pop as b
on a.country = b.country;
select sum(1) from wk02;
quit;

/* saving the data and loading to cas */
proc casutil;
droptable incaslib=covid casdata='covid_acc_tpd'
		  quiet;
promote incaslib=casuser casdata='wk02'
		outcaslib=covid casout='covid_acc_tpd';
save incaslib=covid casdata='covid_acc_tpd'
	 outcaslib=covid casout='covid_acc_tpd'
	 replace;
quit;

