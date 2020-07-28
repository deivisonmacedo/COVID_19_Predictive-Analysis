
cas mysess;
caslib _all_ assign;

/* transformando char em numerico */
data casuser.covid_all;
	set covid.PorAll ;
	casosAcumulados=input(put(casosacumulado,$CHAR18.),COMMAX18.);;
    obtiosAcumulados=input(put(obitosacumulado,$CHAR18.),COMMAX18.);;
run;

/*tirando casos=0 e ordenando*/
data casuser.covid_all;
	set casuser.covid_all ;
	if casosAcumulados=0 then delete;
run;
proc sort data=casuser.covid_all;
	by casosAcumulados;
run;

/* criando o ciclo no all */
data casuser.covid_all2;
	set casuser.covid_all;
if first.codmun   then	
	CYCLEDAY= 0 ;
	 CYCLEDAY+1;
by codmun estado data ;
run;

/* promovendo all */
proc casutil;
	droptable incaslib=covid casdata="covid_all"; /* quando eu ja tiver ela alguma vez */
	promote incaslib=casuser casdata="covid_all2"
		outcaslib=covid casout="covid_all";
	save incaslib=covid casdata="covid_all"
		outcaslib=covid casout="covid_all"
		replace;
quit;


/* agrupando por uf */


cas mysess;
caslib _all_ assign;

proc fedsql sessref=mysess ;
create table casuser.covid_uf11   as
select 
	regiao as regiao, 
	estado AS estado,
	data as data,
	sum(casosAcumulados) as CasosAcumulados,
	sum(obtiosAcumulados) as ObitosAcumulados 
from casuser.covid_all
where estado <> . and municipio = . and populacaoTCU2019 <> .
group by regiao, estado, data;
quit;

proc sort data=casuser.covid_uf11;
	by  estado data;
run;

/* criando o ciclo por uf */
data casuser.covid_uff12;
	set casuser.covid_uf11;
if first.estado   then	
	CYCLEDAY= 0 ;
	 CYCLEDAY+1;
by  estado data ;
run;

/* promovendo uf */

proc casutil;
	/*droptable incaslib=covid casdata="covid_uf11"; /* quando eu ja tiver ela alguma vez */
	promote incaslib=casuser casdata="covid_uff12"
		outcaslib=covid casout="covid_uff";
	save incaslib=covid casdata="covid_uff"
		outcaslib=covid casout="covid_uff"
		replace;
quit;