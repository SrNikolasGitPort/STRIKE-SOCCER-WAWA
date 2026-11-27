# Configuração manual (o que só você pode fazer)

## 1. Primeiro build (nada a configurar)

O workflow roda sozinho a cada push na `main` e gera o APK **debug** e o zip do Windows. Baixe em **Actions > (execução mais recente) > Artifacts > strike-soccer-wawa-builds**.

Se o build falhar, abra a execução, copie o erro e me mande. O build é o primeiro teste real do projeto.

## 2. Keystore Android (para o APK release assinado e para a Play Store)

O APK debug instala em qualquer celular. Para um APK **release** assinado:

1. Gere a keystore (guarde o arquivo e as senhas em local seguro; se perder, não dá para atualizar o app depois):
   ```
   keytool -genkeypair -v -keystore strike-soccer.keystore -alias strike -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Converta para base64:
   - Linux/macOS: `base64 -w0 strike-soccer.keystore`
   - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("strike-soccer.keystore"))`
3. No GitHub: **Settings > Secrets and variables > Actions > New repository secret** e crie:

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | saída do passo 2 |
| `ANDROID_KEYSTORE_USER` | alias (`strike`) |
| `ANDROID_KEYSTORE_PASSWORD` | senha da keystore |

4. Crie uma tag para disparar a Release: `git tag v0.1.0 && git push origin v0.1.0`.

**Nunca** commite a keystore. O `.gitignore` já bloqueia `*.keystore`, `*.jks` e `.env`.

## 3. Login com Google (opcional)

O jogo usa o fluxo OAuth 2.0 **Device Authorization** (o jogo mostra um código; o jogador autoriza no navegador). Nenhum token é salvo.

1. Google Cloud Console > crie um projeto > **APIs e serviços > Tela de consentimento OAuth** (tipo Externo; escopos `openid`, `email`, `profile`; adicione seus testadores).
2. **Credenciais > Criar credenciais > ID do cliente OAuth > tipo "TVs e dispositivos de entrada limitada"**.
3. No GitHub, crie os Secrets `GOOGLE_OAUTH_CLIENT_ID` e `GOOGLE_OAUTH_CLIENT_SECRET` (o secret desse tipo de cliente não é confidencial de verdade, mas mantenha fora do repositório).
4. O CI gera `game/data/config/google_oauth.json` a partir dos Secrets durante o build (arquivo ignorado pelo git). Para testar localmente, salve o mesmo JSON em `user://google_oauth.json`.

Sem esses Secrets o jogo funciona normalmente como convidado; o botão do Google só mostra um aviso.

## 4. Multiplayer online

- **Modelo**: um jogador é o **host** (servidor autoritativo: só ele simula; clientes enviam entradas).
- **Código da sala**: codifica IP+porta (UDP 24565). O host tenta abrir a porta via UPnP; se o roteador não permitir, o código só funciona na mesma rede (LAN) — nesse caso abra/encaminhe a porta UDP 24565.
- **Salas públicas**: aparecem automaticamente na LAN (broadcast UDP 24566). Para lista pela **internet**, rode `python3 tools/master_server.py 8080` em um servidor seu e crie o Secret `MASTER_SERVER_URL`.
- **Amigos**: lista local por código de amigo; salas com amigos aparecem com ★.
- Sem predição de movimento no cliente (há latência igual ao ping).
