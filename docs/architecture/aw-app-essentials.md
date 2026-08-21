---
repo: architecture
path: docs/architecture/aw-app-essentials.md
source: generated
edited: false
checksum: sha256:6763acda63bf041440bb28ca1fffe118ae6322ea8920b0542f4c10dec6fe853a
---
# Essential CLI Tools

- **repo**: aw-app-essentials
- **layer**: app
- **technologies**: python
- **health** (derived): planned

Installs a broad set of workspace CLI tooling and keeps it present across restarts: core networking/utilities (telnet, ping, curl, nc, perl, python, vim, docker), Go, a Node.js dev toolkit (nvm, node, npm, npx, yarn, pnpm), Terraform, and Homebrew (Linuxbrew). Consolidates what used to be four separate apps (essentials, node, terraform, brew) into one, since they're all the same kind of thing: pure command installs, no login/settings/secrets.

## Connections
_none_

## MCP tools
_none exposed_

## Requirements
### Cada CLI instala pelo seu próprio script, no caminho exato dentro do repo
- Given os dezoito CLIs que este app consolidou dos antigos repos essentials/node/terraform/brew
- When a função de install de cada um resolve o script sob SCRIPTS_DIR e chama bash nele (repos/aw-app-essentials/essentials_app/installer.py::_run_script:30, SCRIPTS_DIR:23)
- Then o argv termina no caminho esperado daquele script e nenhum instalador roda o script de outro — a asserção é sobre o caminho, não sobre o efeito, porque o subprocess está mockado e o CI roda num runner limpo do GitHub sem rede nem apt. É o que dá para garantir barato: a fiação do repo, não a instalação de verdade, que só a suíte standalone exercita
- intended_status: `not_implemented` · derived health: `not_implemented`
- tests: `repos/aw-app-essentials/tests/test_installer.py` (passing)

### A versão escolhida chega ao script por variável de ambiente, não por argumento
- Given as três knobs configuráveis do app (terraform_version, node_version, go_version) e o fato de o framework não repassar argumentos para script de instalação, só package_dir e cwd
- When o activate exporta as três no ambiente antes de qualquer install (repos/aw-app-essentials/essentials_app/plugin.py::EssentialsAppPlugin.activate:35-37) e o caminho sem framework faz o mesmo por env_overrides (repos/aw-app-essentials/essentials_app/installer.py::install_terraform:95)
- Then o script lê AW_APP_TERRAFORM_VERSION / AW_APP_NODE_VERSION / AW_APP_GO_VERSION, com defaults 1.9.8 / lts / latest quando a config vem vazia ou ausente — o `or` cobre os dois casos de propósito, porque uma knob apagada na UI chega como string vazia e não como None, e sem isso o script receberia "" e instalaria uma versão sem nome
- intended_status: `not_implemented` · derived health: `not_implemented`
- tests: `repos/aw-app-essentials/tests/test_installer.py` (passing)

### Cada CLI define o comando que prova que ele existe, em vez de bastar estar no PATH
- Given CLIs cujo nome no PATH não prova nada: nvm é função de shell e nunca está no PATH, e ping, nc, go e gofmt não respondem a --version
- When o activate repassa o verify declarado no manifesto para a facade (repos/aw-app-essentials/essentials_app/plugin.py::EssentialsAppPlugin.activate:47, campo verify de contributes.system_clis)
- Then quem não declara verify cai no default `&lt;nome&gt; --version` e os cinco casos especiais usam o seu (nvm verifica `test -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh"`, go usa `go version`, gofmt usa `gofmt -h`, ping usa `ping -V`, nc usa `nc -h`) — uma checagem de presença fingindo ser checagem de saúde é o modo de falha desta casa, e com nvm ela erraria sempre: o binário nunca existe, então o padrão reportaria não-instalado para uma instalação perfeita
- intended_status: `not_implemented` · derived health: `not_implemented`
- tests: _none linked_

### Script de install que falha vira exceção com exit code e stderr, e não sucesso silencioso
- Given um script de instalação que sai diferente de zero (sem rede, apt travado, download 404)
- When o resultado do subprocess é conferido (repos/aw-app-essentials/essentials_app/installer.py::_run_script:42, com check=False no run da linha 35)
- Then sobe InstallError trazendo o nome do script, o exit code e o stderr — o check=False é deliberado para que a mensagem seja essa, e não o CalledProcessError cru do subprocess, que não diz qual dos dezoito scripts quebrou. Como os scripts são idempotentes, o reconciler pode reexecutar activate a cada boot sem acumular efeito
- intended_status: `not_implemented` · derived health: `not_implemented`
- tests: _none linked_
