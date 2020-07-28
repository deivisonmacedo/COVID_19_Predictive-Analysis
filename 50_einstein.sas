cas mysess;
caslib _all_ assign;



/* proc cardinality data=PUBLIC.COVID_EINSTEIN2(where=(covid='positive')) maxlevels=254  */
/* 		outcard=public.covdi_einstein2_vars; */
/* run; */
/*  */
/* proc print data=public.covdi_einstein2_vars label; */
/* 	var _varname_ _fmtwidth_ _type_ _rlevel_ _more_ _cardinality_ _nmiss_ _min_  */
/* 		_max_ _mean_ _stddev_; */
/* 	title 'Variable Summary'; */
/* run; */



/* 1352 obs */
/* proc fedsql sessref=mysess; */
/* select sum(1) from public.covid_einstein2 where */
/* var016 is not null and */
/* var017 is not null and */
/* var018 is not null and */
/* var019 is not null and */
/* var020 is not null and */
/* var021 is not null and */
/* var023 is not null and */
/* var024 is not null and */
/* var025 is not null and */
/* var026 is not null and */
/* var027 is not null and */
/* var028 is not null and */
/* var029 is not null and */
/* var030 is not null and */
/* var031 is not null and */
/* var032 is not null and */
/* var033 is not null; */
/* quit; */



/* 598 obs */
proc fedsql sessref=mysess;
create table wk00 {options replace=true} as select
patient,
age,
covid,
treatment,
var001,
var002,
var003,
var004,
var005,
var006,
var007,
var008,
var009,
var010,
var011,
var012,
var013,
var014
from covid.covid_einstein where
var001 is not null and
var002 is not null and
var003 is not null and
var005 is not null and
var006 is not null and
var007 is not null and
var008 is not null and
var009 is not null and
var010 is not null and
var011 is not null and
var012 is not null and
var013 is not null and
var014 is not null and
var004 is not null ;
select sum(1) from wk00;
quit;

proc casutil;
droptable incaslib=covid casdata='covid_einstein_sel'
		  quiet;
promote incaslib=casuser casdata='wk00'
		outcaslib=covid casout='covid_einstein_sel';
save incaslib=covid casdata='covid_einstein_sel'
	 outcaslib=covid casout='covid_einstein_sel'
	 replace;
quit;
