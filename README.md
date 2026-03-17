🔄 Assistente de Migração VMD/RST ↔ AHCI (Windows)

Um script em lote (.bat) automatizado, guiado e seguro para alternar entre as controladoras Intel VMD / RST e AHCI / NVMe nativo no Windows 10 e 11, sem causar o erro de Tela Azul (INACCESSIBLE_BOOT_DEVICE).

Perfeito para quem precisa desativar o VMD na BIOS para instalar macOS (Hackintosh) ou Linux em Dual Boot, mas quer manter o Windows funcionando perfeitamente.

✨ Recursos

Modo Guiado (Passo a Passo): O script diz exatamente o que você precisa fazer e em qual fase está.

Ida e Volta: Permite tanto Desativar o VMD (migrar para AHCI) quanto Reativar o VMD de forma segura.

Gerenciamento de BitLocker: Detecta o status do BitLocker (Suporte a sistemas em PT-BR e EN) e suspende a proteção automaticamente se necessário.

Autoelevação: Solicita privilégios de Administrador automaticamente se aberto com duplo-clique.

Detecção Inteligente: Verifica se o VMD já está desativado ou ativo no hardware usando o utilitário nativo do Windows.

Logs Detalhados: Salva um histórico das ações (VMD_Log_DATA.txt) na mesma pasta do script.

⚠️ Aviso Importante

Este script prepara o Windows para a mudança, mas VOCÊ precisa saber onde fica a configuração de "Intel VMD", "Intel RST" ou "Armazenamento (SATA/NVMe)" na BIOS da sua placa-mãe. Diferentes marcas (ASUS, Gigabyte, Dell, Lenovo) têm menus diferentes.

🚀 Como usar

Faça o download do arquivo Migra_VMD_AHCI_Windows.bat.

Clique com o botão direito no arquivo e selecione Executar como Administrador (ou apenas dê um duplo-clique e confirme o prompt do UAC).

O Assistente abrirá. Escolha a opção desejada:

Opção 

$$1$$

 DESATIVAR Intel VMD / RST (Ir para AHCI)

Opção 

$$2$$

 ATIVAR Intel VMD / RST (Voltar para o padrão de fábrica)

Fase 1 (Preparação): O script configurará o Windows para iniciar em Modo de Segurança e reiniciará o PC direto para a sua BIOS.

Na BIOS: Altere a configuração do VMD/RST conforme o seu objetivo, salve (geralmente F10) e saia.

Fase 2 (Limpeza): O Windows iniciará em Modo de Segurança (com visual básico). Abra o Migra_VMD_AHCI_Windows.bat novamente. Ele detectará a Fase 2, removerá o Modo de Segurança e reiniciará o PC normalmente.

Pronto! Seu Windows iniciará normalmente com a nova controladora ativa.

🛠️ Como funciona (Sob o capô)

O Windows vincula o driver da controladora de armazenamento no momento da instalação. Se você mudar na BIOS repentinamente, ele não encontra o disco. O truque deste script é forçar a flag safeboot minimal no BCD (bcdedit). No Modo de Segurança, o Windows é obrigado a carregar drivers genéricos (AHCI/NVMe) básicos, corrigindo o registro para a próxima inicialização normal.

📝 Licença

Distribuído sob a licença MIT. Sinta-se à vontade para usar, modificar e distribuir.
