
cas mysess;
caslib _all_ assign;

/*Importar o csv do site do Ministério da Saúde - COVID_UF*/

/* base covid.porall importada manualmente */

/* transformando char em numerico */
data casuser.covid_all;
	set covid.PorAll ;
/*	casosAcumulados=input(put(casosacumulado,$CHAR18.),COMMAX18.);;
    obtiosAcumulados=input(put(obitosacumulado,$CHAR18.),COMMAX18.);;
*/run;

/*tirando casos=0 e ordenando*/
data casuser.covid_all;
	set casuser.covid_all (WHERE=(populacaoTCU2019 <> .)) ;
	if casosAcumulados=0 then delete;
run;

/* agrupando por uf */
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
/* Tabela no covid.covid_uff */
proc casutil;
	droptable incaslib=covid casdata="covid_uff"; /* quando eu ja tiver ela alguma vez */
	promote incaslib=casuser casdata="covid_uff12"
		outcaslib=covid casout="covid_uff";
	save incaslib=covid casdata="covid_uff"
		outcaslib=covid casout="covid_uff"
		replace;
quit;