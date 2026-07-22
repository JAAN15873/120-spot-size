# FovCheck — nahrání na iPhone 13 mini z Windows (bez Macu)

MVP appka pro terénní ověření, jestli objekt padne do 120° zorného pole scanneru. Zdrojáky se
sestavují v cloudu (GitHub Actions, macOS runner) a na iPhone se instalují přes AltStore/AltServer —
běžný postup pro sideloading bez vlastního Macu, zdarma na vlastním Apple ID.

## Jednorázová příprava (jen poprvé)

1. **Apple Devices / iTunes** — nainstalujte na Windows aplikaci "Apple Devices" (Microsoft Store)
   nebo klasické iTunes z apple.com. Potřeba kvůli USB ovladačům, bez toho AltServer telefon nevidí.
2. **AltServer** — stáhněte a nainstalujte z [altstore.io](https://altstore.io) (odkaz na Windows verzi).
   Po instalaci běží jako ikonka v system tray.
3. **Apple ID** — stačí běžné (bezplatné) Apple ID, žádný placený Developer účet. Pokud máte
   dvoufázové ověření (běžně ano), vygenerujte si na [appleid.apple.com](https://appleid.apple.com)
   pod "Zabezpečení" → "Heslo pro aplikace" (app-specific password) — AltServer/AltStore ho bude
   chtít místo běžného hesla.
4. **AltStore na iPhonu** — připojte iPhone kabelem, na telefonu potvrďte "Důvěřovat tomuto počítači".
   Klikněte pravým na ikonku AltServer v tray → vyberte svůj iPhone → "Install AltStore" → zadejte
   Apple ID a heslo pro aplikace. Na telefonu se objeví appka AltStore.
5. Na iPhonu: Nastavení → Obecné → VPN a správa zařízení → potvrďte důvěru danému Apple ID (jinak se
   appka nespustí, i když se "nainstaluje").

Tohle je jediná část, kterou musím nechat na vás — přihlašovací údaje k Apple ID nikdy nezadávám
a neuvidím.

## Stažení sestavené appky (po každé změně kódu)

1. Otevřete repo na GitHub → záložka **Actions** → poslední běh workflow "Build iOS (unsigned)".
2. V sekci **Artifacts** stáhněte `FovCheck-unsigned-ipa.zip`, rozbalte → dostanete `FovCheck.ipa`.

## Instalace na iPhone (USB)

1. Připojte iPhone 13 mini kabelem, AltServer v tray musí běžet.
2. Pravým tlačítkem na ikonku AltServer → váš iPhone → **Install .ipa...** → vyberte stažený
   `FovCheck.ipa`.
3. Chvíli to trvá (podepisování + instalace). Ikonka FovCheck se objeví na ploše.
4. První spuštění appka požádá o přístup ke kameře — povolte, jinak nic neuvidíte.
5. Appka je uzamčená na landscape (na šířku) — otočte telefon.

## Důležité: platnost 7 dní

Appky podepsané zdarma přes Apple ID přestanou po 7 dnech fungovat, pokud se neobnoví. AltServer to
umí dělat automaticky na pozadí, pokud:
- necháte AltServer běžet na PC (i minimalizovaný v tray),
- iPhone bude čas od času na stejné Wi-Fi jako ten PC.

Pokud appka po týdnu přestane jít spustit, zopakujte jen krok "Instalace na iPhone" výše se stejným
(nebo novým) `.ipa`.

## Poznámka ke kalibraci

Reportovaný úhel záběru (FOV) v appce vychází z Apple specifikace objektivu, ne z měření. Před
ostrým použitím v terénu proveďte v appce kalibraci (tlačítko "Calibrate"): změřte pásmem šířku a
vzdálenost nějakého referenčního objektu, na obrazovce nastavte značky na jeho okraje a uložte
výslednou korekci. Bez kalibrace se overlay opírá jen o výrobní spec, což na vzdálenosti kolem 25 m
může znamenat chybu v řádu metrů.
