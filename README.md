# Ilha Dinâmica

Ilha Dinâmica nativa para macOS desenvolvida com SwiftUI e AppKit, integrada ao notch da tela.

## Principais recursos

- **Música**: controle de reprodução, capa do álbum, visualizador de áudio e notificações de troca de faixa.
- **Áudio e Brilho**: sliders de volume e brilho com feedback visual Liquid Glass e supressão opcional do HUD nativo do macOS.
- **Clima**: previsão e visão expandida dedicada.
- **Shelf (Prateleira)**: área rápida para arrastar arquivos com miniaturas de imagens e vídeos.
- **Gravação de Tela**: gravação nativa via ScreenCaptureKit com captura de áudio do sistema.
- **Produtividade e Utilitários**: Calendário, Notas rápidas, Clipboard, Espelho de câmera, Pomodoro e Monitor de sistema/bateria.
- **Configurações**: ajuste de abas visíveis, atraso de hover e velocidade das animações.

## Requisitos

- macOS 14 (Sonoma) ou superior
- Swift 5.10 ou superior (Xcode ou Command Line Tools)

## Compilação

Para compilar o bundle em modo release e assinar em `dist/IlhaDinamica.app`:

```bash
./scripts/build_app.sh
```
