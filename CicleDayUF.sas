
cas mysess;
caslib _all_ assign;

/*Importar o csv do site do Ministério da Saúde - COVID_UF*/

/* base covid.poruf importada manualmente */

data casuser.covid_uf;
	set covid.poruf ;
	if casosAcumulados=0 then delete;
run;

proc sort data=casuser.covid_uf;
	by casosAcumulados;
run;

data casuser.covid_uf2;
	set casuser.covid_uf;
if first.estado then	
	CYCLEDAY= 0 ;
	 CYCLEDAY+1;
by estado data ;
run;


proc casutil;
	droptable incaslib=covid casdata="Covid_uf"; /* quando eu ja tiver ela alguma vez */
	promote incaslib=casuser casdata="covid_uf2"
		outcaslib=covid casout="covid_uf";
	save incaslib=covid casdata="covid_uf"
		outcaslib=covid casout="covid_uf"
		replace;
quit;