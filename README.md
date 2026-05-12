# Pravidlo-3-30-300-hodnotenie-mestskej-zelene
Tento repozitár obsahuje SQL skripty využité pri implementácii pravidla 3-30-300 v prostredí PostgreSQL/PostGIS. Skripty boli vytvorené pre automatizované spracovanie priestorových analýz súvisiacich s hodnotením viditeľnosti stromov, stromovej pokrývky a dostupnosti zelene v mestskom prostredí.

Analýzy boli realizované v jazyku SQL s využitím priestorového rozšírenia PostGIS. Skripty boli spúšťané v prostredí pgAdmin nad databázou PostgreSQL 17 a PostGIS 3.5.

Obsah skriptov
Observer_points.sql
Generovanie pozorovacích bodov na fasádach budov na základe segmentácie obvodov budov.
Line_of_sight.sql
Tvorba spojníc medzi pozorovacími bodmi a stromami do vzdialenosti 30 m a vyhodnotenie ich viditeľnosti vzhľadom na prekážky tvorené budovami.
Pokryvka_30.sql
Výpočet percentuálneho podielu stromovej pokrývky (canopy cover) v 30 m okolí budov.
Vzdialenost_300.sql
Výpočet vzdialenosti budov k najbližšej verejne prístupnej zelenej ploche.
Požiadavky

Na použitie skriptov je potrebné mať:

PostgreSQL s rozšírením PostGIS
pgAdmin alebo iné SQL rozhranie
vstupné vrstvy v jednotnom súradnicovom systéme:
vrstva budov
bodová vrstva stromov
vektorová vrstva zelene / parkov
polygonizovaná vrstva stromovej pokrývky vytvorená z CHM/LiDAR dát
Použitie

Skripty je odporúčané spúšťať postupne podľa ich poradia, keďže výstupy jednotlivých krokov môžu slúžiť ako vstupy pre nasledujúce analýzy.
