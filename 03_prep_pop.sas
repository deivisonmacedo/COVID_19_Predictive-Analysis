/* cas mysess; */
/* caslib _all_ assign; */

/* creating the percents of total pop and joining data sets*/
proc fedsql sessref=mysess;
create table wk00 {options replace=true} as select
	a.*,
	a.cases / b.population as pct_cases,
	a.deaths / b.population as pct_deaths,
	a.acc_cases / b.population as pct_acc_cases,
	a.acc_deaths / b.population as pct_acc_deaths
from covid.covid_acc as a
left join covid.pop as b
on a.country = b.country;
quit;

/* saving and loading data into cas */
proc casutil;
droptable incaslib=covid casdata='covid_acc'
		  quiet;
promote incaslib=casuser casdata='wk00'
		outcaslib=covid casout='covid_acc'
		keep;
save incaslib=covid casdata='covid_acc'
	 outcaslib=covid casout='covid_acc'
	 replace;
quit;

/* creating and formatting the new var of date */
data casuser.wk01(replace=yes);
set casuser.wk00(drop=fulldate);
format FULLDATE yymmdd10.;
fulldate = cycleday-1;
run;

/* saving and loading data into cas */
proc casutil;
droptable incaslib=covid casdata='covid_acc2'
		  quiet;
promote incaslib=casuser casdata='wk01'
		outcaslib=covid casout='covid_acc2';
save incaslib=covid casdata='covid_acc2'
	 outcaslib=covid casout='covid_acc2'
	 replace;
quit;