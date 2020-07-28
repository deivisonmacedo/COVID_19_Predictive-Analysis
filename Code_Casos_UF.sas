cas mysess;
caslib _all_ assign;

/*Partir da base de UF da Mari*/
/*Here, you can use the data obtained from the code "CycleDayUF_ENG"*/
data casuser.covid_uff_livia;
	set covid.covid_uff;
	casos_lag=lag(casosacumulados);
	obitos_lag=lag(obitosacumulados);
run;

/*Calculate the field with new cases and deaths by states*/
data casuser.covid_uff_livia;
	set casuser.covid_uff_livia;
	if casosacumulados >= casos_lag then do;
		novos_casos=casosacumulados-casos_lag;
	end;
	if novos_casos=. then novos_casos=casosacumulados;

	if obitosacumulados >= obitos_lag then do;
		novos_obitos=obitosacumulados-obitos_lag;
	end;
	if novos_obitos=. then novos_obitos=obitosacumulados;
run;

/*Save and promote the table*/
proc casutil;
	droptable incaslib=covid casdata="COVID_UFF_LIVIA";
	promote incaslib=casuser casdata="COVID_UFF_LIVIA"
		outcaslib=covid casout="COVID_UFF_LIVIA";
	save incaslib=covid casdata="COVID_UFF_LIVIA"
		outcaslib=covid casdata="COVID_UFF_LIVIA"
		replace;
quit;