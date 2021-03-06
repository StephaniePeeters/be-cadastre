* Encoding: windows-1252.
* dit document draaien nadat je enkele stappen in gis hebt gezet (zie handleiding_gis).

* locatie van je bestanden instellen.
* pas dit aan naar de map waar je bestanden staan.
* OPGELET: dit gaat ervan uit dat je daar deze mappen hebt: geometrie, werkbestanden.
DEFINE basismap () 'G:\OD_IF_AUD\2_04_Statistiek\2_04_01_Data_en_kaarten\kadaster_percelen\kadaster_gebouwdelen_2015\' !ENDDEFINE.

* DEEL 1: percelen zonder twijfel.

GET TRANSLATE
  FILE=
    '' + basismap + 'geometrie\percelen_in_enkel_sectordeel.dbf'
  /TYPE=DBF /MAP .
DATASET NAME eenvoudig WINDOW=FRONT.

*verwijder balast.
match files
/file=*
/keep=capakey statsec wijkcode.
*standaardiseer tekstvariabelen.
alter type statsec (a4).
alter type wijkcode (a5).

SAVE OUTFILE='' + basismap + 'geometrie\unieke_capa.sav'
  /COMPRESSED.



* DEEL 2: percelen die een grens overschrijden.

* A: crabadressen per statsec per perceel.

GET TRANSLATE
  FILE=
    '' + basismap + '\geometrie\crab_statsec_perceel.dbf'
  /TYPE=DBF /MAP .
DATASET NAME crabsplits WINDOW=FRONT.

* zorg dat je hoogstens een rij hebt per mogelijke sector en wijk en perceel.

DATASET DECLARE capaagg.
AGGREGATE
  /OUTFILE='capaagg'
  /BREAK=capakey statsec WijkCode
  /combinaties=N.
DATASET ACTIVATE capaagg.
variable labels combinaties "crabadressen op dit perceeldeel".
AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /BREAK=capakey
  /records=N.
sort cases records (d).
variable labels records "aantal mogelijke sectoren bij dit perceel".

* B: oppervlakte van perceeldelen per sector.
GET TRANSLATE
  FILE=
    '' + basismap + '\geometrie\percelen_over_de_sectorgrens.dbf'
  /TYPE=DBF /MAP .
DATASET NAME percsplits WINDOW=FRONT.
* bereken oppervlakte van het perceeldeel per sector.
DATASET DECLARE aggopp.
AGGREGATE
  /OUTFILE='aggopp'
  /BREAK=capakey statsec WijkCode
  /oppervlakte=SUM(oppsplits).
dataset activate aggopp.

* koppel A en B.
ADD FILES /FILE=*
  /FILE='capaagg'.
EXECUTE.

dataset close percsplits.
dataset close crabsplits.
dataset close capaagg.


DATASET DECLARE finalagg.
AGGREGATE
  /OUTFILE='finalagg'
  /BREAK=capakey statsec WijkCode
  /oppervlakte=SUM(oppervlakte) 
  /combinaties=SUM(combinaties) 
  /records=SUM(records).
dataset activate finalagg.

dataset close aggopp.

* sorteer volgens perceelnummer en daarbinnen bovenaan de optie met het meeste adressen en in tweede instantie de grootste oppervlakte en gebruik die om per perceel een volgnummer toe te kennen.
sort cases  capakey (d) combinaties (d) oppervlakte (d).
if $casenum=1 volgnummer=1.
if capakey~=lag(capakey) volgnummer=1.
if capakey=lag(capakey) volgnummer=lag(volgnummer)+1.
EXECUTE.

recode combinaties (missing=0).

* voeg een variabele toe die per perceel maximum oppervlakte en aantal adressen laat zien.
AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /BREAK=capakey
  /oppervlakte_max=MAX(oppervlakte) 
  /combinaties_max=MAX(combinaties).

* ben je op alles nummer 1, dan wijzen we het perceeldeel aan die sector toe.
if volgnummer=1 & combinaties=combinaties_max & oppervlakte=oppervlakte_max toegewezen=1.
if volgnummer=1 & missing(toegewezen) toegewezen=0.
* ben je nummer 1 en ben je enkel de grootste wat betreft adressen, dan wijzen we daaraan toe.
if toegewezen=0 & combinaties=combinaties_max toegewezen=1.
EXECUTE.
* check of alle percelen toegewezen zijn.
freq toegewezen.
DATASET ACTIVATE finalagg.
DATASET DECLARE test.
AGGREGATE
  /OUTFILE='test'
  /BREAK=capakey
  /toegewezen_max=MAX(toegewezen).
* check in deze dataset of alle percelen op 1 staan.
dataset close test.

* hoe enkel het perceeldeel over met de sector waaraan we hebben toegewezen.
FILTER OFF.
USE ALL.
SELECT IF (toegewezen = 1).
EXECUTE.

* verwijder ballast.
match files
/file=*
/keep=capakey
statsec
WijkCode.
*standaardiseer tekstvariabelen.
alter type statsec (a4).
alter type wijkcode (a5).

*voeg "onderaan" de eenvoudige gevallen toe.
ADD FILES /FILE=*
  /FILE='eenvoudig'.
EXECUTE.
sort cases capakey (a).

* sla op als SPSS tabel.
SAVE OUTFILE='' + basismap + '\werkbestanden\sectoren_toekennen.sav'
  /COMPRESSED.

new file.
dataset name leeg window=front.
dataset close eenvoudig.
dataset close finalagg.


