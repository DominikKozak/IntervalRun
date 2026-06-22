# IntervalRunCoach

`IntervalRunCoach` je jednoducha iPhone appka pro intervalovy beh a chuzi. Je delana tak, aby clovek pri treninku nemusel porad koukat na hodinky nebo displej a mohl se ridit zvukem, hlasem a vibraci.

## Co aplikace umi

- nastavit vlastni sekvenci intervalu, napriklad `Beh 1:00` a `Chuze 3:00`
- opakovat celou sekvenci ve vice kolech
- pridavat, mazat a menit poradi intervalu
- spustit 5sekundovou pripravu pred startem
- prehrat zvuk, vibraci a hlasove hlaseni pri zmene intervalu
- ukazat aktualni usek, dalsi usek, prubeh a zbyvajici cas
- nabidnout rychle presety pro casto pouzivane treninky
- ulozit posledni nastaveni lokalne do telefonu
- posilat lokalni notifikace i pri zamknute obrazovce
- pri behu drzet displej aktivni, aby telefon neusnul

## Jak je projekt postaveny

- `SwiftUI`
- bez backendu
- bez externich knihoven
- lokalni ukladani pres `UserDefaults`
- hlas pres `AVSpeechSynthesizer`
- notifikace pres `UserNotifications`

## Otevreni v Xcode

1. Na Macu otevri `IntervalRunCoach.xcodeproj`.
2. V `Signing & Capabilities` zvol svuj `Personal Team`.
3. Pokud Xcode zahlasi problem s podpisem, zmen `Bundle Identifier` treba na `com.tvojejmeno.IntervalRunCoach`.
4. Pripoj iPhone kabelem nebo pres lokalni sit.
5. V horni liste vyber iPhone jako cilove zarizeni.
6. Spust aplikaci tlacitkem `Run`.

## Bezplatne nahrani do iPhonu

- S bezplatnym Apple ID jde aplikaci nahrat pres Xcode bez placeneho developer programu.
- Podpis u free uctu obvykle vydrzi asi 7 dni, pak je potreba aplikaci znovu nahrat.
- Pro osobni pouziti na jednom telefonu je to nejjednodussi a nejlevnejsi cesta.

## Chovani upozorneni

- Kdyz je aplikace otevrena, prepnuti intervalu hlasi vestaveny hlas, zvuk a vibrace.
- Kdyz je telefon zamknuty nebo je aplikace na pozadi, prijdou lokalni notifikace se zvukem.
- Pri pauze se plan notifikaci prepocita, aby se upozorneni nerozjela mimo skutecny trenink.

## Napad na dalsi krok

Jestli budes chtit, da se snadno pridat historie treninku, vlastni barevna temata nebo Apple Watch verze.
