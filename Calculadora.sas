Libname CALC "/sasdata/covid/calc/";
%LET DIAS=11;
%let Hoje=%sysfunc(today(),date9.);
%LET CALC = %SYSFUNC (CAT(/sasdata/covid/calc/&Hoje.,_CALCULADORA, .csv));
%LET EVOL_CASOS = %SYSFUNC (CAT(/sasdata/covid/calc/&Hoje.,_EVOL_CASOS, .csv));
%LET EVOL_OBITOS = %SYSFUNC (CAT(/sasdata/covid/calc/&Hoje.,_EVOL_OBITOS, .csv));

/*********************************************************************************************/;
/**************************** DOWNLOAD DADOS ***********************************************/;
/*********************************************************************************************/;

/* download CSV */
filename seade temp;
proc http
	url="https://raw.githubusercontent.com/seade-R/dados-covid-sp/master/data/dados_covid_sp.csv"
	method="GET"
	out=seade;
run;

/* import to a SAS data set */
options validvarname=any;
proc import 
	file=seade
	out=work.SP0 replace
	dbms=csv;
	delimiter=';';
	guessingrows=10000;
run;

PROC SQL;
   CREATE TABLE HIST AS 
   SELECT t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.LAT1, 
          t1.LONG1, 
          t1.POPULACAO, 
          MDY(t2.MES,t2.DIA,2020) FORMAT=DATE9. AS DATA,
		  IFN(t2.CASOS='NA',0,INPUT(t2.casos,8.)) AS CASOS,
		  IFN(t2.OBITOS='NA',0,INPUT(t2.obitos,8.)) AS OBITOS
   FROM CALC.POPULACAO_MUNICIPIOS t1
   INNER JOIN WORK.SP0 t2 
   ON t1.COD_UFMUN = INPUT(SUBSTR(t2.codigo_ibge,1,6),6.);
QUIT;

/* CSV COM ERRO, CORREÇÃO */

PROC SQL;
   CREATE TABLE CALC.CASOS_COVID_MUNIC_HIST AS 
   SELECT distinct t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.DATA, 
		  t1.POPULACAO,
            (MAX(t1.OBITOS)) AS OBITOS, 
            (MAX(t1.CASOS)) AS CASOS
      FROM HIST t1
      GROUP BY t1.COD_UFMUN,
               t1.NOME_MUNICIPIO,
               t1.DATA;
QUIT;

/*** Quantitativos Estados ******/

PROC SQL;
   CREATE TABLE CALC.CASOS_COVID_ESTAD_HIST AS 
   SELECT  (999999) AS COD_UFMUN, 
            ('Estado de São Paulo') AS NOME_MUNICIPIO, 
            t1.DATA, 
            (SUM(t1.OBITOS)) AS OBITOS, 
            (SUM(t1.CASOS)) AS CASOS, 
            (46193726) AS POPULACAO
      FROM CALC.CASOS_COVID_MUNIC_HIST t1
      GROUP BY (CALCULATED COD_UFMUN),
               (CALCULATED NOME_MUNICIPIO),
               t1.DATA,
               (CALCULATED POPULACAO);
QUIT;

/*********************************************************************************************/;
/************************ CALCULADORA MUNICIPIOS ***********************************************/;
/*********************************************************************************************/;


/* Seleciona as últimas datas */

PROC SQL;
   CREATE TABLE WORK.ULTIMA_DATA AS 
   SELECT DISTINCT t1.COD_UFMUN, 
          t1.DATA AS DATA2, 
          t1.CASOS AS CASOS2, 
          t1.OBITOS AS OBITOS2
      FROM CALC.CASOS_COVID_MUNIC_HIST t1
      WHERE t1.DATA >= TODAY()-&DIAS.;
QUIT;

/* Verifica de naquela data já havia dobrado e calcula os novos casos */

PROC SQL;
   CREATE TABLE WORK.DIAS_COM_CASOS AS 
   SELECT t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.POPULACAO, 
          t1.DATA AS DATA1, 
          t2.DATA2, 
            (CASE WHEN (t2.CASOS2/t1.CASOS-1)<= 1 THEN 1 ELSE 0 END) AS NAO_DOBROU, 
            (CASE WHEN t2.DATA2=TODAY()-1 AND t1.DATA=TODAY()-2 THEN t2.CASOS2-t1.CASOS ELSE 0 END) AS CASOS_NOVOS, 
            (CASE WHEN t2.DATA2=TODAY()-1 AND t1.DATA=TODAY()-2 THEN t2.OBITOS2-t1.OBITOS ELSE 0 END) AS OBITOS_NOVOS, 
            (MAX(t2.CASOS2)) AS CASOS_ACUMULADOS, 
            (MAX(t2.OBITOS2)) AS OBITOS_ACUMULADOS
      FROM CALC.CASOS_COVID_MUNIC_HIST t1
           INNER JOIN WORK.ULTIMA_DATA t2 ON (t1.COD_UFMUN = t2.COD_UFMUN)
      WHERE t1.CASOS > 0 AND t2.DATA2 > t1.DATA
      GROUP BY t1.COD_UFMUN
      ORDER BY t1.NOME_MUNICIPIO,
               t2.DATA2,
               t1.DATA;
QUIT;

/* Soma quantos dias demorou para dobrar por dia e por município */

PROC SQL;
   CREATE TABLE WORK.DIAS_ULTIMA_DOBRA AS 
   SELECT DISTINCT t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.POPULACAO, 
          t1.DATA2, 
            (SUM(t1.NAO_DOBROU)+1) AS DIAS_ULTIMA_DOBRA, 
            ((SUM(t1.OBITOS_NOVOS))) AS OBITOS_NOVOS, 
            ((SUM(t1.CASOS_NOVOS))) AS CASOS_NOVOS, 
          t1.CASOS_ACUMULADOS, 
          t1.OBITOS_ACUMULADOS
      FROM WORK.DIAS_COM_CASOS t1
      GROUP BY t1.COD_UFMUN,
               t1.DATA2;
QUIT;

/* Média dos ultimos dias até dobrar */
PROC SQL;
   CREATE TABLE WORK.DIAS_ATE_DOBRA AS 
   SELECT DISTINCT t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.POPULACAO, 
          /* DIAS_ATE_DOBRA */
            (AVG(t1.DIAS_ULTIMA_DOBRA)) AS DIAS_ATE_DOBRA, 
          /* CASOS_NOVOS */
            (MAX(t1.CASOS_NOVOS)) AS CASOS_NOVOS, 
          /* OBITOS_NOVOS */
            (MAX(t1.OBITOS_NOVOS)) AS OBITOS_NOVOS, 
          t1.CASOS_ACUMULADOS, 
          t1.OBITOS_ACUMULADOS
      FROM WORK.DIAS_ULTIMA_DOBRA t1
      GROUP BY t1.COD_UFMUN;
QUIT;
/* Calcula a taxa de crescimento por dia*/

DATA CRESCIMENTO;
FORMAT TX_CRESC 6.4;
SET CALC.CASOS_COVID_MUNIC_HIST;
BY COD_UFMUN DATA;
LAG_CASOS=ifn(first.COD_UFMUN,0,lag(CASOS));
TX_CRESC=(CASOS/LAG_CASOS);
DROP LAG_CASOS;
RUN;

/* Calcula a média de crescimento apenas dos últimos dias antes de dobrar */

PROC SQL;
   CREATE TABLE WORK.TX_CRESC_MEDIO AS 
   SELECT t1.COD_UFMUN, 
            (AVG(t2.TX_CRESC)) FORMAT=6.4 AS TX_CRESC_MEDIO
      FROM WORK.DIAS_ATE_DOBRA t1
           INNER JOIN WORK.CRESCIMENTO t2 ON (t1.COD_UFMUN = t2.COD_UFMUN)
      WHERE t2.DATA > TODAY()-1-t1.DIAS_ATE_DOBRA
      GROUP BY t1.COD_UFMUN;
QUIT;

/* Calcula taxas médias */


PROC SQL;
   CREATE TABLE CALCULADORA_MUNIC AS 
   SELECT t2.COD_UFMUN, 
          t2.NOME_MUNICIPIO, 
          t2.CASOS_ACUMULADOS LABEL="Casos totais" AS CASOS_ACUMULADOS, 
          /* CASOS_POP */
            (ROUND(t2.CASOS_ACUMULADOS/t2.POPULACAO,0.00001)) LABEL="Casos totais/pop (%)" AS CASOS_POP, 
          t2.OBITOS_ACUMULADOS LABEL="Óbitos totais" AS OBITOS_ACUMULADOS, 
          /* OBITOS_POP */
            (ROUND(t2.OBITOS_ACUMULADOS/t2.POPULACAO,0.00001)) LABEL="Óbitos totais/pop (%)" AS OBITOS_POP, 
          /* TX_MORTALIDADE */
            (ROUND(t2.OBITOS_ACUMULADOS/t2.CASOS_ACUMULADOS,0.0001)) LABEL="Taxa de mortalidade" AS TX_MORTALIDADE, 
          t2.CASOS_NOVOS LABEL="Número de casos hoje" AS CASOS_NOVOS, 
          /* PERC_NOVOS_CASOS */
            (ROUND(t2.CASOS_NOVOS/t2.CASOS_ACUMULADOS,0.00001)) LABEL="% de novos casos" AS PERC_NOVOS_CASOS, 
          t2.OBITOS_NOVOS LABEL="Novos óbitos hoje" AS OBITOS_NOVOS, 
          /* PERC_NOVOS_OBITOS */
            (ROUND(t2.OBITOS_NOVOS/t2.OBITOS_ACUMULADOS,0.00001)) LABEL="% de novos óbitos" AS PERC_NOVOS_OBITOS, 
          /* DIAS ATE DOBRA */
			ROUND(t2.DIAS_ATE_DOBRA,0.01) AS DIAS_ATE_DOBRA LABEL="Casos dobrando a cada... (dias)" AS DIAS_ATE_DOBRA, 
          /* EM_7_DIAS */
            (ROUND(t2.CASOS_ACUMULADOS*t1.TX_CRESC_MEDIO**7)) LABEL="Total de casos em 7 dias" AS EM_7_DIAS, 
          /* EM_14_DIAS */
            (ROUND(t2.CASOS_ACUMULADOS*t1.TX_CRESC_MEDIO**14)) LABEL="Total de casos em 14 dias" AS EM_14_DIAS, 
          /* EM_30_DIAS */
            (ROUND(t2.CASOS_ACUMULADOS*t1.TX_CRESC_MEDIO**30)) LABEL="Total de casos em 30 dias" AS EM_30_DIAS
      FROM WORK.TX_CRESC_MEDIO t1
           INNER JOIN WORK.DIAS_ATE_DOBRA t2 ON (t1.COD_UFMUN = t2.COD_UFMUN);
QUIT;

/*********************************************************************************************/;
/************************ CALCULADORA ESTADOS ***********************************************/;
/*********************************************************************************************/;


/* Seleciona as últimas datas */

PROC SQL;
   CREATE TABLE WORK.ULTIMA_DATA AS 
   SELECT DISTINCT t1.COD_UFMUN, 
          t1.DATA AS DATA2, 
          t1.CASOS AS CASOS2, 
          t1.OBITOS AS OBITOS2
      FROM CALC.CASOS_COVID_ESTAD_HIST t1
      WHERE t1.DATA >= TODAY()-&DIAS.;
QUIT;

/* Verifica de naquela data já havia dobrado e calcula os novos casos */

PROC SQL;
   CREATE TABLE WORK.DIAS_COM_CASOS AS 
   SELECT t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.POPULACAO, 
          t1.DATA AS DATA1, 
          t2.DATA2, 
            (CASE WHEN (t2.CASOS2/t1.CASOS-1)<= 1 THEN 1 ELSE 0 END) AS NAO_DOBROU, 
            (CASE WHEN t2.DATA2=TODAY()-1 AND t1.DATA=TODAY()-2 THEN t2.CASOS2-t1.CASOS ELSE 0 END) AS CASOS_NOVOS, 
            (CASE WHEN t2.DATA2=TODAY()-1 AND t1.DATA=TODAY()-2 THEN t2.OBITOS2-t1.OBITOS ELSE 0 END) AS OBITOS_NOVOS, 
            (MAX(t2.CASOS2)) AS CASOS_ACUMULADOS, 
            (MAX(t2.OBITOS2)) AS OBITOS_ACUMULADOS
      FROM CALC.CASOS_COVID_ESTAD_HIST t1
           INNER JOIN WORK.ULTIMA_DATA t2 ON (t1.COD_UFMUN = t2.COD_UFMUN)
      WHERE t1.CASOS > 0 AND t2.DATA2 > t1.DATA
      GROUP BY t1.COD_UFMUN
      ORDER BY t1.NOME_MUNICIPIO,
               t2.DATA2,
               t1.DATA;
QUIT;

/* Soma quantos dias demorou para dobrar por dia e por município */

PROC SQL;
   CREATE TABLE WORK.DIAS_ULTIMA_DOBRA AS 
   SELECT DISTINCT t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.POPULACAO, 
          t1.DATA2, 
            (SUM(t1.NAO_DOBROU)+1) AS DIAS_ULTIMA_DOBRA, 
            ((SUM(t1.OBITOS_NOVOS))) AS OBITOS_NOVOS, 
            ((SUM(t1.CASOS_NOVOS))) AS CASOS_NOVOS, 
          t1.CASOS_ACUMULADOS, 
          t1.OBITOS_ACUMULADOS
      FROM WORK.DIAS_COM_CASOS t1
      GROUP BY t1.COD_UFMUN,
               t1.DATA2;
QUIT;

/* Média dos ultimos dias até dobrar */
PROC SQL;
   CREATE TABLE WORK.DIAS_ATE_DOBRA AS 
   SELECT DISTINCT t1.COD_UFMUN, 
          t1.NOME_MUNICIPIO, 
          t1.POPULACAO, 
          /* DIAS_ATE_DOBRA */
            (AVG(t1.DIAS_ULTIMA_DOBRA)) AS DIAS_ATE_DOBRA, 
          /* CASOS_NOVOS */
            (MAX(t1.CASOS_NOVOS)) AS CASOS_NOVOS, 
          /* OBITOS_NOVOS */
            (MAX(t1.OBITOS_NOVOS)) AS OBITOS_NOVOS, 
          t1.CASOS_ACUMULADOS, 
          t1.OBITOS_ACUMULADOS
      FROM WORK.DIAS_ULTIMA_DOBRA t1
      GROUP BY t1.COD_UFMUN;
QUIT;
/* Calcula a taxa de crescimento por dia*/

DATA CRESCIMENTO;
FORMAT TX_CRESC 6.4;
SET CALC.CASOS_COVID_ESTAD_HIST;
BY COD_UFMUN DATA;
LAG_CASOS=ifn(first.COD_UFMUN,0,lag(CASOS));
TX_CRESC=(CASOS/LAG_CASOS);
DROP LAG_CASOS;
RUN;

/* Calcula a média de crescimento apenas dos últimos dias antes de dobrar */

PROC SQL;
   CREATE TABLE WORK.TX_CRESC_MEDIO AS 
   SELECT t1.COD_UFMUN, 
            (AVG(t2.TX_CRESC)) FORMAT=6.4 AS TX_CRESC_MEDIO
      FROM WORK.DIAS_ATE_DOBRA t1
           INNER JOIN WORK.CRESCIMENTO t2 ON (t1.COD_UFMUN = t2.COD_UFMUN)
      WHERE t2.DATA > TODAY()-1-t1.DIAS_ATE_DOBRA
      GROUP BY t1.COD_UFMUN;
QUIT;

/* Calcula taxas médias */


PROC SQL;
   CREATE TABLE CALCULADORA_ESTAD AS 
   SELECT t2.COD_UFMUN, 
          t2.NOME_MUNICIPIO, 
          t2.CASOS_ACUMULADOS LABEL="Casos totais" AS CASOS_ACUMULADOS, 
          /* CASOS_POP */
            (ROUND(t2.CASOS_ACUMULADOS/t2.POPULACAO,0.00001)) LABEL="Casos totais/pop (%)" AS CASOS_POP, 
          t2.OBITOS_ACUMULADOS LABEL="Óbitos totais" AS OBITOS_ACUMULADOS, 
          /* OBITOS_POP */
            (ROUND(t2.OBITOS_ACUMULADOS/t2.POPULACAO,0.00001)) LABEL="Óbitos totais/pop (%)" AS OBITOS_POP, 
          /* TX_MORTALIDADE */
            (ROUND(t2.OBITOS_ACUMULADOS/t2.CASOS_ACUMULADOS,0.0001)) LABEL="Taxa de mortalidade" AS TX_MORTALIDADE, 
          t2.CASOS_NOVOS LABEL="Número de casos hoje" AS CASOS_NOVOS, 
          /* PERC_NOVOS_CASOS */
            (ROUND(t2.CASOS_NOVOS/t2.CASOS_ACUMULADOS,0.00001)) LABEL="% de novos casos" AS PERC_NOVOS_CASOS, 
          t2.OBITOS_NOVOS LABEL="Novos óbitos hoje" AS OBITOS_NOVOS, 
          /* PERC_NOVOS_OBITOS */
            (ROUND(t2.OBITOS_NOVOS/t2.OBITOS_ACUMULADOS,0.00001)) LABEL="% de novos óbitos" AS PERC_NOVOS_OBITOS, 
          /* DIAS ATE DOBRA */
			ROUND(t2.DIAS_ATE_DOBRA,0.01) AS DIAS_ATE_DOBRA,
          /* EM_7_DIAS */
            (ROUND(t2.CASOS_ACUMULADOS*t1.TX_CRESC_MEDIO**7)) LABEL="Total de casos em 7 dias" AS EM_7_DIAS, 
          /* EM_14_DIAS */
            (ROUND(t2.CASOS_ACUMULADOS*t1.TX_CRESC_MEDIO**14)) LABEL="Total de casos em 14 dias" AS EM_14_DIAS, 
          /* EM_30_DIAS */
            (ROUND(t2.CASOS_ACUMULADOS*t1.TX_CRESC_MEDIO**30)) LABEL="Total de casos em 30 dias" AS EM_30_DIAS
      FROM WORK.TX_CRESC_MEDIO t1
           INNER JOIN WORK.DIAS_ATE_DOBRA t2 ON (t1.COD_UFMUN = t2.COD_UFMUN);
QUIT;


/*********************************************************************************************/;
/************************ CONSOLIDA E SALVA ***********************************************/;
/*********************************************************************************************/;

/* Apenda Municipios e Estados e coloca prefixo na data */



DATA CASOS_COVID_ESTAD_HIST;
SET CALC.CASOS_COVID_ESTAD_HIST;
COD_UFMUN=0;
RUN;

DATA TRANSP (DROP=POPULACAO);
SET CASOS_COVID_ESTAD_HIST CALC.CASOS_COVID_MUNIC_HIST;
NOVA_DATA=CATT("DIA_",PUT(MONTH(DATA),Z2.),"/",PUT(DAY(DATA),Z2.));
RUN;

/* Transpoe */

PROC SORT DATA = TRANSP
OUT = TRANSP;
  BY COD_UFMUN NOVA_DATA;
RUN;

PROC TRANSPOSE DATA=TRANSP (KEEP=COD_UFMUN NOME_MUNICIPIO NOVA_DATA CASOS)
OUT=EVOLUCAO_CASOS;
BY COD_UFMUN NOME_MUNICIPIO;
ID NOVA_DATA;
RUN;

PROC TRANSPOSE DATA=TRANSP (KEEP=COD_UFMUN NOME_MUNICIPIO NOVA_DATA OBITOS)
OUT=EVOLUCAO_OBITOS;
BY COD_UFMUN NOME_MUNICIPIO;
ID NOVA_DATA;
RUN;

/* Remove missing */

DATA CALC.EVOLUCAO_CASOS (DROP=_NAME_);
SET EVOLUCAO_CASOS;
ARRAY X[*] DIA_:;
DO i = 1 TO DIM(X);
IF X[i] = . THEN X[i] = 0;
END;
OUTPUT;
DROP i;
RUN;

DATA CALC.EVOLUCAO_OBITOS (DROP=_NAME_);
SET EVOLUCAO_OBITOS;
ARRAY X[*] DIA_:;
DO i = 1 TO DIM(X);
IF X[i] = . THEN X[i] = 0;
END;
OUTPUT;
DROP i;
RUN;


/*********************************************************************************************/;
/************************ CONSOLIDA E SALVA ***********************************************/;
/*********************************************************************************************/;

DATA CALC.CALCULADORA;
SET CALCULADORA_MUNIC CALCULADORA_ESTAD;
RUN;

/* Exporta CSV */

PROC EXPORT
DATA=CALC.CALCULADORA
DBMS=csv
LABEL
OUTFILE="&CALC"
REPLACE;
QUIT;

PROC EXPORT
DATA=CALC.EVOLUCAO_CASOS
DBMS=csv
LABEL
OUTFILE="&EVOL_CASOS"
REPLACE;
QUIT;

PROC EXPORT
DATA=CALC.EVOLUCAO_OBITOS
DBMS=csv
LABEL
OUTFILE="&EVOL_OBITOS"
REPLACE;
QUIT;


/* Apaga tabelas work */
PROC SQL;
DROP TABLE WORK.SP2; DROP TABLE WORK.SP0; DROP TABLE CRESCIMENTO;
DROP TABLE ULTIMA_DATA; DROP TABLE DIAS_COM_CASOS;
DROP TABLE DIAS_ULTIMA_DOBRA; DROP TABLE DIAS_ATE_DOBRA;
DROP TABLE TX_CRESC_MEDIO; DROP TABLE CALCULADORA_MUNIC; 
DROP TABLE  CALCULADORA_ESTAD; DROP TABLE CASOS_COVID_ESTAD_HIST;
DROP TABLE TRANSP; DROP TABLE EVOLUCAO_OBITOS; DROP TABLE EVOLUCAO_CASOS;
QUIT;
