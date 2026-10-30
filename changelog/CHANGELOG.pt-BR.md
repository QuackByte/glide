# Changelog

Novidades de cada versão do Glide para Mac. O Glide mostra as novas entradas uma vez após se atualizar, e as notas de cada versão no GitHub vêm daqui, então escreva para quem usa o Glide. Adicione uma entrada para cada mudança que vale a pena conhecer na próxima versão antes de criar a tag. Esta é uma tradução de CHANGELOG.md, que é o original.

## 0.11.2 — 2026-10-30

### Novidades

- **Use só ⌥ como tecla modificadora do Glide.** Ajustes › Atalhos › Tecla modificadora do Glide troca todos os atalhos padrão de ⌃⌥ para ⌥, como fazem o AeroSpace e apps parecidos: ⌥→ foca à direita, ⌥⇧→ move a janela e ⌥ + roda desliza a faixa. Em troca, ⌥ + setas deixam de pular de palavra em palavra no texto, e ⌥ + letras e números deixam de digitar caracteres como é ou ©. Os atalhos que você mesmo mudou continuam como estão.

## 0.11.1 — 2026-10-20

### Mudanças

- **Layout em blocos: em tela cheia, as setas percorrem as janelas em ordem.** ⌃⌥→ e ⌃⌥↑ vão para a próxima janela, ⌃⌥← e ⌃⌥↓ para a anterior, voltando ao início ao chegar ao fim, então você não precisa lembrar onde cada janela fica por baixo. As abas de um grupo vêm uma por uma, e com ⇧ as setas movem a janela focada uma posição.

## 0.11.0 — 2026-10-20

### Novidades

- **Layout em blocos: ⌃⌥F deixa todo o espaço de trabalho em tela cheia.** Cada janela preenche a tela, com a focada por cima, até você pressionar ⌃⌥F de novo. ⌃⌥ + setas passam de uma janela para outra sem sair da tela cheia, e janelas novas também abrem em tela cheia.

## 0.10.2 — 2026-10-19

### Novidades

- **Layout em blocos: ⌃⌥↑ e ⌃⌥↓ trocam de aba primeiro.** Em um grupo de abas, elas trocam de aba antes de ir para o bloco nessa direção.

### Correções

- **Layout em blocos: os vizinhos encolhem para caber na largura mínima de um app.** Quando um app tem largura mínima, os blocos ao lado encolhem para caber nela em vez de se sobrepor, e o Glide informa por que um redimensionamento para nessa largura.

## 0.10.1 — 2026-10-19

### Correções

- **Grupos de abas funcionam no layout em blocos.** ⌃⌥[ e ⌃⌥] adicionam uma janela a um grupo de abas (uma coluna com abas), e uma aba pode ser movida para o próprio bloco, como já acontecia ao rolar.

## 0.10.0 — 2026-10-19

### Novidades

- **Mosaico agora é um layout em espiral.** ⌃⌥T muda um espaço de trabalho para um layout em que todas as janelas cabem na tela: uma janela a preenche, duas a dividem em metades, e a partir da terceira a última coluna se divide de novo, alternando em cima e embaixo com esquerda e direita. Ele usa 2 colunas, ou 3 com o novo ⌃⌥G, que também é o que o Glide escolhe em telas ultrawide. Voltar para Rolagem mantém suas janelas na mesma ordem.
- **Mova-se por um espaço de trabalho em mosaico pela direção.** ⌃⌥ + setas focam o bloco ao lado do focado, e ⌃⌥⇧ + setas o trocam de lugar com esse vizinho. Percorrer as larguras (⌃⌥R) muda como o bloco focado divide o espaço com os blocos seguintes, e ⌃⌥F amplia um bloco para preencher a tela até você pressionar de novo.
- **Escolha quantas colunas os espaços de trabalho em mosaico usam** em Ajustes › Geral › Colunas do mosaico: Automático (3 em telas ultrawide, senão 2), 2 ou 3.

### Mudanças

- **Enviar uma janela a outro espaço de trabalho move só essa janela.** ⌃⌥⇧1…9 e ⌃⌥⇧PgUp/PgDn levavam a coluna inteira; agora só a janela focada vai, como uma coluna própria, e você continua no espaço de trabalho em que está.

## 0.9.4 — 2026-10-19

### Correções

- **Chega de lacunas depois de fechar uma janela.** Quando uma janela fechava ou saía, um app que ignorava parte de um movimento (como o Proton Mail) podia ficar onde estava, deixando uma lacuna. Agora o Glide confere onde as janelas realmente ficam e as coloca no lugar certo.

## 0.9.3 — 2026-10-19

### Novidades

- **Layout em mosaico.** ⌃⌥T alterna o espaço de trabalho atual entre a faixa com rolagem e um layout em mosaico, em que todas as colunas dividem a tela e cabem juntas, sem rolagem. Cada espaço de trabalho mantém o próprio layout, mesmo depois de reiniciar o Glide. Percorrer as larguras de uma coluna (⌃⌥R) dá a ela uma parte maior ou menor, arrastar a borda a redimensiona, e ⌃⌥F continua deixando a coluna com largura total até você pressionar de novo.
- **Escolha o layout com que os novos espaços de trabalho começam** em Ajustes › Geral › Layout: Rolagem, como antes, ou Mosaico. Os espaços de trabalho que você alternou com ⌃⌥T mantêm o seu.

## 0.9.2 — 2026-10-16

### Novidades

- **Novidades também fala o seu idioma.** As notas que o Glide mostra após uma atualização, e em Novidades, agora estão no mesmo idioma do resto do Glide.

## 0.9.1 — 2026-10-16

### Novidades

- **O Glide fala o seu idioma.** O Glide agora está disponível em francês, alemão, japonês, chinês simplificado, coreano e português do Brasil, além de inglês e espanhol, e segue o idioma preferido do macOS.

## 0.9.0 — 2026-10-15

O Glide para Mac agora usa os mesmos números de versão do Glide para Windows.

### Novidades

- **Todos os atalhos em uma página.** ⌃⌥/ mostra todos; pressione de novo, pressione Esc ou clique fora para fechar. Ele também fica no menu da barra de menus, no topo de Atalhos.
- **Relatar um problema**, no menu da barra de menus e em Ajustes › Geral. O Glide reúne o registro recente e os ajustes em um zip, sem os títulos das janelas, mostra o arquivo no Finder e abre um novo issue no GitHub para você descrever o que aconteceu e anexar o zip. Nada é enviado automaticamente.
- **O Glide fala espanhol.** Quando o macOS está em espanhol, o Glide também está. Novidades continua em inglês.

### Correções

- **Tela cheia continua em tela cheia.** Uma janela que você coloca em tela cheia, ou um vídeo ou jogo que ocupa o display inteiro, não é mais puxada de volta para a sua coluna. O Glide a deixa em paz, oculta o contorno de foco, o escurecimento e a barra de abas sobre ela, e deixa a roda horizontal e os gestos de três dedos chegarem até ela nesse display. Quando ela sai da tela cheia, volta para a sua coluna.

## 0.4.0 — 2026-10-14

### Novidades

- **Veja onde a janela arrastada vai ficar.** Enquanto você arrasta uma janela, um contorno na cor do contorno de foco mostra a coluna em que ela entraria, incluindo a barra de abas. Sobre outro display, uma barra mostra onde ela ficaria entre as colunas desse display. Sem destaque, ela volta para o lugar de origem.

## 0.3.0 — 2026-10-14

### Novidades

- **Todos os displays em mosaico.** Cada display tem a sua própria faixa e seus próprios nove espaços de trabalho. Os atalhos agem no display com a janela em foco, ou no que está sob o ponteiro. ⌃⌥⌘←/→ movem o foco para o display daquele lado, e ⌃⌥⌘⇧←/→ enviam a coluna em foco para lá. As janelas novas entram no display em que abrem.
- **Arraste uma janela para onde quiser.** Solte-a em uma barra de abas e ela vira uma aba ali; solte-a sobre outra janela e ela é empilhada na coluna dessa janela; solte-a em outro display e ela entra na faixa desse display. Uma janela flutuante solta sobre um bloco entra no mosaico. Em qualquer outro lugar, ela volta para o lugar de origem, como antes.
- **A roda do mouse desliza pela faixa.** Incline a roda (ou use uma roda para o polegar) para se mover pela faixa, ou mantenha ⌃⌥ pressionado ao rolar. Escolha quando a inclinação faz isso em Ajustes › Roda horizontal do mouse: Sempre, Com ⌃⌥ ou Desativado.
- **Os apps reabrem onde você os deixa.** O Glide lembra o display, o espaço de trabalho, a largura da coluna e a posição de cada app na faixa, e abre as janelas novas dele ali. Desative isso, ou esqueça todos os lugares, nos Ajustes.
- **Espessura do contorno de foco**, de 1 a 12 pontos, em Ajustes › Aparência.

## 0.2.1 — 2026-10-14

### Novidades

- **Novidades.** Após uma atualização, o Glide mostra o que mudou. Encontre-o de novo na barra de menus, em **Novidades**.

## 0.2.0 — 2026-10-14

### Novidades

- **O Glide se mantém atualizado.** Ele busca uma nova versão uma vez por dia e a oferece, ou a instala para você se você ativar isso em Ajustes › Atualizações. **Buscar atualizações…** no menu busca na hora. Toda atualização é assinada e notarizada pela Apple.
- **O Glide é de código aberto**, sob a licença MIT: [github.com/QuackByte/glide](https://github.com/QuackByte/glide).

## 0.1.1 — 2026-10-13

### Correções

- Fechar e reabrir o Chrome, o T3 Code ou outro app Chromium ou Electron deixava o foco na janela anterior, e a nova janela ficava fora da tela. Agora ela recebe o foco e é rolada para a área visível.

## 0.1.0 — 2026-10-13

A primeira versão do Glide para Mac.

- **Colunas em uma faixa com rolagem**: larguras de ⅓, ½, ⅔ e total, pilhas e colunas com abas, com um atalho para tudo.
- **Nove espaços de trabalho**, uma visão geral com pré-visualizações ao vivo, gestos de três dedos, um contorno de foco, regras por app e um vigia que devolve as suas janelas ao lugar se o Glide travar.
