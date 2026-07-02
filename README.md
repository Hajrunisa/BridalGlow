# BridalGlow

**BridalGlow** je sistem za upravljanje salonom vjenčanica — omogućava kupcima pregled kataloga, rezervaciju probavanja i iznajmljivanja vjenčanica, plaćanje putem Stripe-a i ostavljanje recenzija, dok osoblju salona i administraciji pruža alate za upravljanje katalogom, rezervacijama, održavanjem, finansijama i izvještajima. Projekat je rađen u sklopu predmeta **Razvoj softvera II (RSII)**.

Sistem se sastoji od **.NET 8 Web API** backend-a, pozadinskog **Worker** servisa za asinhronu obradu (RabbitMQ), **PostgreSQL** baze podataka te dvije **Flutter** aplikacije — desktop (za osoblje salona) i mobilna (za kupce).

## 📱 Aplikacije

| Aplikacija | Folder | Namjena |
|---|---|---|
| **Desktop app** | `UI/bridalglow_desktop` | Interfejs za Admina i Salon Staff — katalog, rezervacije, održavanje, finansije, izvještaji |
| **Mobile app** | `UI/bridalglow_mobile` | Aplikacija za kupce — pregled kataloga, rezervacije, plaćanja, recenzije, preporuke |

## 🛠️ Korištene tehnologije

### Backend

| Tehnologija | Uloga |
|---|---|
| **.NET 8 Web API** | REST API, autentikacija, poslovna logika |
| **Worker Service (.NET 8)** | Pozadinska obrada — outbox relay, notifikacije, recommender recompute jobovi |
| **Entity Framework Core** | ORM (Npgsql provider) |
| **PostgreSQL** | Primarna baza podataka |
| **RabbitMQ (EasyNetQ)** | Message broker za asinhronu komunikaciju API ↔ Worker |
| **SignalR** | Real-time isporuka notifikacija na mobilnu aplikaciju |
| **JWT Bearer** | Autentikacija (access + refresh token) |
| **Stripe.net** | Payment Intent i Refund API (plaćanje i povrat sredstava) |
| **QuestPDF** | Generisanje PDF izvještaja (Business Performance, Financial) |
| **Mapster** | Object-to-object mapiranje |
| **Swagger / Swashbuckle** | Interaktivna API dokumentacija |

### Recommendation System

Item-based collaborative filtering (IBCF) preporučivač haljina, izračunat i osvježavan periodično kroz Worker. Detaljno opisan u posebnom dijelu ovog dokumenta ([Recommendation System](#-recommendation-system)).

### Frontend

| Tehnologija | Uloga |
|---|---|
| **Flutter / Dart** | Cross-platform UI (desktop + mobilna aplikacija) |
| **Provider** | State management |
| **flutter_stripe** | Stripe Payment Sheet integracija (mobilna aplikacija) |
| **signalr_netcore** | SignalR klijent za real-time notifikacije (mobilna aplikacija) |

### Infrastruktura

| Tehnologija | Uloga |
|---|---|
| **Docker / Docker Compose** | Orkestracija PostgreSQL, RabbitMQ, API i Worker kontejnera |

## 🏗️ Arhitektura

```
                         ┌─────────────────────┐
                         │   Flutter Desktop    │
                         │ (Admin / SalonStaff) │
                         └──────────┬───────────┘
                                    │ HTTPS / REST
                                    ▼
┌─────────────────┐        ┌───────────────────┐        ┌──────────────────┐
│  Flutter Mobile  │  REST  │   BridalGlow.API   │  SQL   │    PostgreSQL     │
│    (Customer)    ├───────▶│  (ASP.NET Core 8)  ├───────▶│                   │
└────────┬─────────┘        │  + SignalR Hub      │        └──────────────────┘
         │  WebSocket        └─────────┬──────────┘                 ▲
         │ (notifikacije)              │ piše u Outbox              │
         │                             ▼                            │
         │                   ┌───────────────────┐                  │
         │                   │  OutboxMessages    │                  │
         │                   └─────────┬──────────┘                  │
         │                             │ relay                       │
         │                             ▼                             │
         │                   ┌───────────────────┐                  │
         │                   │     RabbitMQ       │                  │
         │                   └─────────┬──────────┘                  │
         │                             │ consume                     │
         │                             ▼                             │
         │                   ┌───────────────────┐   SQL             │
         └───────────────────│ BridalGlow.Worker  ├───────────────────┘
         (push notifikacije) │ (Hosted Services)   │
                              └───────────────────┘
```

**Slojevi backend-a (Clean/Layered arhitektura):**

- **`BridalGlow.API`** — ASP.NET Core Web API kontroleri, JWT autentikacija, SignalR hub (`NotificationHub`), Swagger, serviranje uploadovanih slika.
- **`BridalGlow.Services`** — poslovna logika (servisi, interfejsi), zajednička za API i Worker (DI ekstenzije `AddBridalGlowServices`, `AddWorkerServices`).
- **`BridalGlow.Data`** — EF Core `DbContext`, entiteti, Fluent API konfiguracije, migracije i seed podaci.
- **`BridalGlow.Model`** — DTO-ovi (Request/Response), enumi, search objekti, messaging kontrakti.
- **`BridalGlow.Worker`** — pozadinski `BackgroundService` hostovi: outbox relay, RabbitMQ konzumeri (notifikacije, recommender recompute), zakazani jobovi (try-on podsjetnici, periodični recompute).

**Asinhroni tok (Outbox pattern):** API upisuje domenske događaje u `OutboxMessages` tabelu unutar iste transakcije kao poslovnu promjenu → `OutboxRelayHostedService` (Worker) objavljuje poruke na RabbitMQ → specijalizovani `*ConsumerHostedService` servisi u Workeru ih konzumiraju (notifikacije, similarity/snapshot recompute za recommender). Ovaj pristup garantuje da se događaji ne gube čak i ako je RabbitMQ privremeno nedostupan.

## 📂 Struktura solution-a

```
BridalGlow/
├── BridalGlow.API/            # ASP.NET Core Web API
│   ├── Controllers/           # REST API kontroleri
│   ├── Extensions/            # DI, JWT i SignalR ekstenzije
│   ├── Filters/                # Centralizovano rukovanje izuzecima
│   ├── Hubs/                   # SignalR NotificationHub
│   ├── Health/                 # Custom health check
│   └── Services/                # SignalR broadcast servis
│
├── BridalGlow.Services/        # Poslovna logika
│   ├── Services/                # Implementacije servisa
│   ├── Interfaces/              # Interfejsi servisa
│   ├── Helpers/                 # JWT, SMTP, RabbitMQ, Recommender opcije
│   ├── Messaging/                # Resolver za messaging event tipove
│   └── Reports/                  # QuestPDF generatori izvještaja
│
├── BridalGlow.Model/            # DTO-ovi, enumi, search objekti
│   ├── Requests/
│   ├── Responses/
│   ├── SearchObjects/
│   ├── Enums/
│   └── Messaging/                 # Poruke za RabbitMQ (Outbox kontrakti)
│
├── BridalGlow.Data/              # Entity Framework Core
│   ├── Database/                  # DbContext
│   ├── Entities/                  # Domenski entiteti
│   ├── Configuration/             # Fluent API konfiguracije
│   ├── Migrations/                 # EF Core migracije
│   └── Seeders/                    # Lookup podaci, test korisnici, demo haljine
│
├── BridalGlow.Worker/             # Pozadinski servis (Background workers)
│   └── Services/                    # Hosted services (outbox relay, konzumeri, zakazani jobovi)
│
├── docker-compose.yml              # PostgreSQL, RabbitMQ, API, Worker
├── Dockerfile                      # API kontejner
├── Dockerfile.worker               # Worker kontejner
├── .env.example                    # Šablon konfiguracije (kopirati u .env)
│
└── UI/
    ├── bridalglow_desktop/         # Desktop aplikacija (Admin / Salon Staff)
    └── bridalglow_mobile/          # Mobilna aplikacija (Customer)
```

## 🔐 Testni korisnici

Svi seedovani testni nalozi koriste lozinku **`test`**.

| Aplikacija | Korisničko ime | Lozinka | Uloga |
|---|---|---|---|
| Desktop | `admin` | `test` | Admin |
| Desktop | `staff` | `test` | SalonStaff |
| Mobile | `customer` | `test` | Customer |

> Desktop login forma dolazi sa unaprijed popunjenim `admin / test` podacima radi lakšeg testiranja.
>
> Dodatni Customer nalozi mogu se kreirati direktno kroz ekran za registraciju u mobilnoj aplikaciji.
>
> Sistem podržava tačno tri korisničke uloge (`Admin`, `SalonStaff`, `Customer`) — nema dodatnih uloga van navedenih u tabeli.

## ⚙️ Konfiguracija (.env)

Cjelokupna konfiguracija (konekcija na bazu, JWT tajni ključ, RabbitMQ, SMTP, Stripe ključevi, parametri recommendera) čuva se u **jednoj `.env` datoteci na korijenu repozitorija** (pored `BridalGlow.sln`).

- I `BridalGlow.API` i `BridalGlow.Worker` u `Program.cs` pozivaju `Env.TraversePath().Load()` (paket `DotNetEnv`). Ova metoda kreće od tekućeg radnog direktorija i penje se kroz roditeljske foldere dok ne pronađe `.env` datoteku. Kada se projekat pokreće po uputama iz ovog README-a (naredba `dotnet run --project ...` se izvršava iz `BridalGlow` korijenskog foldera), radni direktorij procesa je korijen repozitorija, pa se **direktno učitava `.env` iz korijena** — nije potrebno (niti se koristi) posebna `.env` datoteka unutar `BridalGlow.API` ili `BridalGlow.Worker` foldera.
- `.env` **nije** dio repozitorija (naveden je u `.gitignore`) jer sadrži tajne podatke (lozinke, API ključeve).
- `.env.example` (na korijenu repozitorija) je predložak sa svim potrebnim varijablama i njihovim opisima — kopirati ga u `.env` i popuniti stvarne vrijednosti prije pokretanja.
- Kada se stack pokreće preko `docker compose` (odjeljak ispod), API i Worker kontejneri **ne čitaju `.env` fajl** — sve vrijednosti im se prosljeđuju direktno kroz `environment:` sekciju u `docker-compose.yml` (fajl `.env` je isključen iz Docker build konteksta preko `.dockerignore`). `.env` na korijenu je stoga potreban samo za pokretanje API-ja/Workera **bez Dockera** (`dotnet run`).
- Flutter aplikacije (`UI/bridalglow_desktop`, `UI/bridalglow_mobile`) imaju svoje vlastite, nezavisne `.env.example` fajlove (API URL, Stripe publishable key) koje treba kopirati u `.env` unutar svakog UI foldera — ovo su potpuno odvojene `.env` datoteke od one na korijenu repozitorija.

## 🚀 Pokretanje projekta

### Preduslovi

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.8+
- [Docker](https://www.docker.com/) i Docker Compose (preporučeno za bazu, RabbitMQ, API i Worker)
- PostgreSQL (opciono, ako se ne koristi Docker)

### 1. Docker — infrastruktura i backend

Iz `BridalGlow` foldera:

```bash
cp .env.example .env
```

Otvoriti `.env` i postaviti minimalno:

- `DB_PASSWORD` (PostgreSQL)
- `JWT__SECRET_KEY` (minimalno 32 karaktera)

Pokrenuti kompletan stack (PostgreSQL, RabbitMQ, API, Worker):

```bash
docker compose up -d --build
```

| Servis | URL |
|---|---|
| **API (Swagger)** | http://localhost:5140/swagger |
| **Health check** | http://localhost:5140/health |
| **PostgreSQL** | localhost:5433 |
| **RabbitMQ management** | http://localhost:15673 (guest/guest) |

### 2. Migracije i seed podaci

Migracije i seed podaci se izvršavaju **automatski** — nije potrebna ručna intervencija:

- Pri pokretanju API kontejnera/procesa poziva se `db.Database.Migrate()`, koji primjenjuje sve neizvršene EF Core migracije.
- `db.SeedBusinessData()` zatim kreira demo haljine (20 komada, ako baza nema haljina) i osigurava postojanje testnih korisnika (`staff`, `customer`).
- Admin korisnik (`admin`), kategorije i tagovi haljina se seeduju kroz EF Core `HasData` migracije (izvršava se automatski uz `Migrate()`).

### 3. Pokretanje API-ja (bez Dockera)

```bash
cd BridalGlow
cp .env.example .env
# postaviti DB_MODE=local i podatke za lokalni PostgreSQL, te JWT__SECRET_KEY
dotnet run --project BridalGlow.API
```

Swagger je dostupan na **http://localhost:5140/swagger** u Development okruženju.

### 4. Pokretanje Worker servisa (bez Dockera)

Worker mora imati pristup istoj bazi i istom RabbitMQ instancom kao API:

```bash
cd BridalGlow
dotnet run --project BridalGlow.Worker
```

Worker pokreće outbox relay, RabbitMQ konzumere (notifikacije, recommender recompute) i zakazane jobove (try-on podsjetnici, periodični similarity/snapshot recompute).

### 5. Pokretanje Desktop aplikacije

```bash
cd UI/bridalglow_desktop
cp .env.example .env
flutter pub get
flutter run -d windows
```

### 6. Pokretanje Mobile aplikacije

```bash
cd UI/bridalglow_mobile
cp .env.example .env
flutter pub get
flutter run
```

Svaka Flutter aplikacija čita `API_BASE_URL` iz svog `.env` fajla (podrazumijevano `http://localhost:5140`).

## ✨ Glavne funkcionalnosti

### Kupac (Mobile app)

- Registracija i prijava (JWT)
- Pregled kataloga haljina sa filterima, pretragom i detaljima
- Rezervacija termina za probavanje (Try-On) i iznajmljivanje (Rental)
- Plaćanje putem Stripe-a (Payment Intent) i praćenje statusa uplate
- Ostavljanje recenzija nakon obavljene rezervacije
- Označavanje haljina kao Favorite i personalizovane preporuke ("Recommended for you")
- Real-time i in-app notifikacije (status rezervacije, objavljena recenzija, podsjetnici)
- Pregled i uređivanje ličnog profila

### Osoblje salona / Admin (Desktop app)

- Upravljanje katalogom haljina (CRUD, kategorije, tagovi, slike, cjenovna pravila)
- Pregled i upravljanje terminima dostupnosti (Availability slots)
- Odobravanje/odbijanje rezervacija (Try-On i Rental)
- Evidencija održavanja haljina (Maintenance records)
- Moderacija recenzija kupaca
- Upravljanje korisnicima (aktivacija/deaktivacija)
- Finansijski pregled — plaćanja i zahtjevi za povrat sredstava (Refund)
- Izvještaji o poslovanju i finansijama (dashboard KPI + izvoz u PDF)
- Operativni uvid u recommendation sistem (status, trendovi, ručno pokretanje recompute-a)

## 🎯 Recommendation System

BridalGlow koristi **item-based collaborative filtering (IBCF)** preporučivač koji kupcima predlaže haljine na osnovu njihovih prethodnih interakcija (pregledi, favoriti, rezervacije, recenzije) i sličnosti između haljina.

Ukratko:

1. **Interakcije** (`UserDressInteractions`) se bilježe pri pregledu, označavanju favorita, rezervaciji i recenziji, svaka sa svojom težinom.
2. **Similarity matrica** (`DressSimilarities`) se periodično računa na osnovu cosine sličnosti između haljina prema obrascima interakcija korisnika.
3. **Snapshot preporuke** (`RecommendationSnapshots`) se generišu po korisniku kombinovanjem njegovih interakcija sa similarity matricom i keširaju za brzo čitanje.
4. Za nove korisnike bez historije koristi se **cold-start** strategija (popularnost + featured + ocjena haljine).
5. Recompute jobovi se izvršavaju periodično u Workeru (konfigurabilan interval) ili ručno putem admin API endpointa.

Detaljna dokumentacija algoritma, uključenih klasa/servisa, tabela, pipeline-a (similarity → snapshot), cold-starta i ograničenja implementacije nalazi se u **[`recommender-dokumentacija.md`](./recommender-dokumentacija.md)** na korijenu repozitorija.

## 📡 API Overview

| Endpoint | Opis |
|---|---|
| `POST /api/Auth/register` | Registracija kupca |
| `POST /api/Auth/login` | Prijava (vraća JWT + refresh token) |
| `POST /api/Auth/refresh` | Osvježavanje access tokena |
| `GET /api/Users/me` | Profil trenutno prijavljenog korisnika |
| `GET /api/Users` | Lista korisnika (samo Admin) |
| `GET /api/Dress` | Katalog haljina (paginacija, filteri) |
| `GET /api/Recommendations/for-me` | Personalizovane preporuke za kupca |
| `POST /api/Payments/create-intent` | Kreiranje Stripe Payment Intent-a za odobrenu rezervaciju |
| `GET /api/Health` | Status servisa (konekcija na bazu, recommender metapodaci) |
| `GET /health` | ASP.NET Core health check endpoint |

Kompletna interaktivna referenca dostupna je na **http://localhost:5140/swagger**. Zaštićeni endpointi zahtijevaju Bearer JWT token.

## 🔒 Sigurnost

- Heširanje lozinki sa salt-om
- JWT access i refresh tokeni
- Autorizacija zasnovana na ulogama (Admin, SalonStaff, Customer)
- Centralizovano rukovanje izuzecima i validacija ulaznih podataka
- Konfiguracija sa tajnim podacima izdvojena u `.env` (van repozitorija)

## 📄 Licenca

Projekat je izrađen isključivo u akademske svrhe, kao seminarski/projektni rad u sklopu predmeta **Razvoj softvera II (RSII)**. Nije namijenjen za komercijalnu upotrebu niti je licenciran za javnu distribuciju.
