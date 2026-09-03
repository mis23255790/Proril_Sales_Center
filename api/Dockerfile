FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY Proril.SalesIssue.Api.csproj ./
RUN dotnet restore Proril.SalesIssue.Api.csproj
COPY . .
RUN dotnet publish Proril.SalesIssue.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# appsettings.json 只放空殼結構，實際值一律靠環境變數（: 換成 __）注入，見 docker.env.example
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "Proril.SalesIssue.Api.dll"]
