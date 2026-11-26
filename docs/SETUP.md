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

## 3. Login com Google (necessário só no M5)

Ficará aqui o passo a passo completo (Google Cloud Console, tela de consentimento OAuth, Client IDs Web/Android/Desktop, SHA-1 da keystore debug e release, Secrets `GOOGLE_WEB_CLIENT_ID` e `GOOGLE_DESKTOP_CLIENT_ID`). Será escrito junto com o M5.

## 4. Servidor online (necessário só no M5)

Hospedagem do servidor dedicado, domínio e provedor de autenticação serão definidos no M5.
