FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["BridalGlow.API/BridalGlow.API.csproj", "BridalGlow.API/"]
COPY ["BridalGlow.Services/BridalGlow.Services.csproj", "BridalGlow.Services/"]
COPY ["BridalGlow.Data/BridalGlow.Data.csproj", "BridalGlow.Data/"]
COPY ["BridalGlow.Model/BridalGlow.Model.csproj", "BridalGlow.Model/"]
RUN dotnet restore "BridalGlow.API/BridalGlow.API.csproj"
COPY . .
WORKDIR "/src/BridalGlow.API"
RUN dotnet build "BridalGlow.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "BridalGlow.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
COPY seed-images ./seed-images
ENTRYPOINT ["dotnet", "BridalGlow.API.dll"]
