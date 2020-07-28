/* -------------------------------------------------------------- */
/* -------------------------------------------------------------- */
/* -- This code create a dataset called covid_uff that is used -- */
/* -- in "casos e mortes por ciclo por UF" ---------------------- */
/* -------------------------------------------------------------- */
/* -------------------------------------------------------------- */

cas mysess;
caslib _all_ assign;

/*Download csv from ministry of health with Brazilian cases
 and import to viya  */

/* sometimes some numeric variables in dataset was char. We need to transform in number */
/* transform char in number */
data casuser.covid_all;
	set covid.PorAll ;
	casosAcumulados=input(put(casosacumulado,$CHAR18.),COMMAX18.);;
    obtiosAcumulados=input(put(obitosacumulado,$CHAR18.),COMMAX18.);;
run;

/*Removinf casos=0 */
data casuser.covid_all;
	set casuser.covid_all (WHERE=(populacaoTCU2019 <> .)) ;
	if casosAcumulados=0 then delete;
run;

/* Group by uf */
proc fedsql sessref=mysess ;
create table casuser.covid_uf11 {options replace=true}  as
select 
	regiao as regiao, 
	estado AS estado,
	data as data,
	sum(casosacumulado) as CasosAcumulados,
	sum(obitosacumulado) as ObitosAcumulados 
from casuser.covid_all
where estado <> '' and municipio = '' 
group by regiao, estado, data ;
quit;

/* sorting by estado and data */
proc sort data=casuser.covid_uf11;
	by  estado data;
run;

/* Creating cycleday variable group by uf */
data casuser.covid_uff12;
	set casuser.covid_uf11;
if first.estado   then	
	CYCLEDAY= 0 ;
	 CYCLEDAY+1;
by  estado data ;
run;

/* promote and rename dataset */
proc casutil;
	droptable incaslib=covid casdata="covid_uff"; /* quando eu ja tiver ela alguma vez */
	promote incaslib=casuser casdata="covid_uff12"
		outcaslib=covid casout="covid_uff";
	save incaslib=covid casdata="covid_uff"
		outcaslib=covid casout="covid_uff"
		replace;
quit;