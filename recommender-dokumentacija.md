# Recommender dokumentacija — BridalGlow

Ovaj dokument opisuje **isključivo stvarno implementiran** sistem preporuka (recommender) u BridalGlow projektu. Sve tvrdnje su provjerene direktno u izvornom kodu (`BridalGlow.Data`, `BridalGlow.Services`, `BridalGlow.Worker`, `BridalGlow.API`, `BridalGlow.Model`). Dokument ne opisuje planirane niti pretpostavljene funkcionalnosti.

## 1. Tip recommender sistema

BridalGlow implementira **Item-based Collaborative Filtering (IBCF)** preporučivač haljina, dopunjen **cold-start** strategijom zasnovanom na popularnosti/isticanju/ocjeni za korisnike bez dovoljno podataka.

Princip rada (item-based CF): sličnost se ne računa između korisnika, već između **parova haljina (dresses)**, na osnovu obrasca po kojem korisnici interaguju s tim haljinama (cosine similarity nad vektorima korisničkih težina po haljini). Preporuke za konkretnog korisnika se zatim generišu tako što se njegove poznate interakcije "projektuju" kroz matricu sličnosti haljina.

Implementacija je **offline/batch** — sličnosti i preporuke se unaprijed izračunaju i snime u bazu (materializovani "snapshoti"), a API u realnom vremenu samo čita već izračunate rezultate. Ne postoji online/real-time (u hodu) izračunavanje preporuka pri svakom pozivu API-ja.

## 2. Klase i servisi koji učestvuju u radu recommendera

### BridalGlow.Services (poslovna logika, zajednička za API i Worker)

| Klasa / interfejs | Uloga |
|---|---|
| `IUserDressInteractionService` / `UserDressInteractionService` (`BridalGlow.Services/Services/UserDressInteractionService.cs`) | Bilježi (`RecordInteractionAsync`) i čita korisničke interakcije s haljinama; sadrži deduplikacijsku logiku (View, Favorite, rezervacije) i mapiranje tipa interakcije u težinu (`ResolveWeight`). |
| `IDressSimilarityComputationService` / `DressSimilarityComputationService` (`BridalGlow.Services/Services/DressSimilarityComputationService.cs`) | Računa item-item cosine similarity matricu haljina na osnovu tabele `UserDressInteractions` i upisuje rezultat u `DressSimilarities`. |
| `IRecommendationSnapshotService` / `RecommendationSnapshotService` (`BridalGlow.Services/Services/RecommendationSnapshotService.cs`) | Za svakog korisnika kombinuje njegove interakcije sa similarity matricom i generiše top-K preporuke koje upisuje u `RecommendationSnapshots`. |
| `IRecommendationQueryService` / `RecommendationQueryService` (`BridalGlow.Services/Services/RecommendationQueryService.cs`) | Čita već izračunate preporuke/sličnosti za potrebe API-ja (`GetForUserAsync`, `GetSimilarDressesAsync`, `GetColdStartAsync`, `GetStatusAsync`, `GetTrendsAsync`). Ne izračunava ništa "u hodu" osim cold-start rangiranja. |
| `RecommenderOptions` / `RecommenderInteractionWeightOptions` (`BridalGlow.Services/Helpers/RecommenderOptions.cs`) | Konfiguracija recommendera (model verzija, Top-K vrijednosti, minimalni similarity prag, težine interakcija, intervali recompute-a). Vezano na `appsettings.json` sekciju `"Recommender"` i djelimično na env varijable. |
| `RecommenderServiceCollectionExtensions.AddBridalGlowRecommender` (`BridalGlow.Services/Extensions/RecommenderServiceCollectionExtensions.cs`) | DI registracija `RecommenderOptions`; primjenjuje override iz env varijabli `RECOMMENDER_SIMILARITY_RECOMPUTE_INTERVAL_HOURS` i `RECOMMENDER_SNAPSHOT_RECOMPUTE_INTERVAL_HOURS`. |

### BridalGlow.Worker (pozadinsko izvršavanje)

| Klasa | Uloga |
|---|---|
| `DressSimilarityRecomputeHostedService` | `BackgroundService` koji periodično (interval iz konfiguracije, podrazumijevano 24h) poziva `IDressSimilarityComputationService.RecomputeSimilaritiesAsync()`. |
| `RecommendationSnapshotHostedService` | `BackgroundService` koji nakon početnog odgode od 15 minuta periodično (interval iz konfiguracije, podrazumijevano 6h) poziva `IRecommendationSnapshotService.RecomputeSnapshotsAsync()`. |
| `SimilarityRecomputeConsumerHostedService` | Konzumira RabbitMQ poruku `SimilarityRecomputeRequestedMessage` (pretplata `MessagingConstants.SimilarityRecomputeSubscriptionId`) i odmah pokreće `RecomputeSimilaritiesAsync()` — koristi se za ručno pokretanje preko admin API endpointa. |
| `SnapshotRecomputeConsumerHostedService` | Konzumira RabbitMQ poruku `SnapshotRecomputeRequestedMessage` (pretplata `MessagingConstants.SnapshotRecomputeSubscriptionId`) i odmah pokreće `RecomputeSnapshotsAsync()` — koristi se za ručno pokretanje preko admin API endpointa. |

Sve četiri gore navedene `BackgroundService` implementacije se registruju u `BridalGlow.Worker/Program.cs`.

### BridalGlow.API (izlaganje preko REST-a)

| Klasa | Uloga |
|---|---|
| `RecommendationsController` (`BridalGlow.API/Controllers/RecommendationsController.cs`) | Endpointi za preporuke, cold-start, status, trendove i ručno pokretanje recompute jobova. |
| `DressController.GetSimilar` (`BridalGlow.API/Controllers/DressController.cs`) | Endpoint za "slične haljine" za konkretnu haljinu (`{id}/similar`), koristi `IRecommendationQueryService.GetSimilarDressesAsync`. |
| `InteractionsController` (`BridalGlow.API/Controllers/InteractionsController.cs`) | Endpoint kojim mobilna aplikacija eksplicitno bilježi `View` i `Favorite` interakcije. |
| `HealthController` (`BridalGlow.API/Controllers/HealthController.cs`) | `GET /api/Health` uključuje status recommendera (`RecommenderStatusResponse`) uz status konekcije na bazu. |

### BridalGlow.Data (perzistencija)

| Entitet | Fajl |
|---|---|
| `UserDressInteraction` | `BridalGlow.Data/Entities/UserDressInteraction.cs` + `Configuration/UserDressInteractionConfiguration.cs` |
| `DressSimilarity` | `BridalGlow.Data/Entities/DressSimilarity.cs` + `Configuration/DressSimilarityConfiguration.cs` |
| `RecommendationSnapshot` | `BridalGlow.Data/Entities/RecommendationSnapshot.cs` + `Configuration/RecommendationSnapshotConfiguration.cs` |

### BridalGlow.Model (kontrakti)

- `InteractionType`, `InteractionSource` enumi (`BridalGlow.Model/Enums/`)
- `RecommendationItemResponse`, `SimilarDressResponse`, `RecommenderStatusResponse`, `RecommenderTrendsResponse`, `RecommendationTrendItemResponse` (`BridalGlow.Model/Responses/`)
- `SimilarityRecomputeRequestedMessage`, `SnapshotRecomputeRequestedMessage` (`BridalGlow.Model/Messaging/Messages/`) — poruke za outbox/RabbitMQ pipeline

### Flutter (prikaz preporuka)

- `RecommendationProvider` i `Recommendation` model — postoje odvojeno u `UI/bridalglow_mobile` i `UI/bridalglow_desktop` (desktop verzija se koristi za operativni uvid administratora — status/trendovi, ne za personalizovane preporuke kupca).
- `recommended_for_you_section.dart` (mobile) — widget koji prikazuje sekciju "Preporučeno za vas" na osnovu odgovora `GET /api/Recommendations/for-me`.
- `recommender_display_helper.dart` (desktop) — pomoćne funkcije za prikaz statusa/trendova recommendera u admin/staff interfejsu.

## 3. Tabele koje recommender koristi

| Tabela (EF Core `ToTable`) | Entitet | Svrha |
|---|---|---|
| `UserDressInteractions` | `UserDressInteraction` | Sirovi zapisi korisničkih interakcija s haljinama (ulaz za oba recompute algoritma). |
| `DressSimilarities` | `DressSimilarity` | Izračunata item-item similarity matrica (parovi haljina + cosine score + verzija modela). |
| `RecommendationSnapshots` | `RecommendationSnapshot` | Materializovane (keširane) top-K preporuke po korisniku za konkretnu verziju modela. |

Relevantna polja:

- `UserDressInteraction`: `UserId`, `DressId`, `InteractionType`, `Weight` (decimal), `OccurredAtUtc`, `SessionId`, `Source`, `MetadataJson` (kolona tipa `jsonb`), plus audit polja (`IsDeleted`, `CreatedAtUtc`, ...) iz `AuditableEntity`. Indeks: `(UserId, DressId, InteractionType, OccurredAtUtc)`.
- `DressSimilarity`: `DressId`, `SimilarDressId`, `Score` (precision 8,6), `ModelVersion`, `CalculatedAtUtc`. Unique indeks: `(DressId, SimilarDressId, ModelVersion)`.
- `RecommendationSnapshot`: `UserId`, `DressId`, `Score` (precision 8,6), `Rank`, `ModelVersion`, `GeneratedAtUtc`. Unique indeks: `(UserId, DressId, ModelVersion)`.

Sve tri tabele nastaju kroz standardne EF Core migracije (`BridalGlow.Data/Migrations`) i ne sadrže seed podatke — recommender kreće od praznog stanja (vidjeti odjeljak Cold-start).

## 4. Kako se grade similarity podaci (`DressSimilarityComputationService`)

Algoritam u `RecomputeSimilaritiesAsync()`:

1. Učita sve aktivne, neobrisane haljine (`Dresses` gdje `!IsDeleted && Status == Active`). Ako ih ima manje od 2, recompute se preskače.
2. Učita sve neobrisane `UserDressInteractions` za te haljine (`UserId`, `DressId`, `Weight`).
3. Izgradi matricu **haljina → (korisnik → suma težina)** (`BuildDressUserWeightMatrix`) — za svaku haljinu se sumiraju sve težine interakcija istog korisnika.
4. Izračuna Euklidsku normu vektora težina svake haljine (`ComputeDressNorms`).
5. Za svaki par aktivnih haljina (i, j) računa **cosine similarity**: skalarni proizvod vektora težina (samo za korisnike koji su interagovali s obje haljine) podijeljen s proizvodom njihovih normi.
6. Zadržava samo parove čiji je score ≥ `MinSimilarityScore` (podrazumijevano `0.01`), i po haljini uzima najviše `TopKSimilarDresses` (podrazumijevano `10`) najsličnijih haljina, sortirano opadajuće po score-u.
7. Svaki novi run dobija novu vrijednost `ModelVersion` u formatu `{ModelVersion}-{yyyyMMdd-HHmmss}` (npr. `ibcf-v1-20260702-190301`).
8. U jednoj DB transakciji: upisuju se novi redovi u `DressSimilarities`, a zatim se brišu svi redovi sa starijom (drugačijom) `ModelVersion` vrijednošću — tabela u svakom trenutku sadrži samo rezultate posljednjeg izvršavanja.

Similarity je **simetrična po značenju**, ali se u bazi pamti samo smjer koji je izašao iz Top-K filtriranja za tu haljinu (tj. moguće je da par (A,B) postoji a (B,A) ne, ako B nije u Top-K listi za A). Servis za čitanje preporuka (`RecommendationQueryService.LoadSimilarityLookupAsync` i `RecommendationSnapshotService.BuildSimilarityNeighborLookup`) ovo rješava tako što svaki par tretira kao obostran (dodaje oba smjera u lookup) prilikom agregacije preporuka.

## 5. Kako nastaju recommendation snapshoti (`RecommendationSnapshotService`)

Algoritam u `RecomputeSnapshotsAsync()`:

1. Pronalazi najnoviju `ModelVersion` iz `DressSimilarities`. Ako similarity tabela prazna → snapshot recompute se preskače (nema smisla praviti preporuke bez similarity modela).
2. Učita sve parove sličnosti za tu verziju modela i izgradi **obostrani lookup** susjeda po haljini (`BuildSimilarityNeighborLookup`).
3. Učita sve neobrisane interakcije za aktivne haljine i za svakog korisnika sumira težine po haljini (`BuildUserDressWeights`), te odvojeno bilježi haljine s kojima je korisnik imao "jaku" interakciju (`RentalReserved` ili `ReviewSubmitted`) — `BuildStrongInteractionDressIds`.
4. Za svakog korisnika, za svaku haljinu s kojom je interagovao, "projektuje" tu interakciju kroz similarity susjede: `contribution = similarityScore * korisnikova_težina_za_izvornu_haljinu`, i akumulira te doprinose po kandidatskoj haljini (`AccumulateSimilarityCandidates`).
   - Haljine koje korisnik već ima kao "jaku" interakciju (iznajmio ili recenzirao) se **isključuju** iz kandidata — nema smisla preporučiti nešto što je već iznajmljeno/ocijenjeno.
   - Haljine koje nisu aktivne se isključuju.
5. Za svakog korisnika se uzima top `TopKRecommendations` (podrazumijevano `12`) kandidata sortiranih opadajuće po akumuliranom score-u i upisuje kao `RecommendationSnapshot` redovi s poljem `Rank` (1..K) i istim `ModelVersion` kao similarity model iz kojeg su izvedeni.
6. U jednoj DB transakciji: brišu se stari snapshoti za istu `ModelVersion` (idempotentnost ponovnog pokretanja), upisuju se novi, pa se brišu svi snapshoti sa **starijom** verzijom modela — tabela uvijek sadrži samo rezultate posljednjeg runa.

Bitno: snapshot recompute **zavisi** od prethodno izvršenog similarity recompute-a (koristi njegov `ModelVersion` i podatke). Zbog toga `RecommendationSnapshotHostedService` u Workeru ima početni odgodu od 15 minuta pri pokretanju procesa (da similarity job stigne odraditi prvi run), a i sam interval snapshot joba (6h) je podrazumijevano kraći od similarity joba (24h) kako bi se preporuke češće osvježavale iz iste similarity matrice.

## 6. Cold-start

Cold-start je implementiran u `RecommendationQueryService.GetColdStartAsync()` i koristi se u dva slučaja:

- Direktno, preko `GET /api/Recommendations/cold-start`.
- Automatski kao **fallback** unutar `GetForUserAsync()`, kada:
  - korisnik nema nijedan `RecommendationSnapshot` red (nikad nije bio dio nekog recompute-a), ili
  - korisnik ima snapshot red, ali za tu `ModelVersion` nema više redova (npr. filtrirano/isteklo) — u oba slučaja se poziva `GetColdStartAsync`.

Algoritam cold-start rangiranja (izvršava se "u hodu", nije materializovan):

1. Učita broj interakcija po haljini (`interactionCounts`, iz `UserDressInteractions`, bez obzira na korisnika).
2. Učita sve aktivne haljine sa slikama, kategorijom i tagovima.
3. Za svaku haljinu računa `ComputeColdStartScore`:
   - `+2` ako je haljina `IsFeatured`,
   - `+ AverageRating` haljine,
   - `+ min(broj_interakcija, 20) * 0.05` (popularnost, sa gornjim ograničenjem).
4. Sortira opadajuće po tom score-u, zatim po `AverageRating`, zatim alfabetski po imenu; uzima top `TopKRecommendations` (ili traženi `limit`).
5. Generiše tekstualno objašnjenje (`BuildColdStartReason`) — npr. "Istaknuta kolekcija s visokom ocjenom korisnica.", "Popularno među korisnicama BridalGlow platforme." itd., zavisno koji uslov je zadovoljen.

Cold-start dakle ne zahtijeva nikakvu prethodnu ličnu historiju korisnika i uvijek daje rezultat (dok god postoji barem jedna aktivna haljina), pa se koristi i za sasvim nove korisnike i kao siguran fallback kada personalizovani model još nije izračunat (npr. odmah nakon prvog pokretanja sistema, prije prvog similarity/snapshot recompute-a).

## 7. Interakcije korisnika koje utiču na preporuke

`InteractionType` (`BridalGlow.Model/Enums/InteractionType.cs`) i njihove podrazumijevane težine (`RecommenderInteractionWeightOptions`, konfigurabilne u `appsettings.json` sekciji `Recommender:InteractionWeights`):

| Tip interakcije | Podrazumijevana težina | Kada se bilježi | Izvor (`InteractionSource`) |
|---|---|---|---|
| `View` | 1 | Kupac otvori detalje haljine u mobilnoj aplikaciji — bilježi `POST /api/Interactions`. | `Mobile` |
| `Favorite` | 2 | Kupac označi haljinu kao omiljenu — `POST /api/Interactions`; uklanjanje ide preko `DELETE /api/Interactions/favorites/{dressId}` (meko brisanje, `IsDeleted = true`). | `Mobile` |
| `TryOnReserved` | 3 | Automatski, iz `TryOnReservationService`, i pri kreiranju rezervacije probe (status `Pending`) i pri potvrdi od strane osoblja (status `Confirmed`). | `System` |
| `RentalReserved` | 4 | Automatski, iz `RentalReservationService`, analogno try-on rezervaciji (kreiranje i potvrda). | `System` |
| `ReviewSubmitted` | 5 | Automatski, iz `ReviewService`, kada je recenzija objavljena (status `Published`). | `System` |
| `PurchasedAddon` | — (nije podržano) | Enum vrijednost postoji (`= 6`) ali **nije ožičena** u `ResolveWeight` — pokušaj bilježenja ove interakcije bacio bi `UserException`. Trenutno se nigdje u kodu ne poziva. | — |

Napomene o deduplikaciji (`UserDressInteractionService.RecordInteractionAsync`):

- `View`: duplikat se preskače ako je isti korisnik pregledao istu haljinu unutar `ViewDeduplicationMinutes` (podrazumijevano 30 min), opciono ograničeno na istu `SessionId`.
- `Favorite`: duplikat se preskače ako korisnik već ima aktivan (neobrisan) Favorite zapis za tu haljinu.
- `TryOnReserved` / `RentalReserved` / (generalno rezervacione interakcije): duplikat se preskače ako već postoji zapis istog tipa sa istim `MetadataJson` (koji sadrži ID konkretne rezervacije) — zbog toga se ista rezervacija ne broji dvaput iako se interakcija bilježi i pri kreiranju i pri potvrdi.

Sve interakcije (`InteractionSource.System`) koje bilježe servisi rezervacija/recenzija se izvršavaju unutar `try/catch` bloka koji samo loguje upozorenje ako zapis interakcije ne uspije — greška u bilježenju interakcije nikad ne blokira glavnu poslovnu operaciju (kreiranje rezervacije, objavu recenzije).

## 8. Kada se recommender izvršava

| Mehanizam | Gdje | Kada |
|---|---|---|
| Periodični similarity recompute | `DressSimilarityRecomputeHostedService` (Worker) | Na pokretanju Worker procesa, zatim svakih `SimilarityRecomputeIntervalHours` sati (podrazumijevano 24h, konfigurabilno preko `RECOMMENDER_SIMILARITY_RECOMPUTE_INTERVAL_HOURS`). |
| Periodični snapshot recompute | `RecommendationSnapshotHostedService` (Worker) | Prvi put 15 minuta nakon pokretanja Worker procesa, zatim svakih `SnapshotRecomputeIntervalHours` sati (podrazumijevano 6h, konfigurabilno preko `RECOMMENDER_SNAPSHOT_RECOMPUTE_INTERVAL_HOURS`). |
| Ručni similarity recompute | `POST /api/Recommendations/recompute-similarity` → `SimilarityRecomputeRequestedMessage` → RabbitMQ → `SimilarityRecomputeConsumerHostedService` (Worker) | Na zahtjev Admin/SalonStaff korisnika iz desktop aplikacije (npr. dugme u operativnom uvidu u recommender). |
| Ručni snapshot recompute | `POST /api/Recommendations/recompute-snapshots` → `SnapshotRecomputeRequestedMessage` → RabbitMQ → `SnapshotRecomputeConsumerHostedService` (Worker) | Na zahtjev Admin/SalonStaff korisnika. |
| Cold-start rangiranje | `RecommendationQueryService.GetColdStartAsync` | Sinhrono, pri svakom pozivu `GET /api/Recommendations/cold-start` ili kad `GetForUserAsync` nema snapshot za korisnika. Nije "recompute job" — nema perzistencije rezultata. |

Bilježenje interakcija (`UserDressInteractions`) se dešava **sinhrono i odmah** (u istom API pozivu koji izaziva interakciju — pregled, favorit, rezervacija, recenzija), za razliku od similarity/snapshot recompute-a koji su uvijek asinhroni/pozadinski.

Napomena o outbox/RabbitMQ toku: ručni recompute endpointi u `RecommendationsController` koriste `IDomainEventPublisher.EnqueueAsync`, što upisuje poruku u `OutboxMessages` tabelu u istoj transakciji, a zatim `OutboxRelayHostedService` (Worker) tu poruku objavljuje na RabbitMQ, odakle je preuzimaju `SimilarityRecomputeConsumerHostedService` / `SnapshotRecomputeConsumerHostedService`. Ovo znači da ručno pokretanje recompute-a **nije trenutno** — zavisi o outbox relay ciklusu i dostupnosti RabbitMQ/Worker procesa.

## 9. API endpointi za preporuke

Svi endpointi zahtijevaju JWT autentikaciju (`[Authorize]` na nivou kontrolera, dodatno ograničeno po ulozi tamo gdje je navedeno).

| Metoda i ruta | Uloga | Opis |
|---|---|---|
| `GET /api/Recommendations/for-me` | `Customer` | Personalizovane preporuke za prijavljenog kupca; pada na cold-start ako nema snapshot podataka. Query parametar `limit` (opciono). |
| `GET /api/Recommendations/cold-start` | `Customer` | Eksplicitno vraća cold-start preporuke (bez personalizacije). Query parametar `limit` (opciono). |
| `GET /api/Recommendations/status` | `Admin`, `SalonStaff` | Operativni status recommendera: `ModelVersion`, vrijeme posljednjeg similarity/snapshot runa, broj interakcija, broj similarity parova, broj snapshotova. |
| `GET /api/Recommendations/trends` | `Admin`, `SalonStaff` | Agregirani trendovi — haljine koje se najčešće/s najvišim ukupnim score-om pojavljuju u posljednjem setu snapshotova. Query parametar `limit` (opciono). |
| `POST /api/Recommendations/recompute-similarity` | `Admin`, `SalonStaff` | Zakazuje similarity recompute posao (asinhrono, preko outbox → RabbitMQ → Worker). Vraća `202 Accepted`. |
| `POST /api/Recommendations/recompute-snapshots` | `Admin`, `SalonStaff` | Zakazuje snapshot recompute posao (asinhrono, preko outbox → RabbitMQ → Worker). Vraća `202 Accepted`. |
| `GET /api/Dress/{id}/similar` | `Customer` | Item-based "slične haljine" za konkretnu haljinu, iz posljednje izračunate `DressSimilarities` verzije modela. Query parametar `limit` (opciono). |
| `POST /api/Interactions` | `Customer` | Bilježi `View` ili `Favorite` interakciju (jedini interakcijski endpoint dostupan direktno klijentu; ostale interakcije su implicitne kroz rezervacije/recenzije). |
| `GET /api/Interactions/favorites` | `Customer` | Lista ID-jeva haljina koje je korisnik označio kao Favorite. |
| `DELETE /api/Interactions/favorites/{dressId}` | `Customer` | Uklanja Favorite interakciju (meko brisanje). |
| `GET /api/Health` | (bez role restrikcije) | Osnovni health check koji uz status baze uključuje i `RecommenderStatusResponse` (opciono, ne blokira health status ako recommender upit ne uspije). |

## 10. Ograničenja trenutne implementacije

- **Batch/offline pristup**: preporuke i sličnosti se ne ažuriraju u realnom vremenu nakon svake interakcije — korisnik vidi ažurirane preporuke tek nakon sljedećeg recompute ciklusa (periodičnog ili ručno pokrenutog).
- **Cold-start je "svima isti"**: `GetColdStartAsync` ne uzima u obzir bilo kakav kontekst trenutnog korisnika (npr. njegove favorite ili demografske podatke) — isti rezultat za sve korisnike bez snapshot podataka, dok god su parametri (broj interakcija po haljini, isticanje, ocjena) isti.
- **O(n²) similarity izračun u memoriji**: `DressSimilarityComputationService` učitava sve interakcije i haljine u memoriju procesa i računa sličnost svih parova ugniježđenim petljama — prihvatljivo za obim podataka demonstracionog projekta (desetine haljina, seed od 20 demo komada), ali se ne bi skaliralo na veliki katalog/veliki broj korisnika bez indeksiranja (npr. ANN) ili paginacije.
- **`PurchasedAddon` interakcija nije implementirana** iako postoji u `InteractionType` enumu — `ResolveWeight` bi bacio izuzetak da je neko pokuša zabilježiti; trenutno je nikad ne poziva nijedan servis.
- **`InteractionSource.Desktop` se nikad ne koristi** — enum vrijednost postoji, ali nijedan API poziv trenutno ne bilježi interakciju s izvorom `Desktop` (desktop aplikacija ne generiše korisničke interakcije, samo administrativne operacije).
- **Similarity nije garantovano simetrična u bazi** (vidi odjeljak 4) zbog Top-K odsijecanja po haljini; kompenzuje se ručno u aplikacijskom sloju prilikom generisanja snapshotova, ali direktan upit nad `DressSimilarities` iz jednog smjera može propustiti par koji postoji samo u drugom smjeru.
- **Nema A/B testiranja ni evaluacijskih metrika**: ne postoji mehanizam za mjerenje kvaliteta preporuka (npr. precision/recall, klik-kroz stopa) — `ModelVersion` postoji radi konzistentnosti podataka (izbjegavanje miješanja starih i novih rezultata), a ne radi poređenja modela.
- **Snapshot recompute je strogo zavisan od postojanja similarity modela**: ako similarity tabela nikad nije popunjena (npr. manje od 2 aktivne haljine ili nema nijedne interakcije), snapshot recompute se u potpunosti preskače i `GetForUserAsync` će uvijek vraćati cold-start rezultate.
- **Nema brisanja/arhiviranja historije interakcija**: `UserDressInteractions` raste neograničeno (meko brisanje se koristi samo za Favorite uklanjanje); nema retention/pruning politike.
- **Ručni recompute nije sinhron**: `202 Accepted` odgovor ne garantuje da je posao odmah izvršen — zavisi od outbox relay ciklusa, dostupnosti RabbitMQ i Worker procesa; UI koji poziva ove endpointe treba naknadno provjeriti `GET /api/Recommendations/status` da potvrdi da je novi `ModelVersion`/vrijeme zaista ažurirano.
- **Nema testova specifičnih za recommender** u repozitoriju (nema jediničnih/integracionih testova za `DressSimilarityComputationService` ili `RecommendationSnapshotService`) — ispravnost algoritma je verifikovana isključivo kroz čitanje koda, ne kroz automatizovane testove.
